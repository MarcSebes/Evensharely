//
//  CloudKitErrorHandler.swift
//  Evensharely
//
//  Error handling and retry logic for CloudKit operations
//

import Foundation
import CloudKit
import Network

// MARK: - CloudKit Error Types

enum CloudKitError: LocalizedError {
    case networkUnavailable
    case quotaExceeded
    case serverError(String)
    case unauthorized
    case notFound
    case conflict
    case limitExceeded
    case retryableError(Error, retryAfter: TimeInterval?)
    case nonRetryableError(Error)
    case invalidData(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        case .quotaExceeded:
            return "Storage quota exceeded. Please free up some space."
        case .serverError(let message):
            return "Server error: \(message)"
        case .unauthorized:
            return "You're not authorized to perform this action."
        case .notFound:
            return "The requested item was not found."
        case .conflict:
            return "There was a conflict with another change. Please try again."
        case .limitExceeded:
            return "Request limit exceeded. Please wait a moment and try again."
        case .retryableError(let error, _):
            return "Temporary error: \(error.localizedDescription). Retrying..."
        case .nonRetryableError(let error):
            return "Error: \(error.localizedDescription)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .timeout:
            return "The request timed out. Please try again."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .serverError, .retryableError, .timeout, .limitExceeded:
            return true
        default:
            return false
        }
    }
    
    var suggestedRetryInterval: TimeInterval {
        switch self {
        case .retryableError(_, let retryAfter):
            return retryAfter ?? 2.0
        case .limitExceeded:
            return 5.0
        case .serverError, .timeout:
            return 3.0
        case .networkUnavailable:
            return 1.0
        default:
            return 2.0
        }
    }
}

// MARK: - CloudKit Error Handler

class CloudKitErrorHandler {
    static let shared = CloudKitErrorHandler()
    private init() {}
    
    /// Maximum number of retry attempts
    private let maxRetries = 3
    
    /// Base delay for exponential backoff (in seconds)
    private let baseDelay: TimeInterval = 1.0
    
    /// Maximum delay between retries (in seconds)
    private let maxDelay: TimeInterval = 30.0
    
    // MARK: - Error Classification
    
    /// Converts CKError to CloudKitError for better handling
    func classifyError(_ error: Error) -> CloudKitError {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return .networkUnavailable
                
            case .quotaExceeded:
                return .quotaExceeded
                
            case .serverResponseLost, .serviceUnavailable, .requestRateLimited:
                let retryAfter = ckError.retryAfterSeconds
                return .retryableError(error, retryAfter: retryAfter)
                
            case .notAuthenticated, .permissionFailure:
                return .unauthorized
                
            case .unknownItem:
                return .notFound
                
            case .serverRecordChanged, .changeTokenExpired:
                return .conflict
                
            case .limitExceeded, .batchRequestFailed:
                return .limitExceeded
                
            case .internalError, .serverRejectedRequest:
                return .serverError(ckError.localizedDescription)
                
            case .zoneBusy:
                return .retryableError(error, retryAfter: 2.0)
                
            default:
                // Check if error suggests retry
                if ckError.isRetriableError {
                    return .retryableError(error, retryAfter: ckError.retryAfterSeconds)
                } else {
                    return .nonRetryableError(error)
                }
            }
        }
        
        // Handle NSError for network issues
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed:
                return .networkUnavailable
            case NSURLErrorTimedOut:
                return .timeout
            default:
                return .nonRetryableError(error)
            }
        }
        
        return .nonRetryableError(error)
    }
    
    // MARK: - Retry Logic with Exponential Backoff
    
    /// Performs a CloudKit operation with automatic retry on failure
    func performWithRetry<T>(
        operation: @escaping () async throws -> T,
        maxAttempts: Int? = nil,
        onRetry: ((Int, TimeInterval) -> Void)? = nil
    ) async throws -> T {
        let attempts = maxAttempts ?? maxRetries
        var lastError: CloudKitError?
        
        for attempt in 1...attempts {
            do {
                // Attempt the operation
                return try await operation()
                
            } catch {
                // Classify the error
                let cloudKitError = classifyError(error)
                lastError = cloudKitError
                
                // Check if error is retryable
                guard cloudKitError.isRetryable else {
                    throw cloudKitError
                }
                
                // Check if we have more attempts
                guard attempt < attempts else {
                    throw cloudKitError
                }
                
                // Calculate delay with exponential backoff
                let delay = calculateBackoffDelay(
                    attempt: attempt,
                    suggestedDelay: cloudKitError.suggestedRetryInterval
                )
                
                // Notify about retry
                onRetry?(attempt, delay)
                
                // Log retry attempt
                print("🔄 Retry attempt \(attempt)/\(attempts) after \(String(format: "%.1f", delay))s delay")
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // This should never be reached, but just in case
        throw lastError ?? CloudKitError.nonRetryableError(NSError(domain: "CloudKit", code: -1))
    }
    
    /// Calculates exponential backoff delay with jitter
    private func calculateBackoffDelay(attempt: Int, suggestedDelay: TimeInterval? = nil) -> TimeInterval {
        // Start with suggested delay or base delay
        let baseValue = suggestedDelay ?? baseDelay
        
        // Calculate exponential backoff: base * 2^(attempt-1)
        let exponentialDelay = baseValue * pow(2.0, Double(attempt - 1))
        
        // Add jitter (±20% randomization to prevent thundering herd)
        let jitter = exponentialDelay * 0.2 * (Double.random(in: -1...1))
        let delayWithJitter = exponentialDelay + jitter
        
        // Cap at maximum delay
        return min(delayWithJitter, maxDelay)
    }
    
    // MARK: - Batch Operation Handling
    
    /// Handles partial failures in batch operations
    func processBatchResults<T>(
        _ results: [(CKRecord.ID, Result<T, Error>)]
    ) -> (succeeded: [T], failed: [(CKRecord.ID, CloudKitError)]) {
        var succeeded: [T] = []
        var failed: [(CKRecord.ID, CloudKitError)] = []
        
        for (recordID, result) in results {
            switch result {
            case .success(let value):
                succeeded.append(value)
            case .failure(let error):
                let cloudKitError = classifyError(error)
                failed.append((recordID, cloudKitError))
            }
        }
        
        return (succeeded, failed)
    }
    
    // MARK: - Network Monitoring
    
    /// A helper class to check network connectivity using the NWPathMonitor.
    class NetworkMonitor {
        static let shared = NetworkMonitor()
        private let monitor = NWPathMonitor()
        private let queue = DispatchQueue(label: "NetworkMonitor")
        private var isConnected = false
        
        init() {
            monitor.pathUpdateHandler = { path in
                self.isConnected = (path.status == .satisfied)
            }
            monitor.start(queue: queue)
        }
        
        func isNetworkAvailable() -> Bool {
            return isConnected
        }
    }
    
    /// Checks if network is available before attempting CloudKit operations.
    func checkNetworkAvailability() async -> Bool {
        return NetworkMonitor.shared.isNetworkAvailable()
    }
}



    /// old and busted code from Claude
//    /// Checks if network is available before attempting CloudKit operations
//    func checkNetworkAvailability() async -> Bool {
//        // Simple connectivity check
//        let container = CloudKitConfig.container
//        
//        do {
//            // Try a lightweight operation
//            _ = try await container.accountStatus()
//            return true
//        } catch {
//            let cloudKitError = classifyError(error)
//            if cloudKitError == .networkUnavailable {
//                return false
//            }
//            else {
//                return true
//            }
//        }
//    }
//}

// MARK: - CKError Extensions

extension CKError {
    /// Determines if the error is retriable
    var isRetriableError: Bool {
        switch self.code {
        case .networkUnavailable, .networkFailure,
             .serviceUnavailable, .requestRateLimited,
             .zoneBusy, .serverResponseLost:
            return true
        default:
            return false
        }
    }
    
    /// Gets the suggested retry interval from the error
    var retryAfterSeconds: TimeInterval? {
        return userInfo[CKErrorRetryAfterKey] as? TimeInterval
    }
}

// MARK: - Operation Result Type

enum OperationResult<T> {
    case success(T)
    case partialSuccess(T, errors: [CloudKitError])
    case failure(CloudKitError)
    
    var isSuccess: Bool {
        switch self {
        case .success, .partialSuccess:
            return true
        case .failure:
            return false
        }
    }
    
    func get() throws -> T {
        switch self {
        case .success(let value), .partialSuccess(let value, _):
            return value
        case .failure(let error):
            throw error
        }
    }
}
