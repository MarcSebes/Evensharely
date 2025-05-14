//  AuthenticationViewModel.swift
//  Evensharely
//
//  Updated 2025-05-11 to cache current user's friends in the App Group via ProfileCache

import SwiftUI
import AuthenticationServices
import CloudKit

/// Manages Sign in with Apple flow and caches user info (ID, full name, friends) in App Group defaults.
final class AuthenticationViewModel: NSObject, ObservableObject {
    @Published var isSignedIn = false
    
    override init() {
        super.init()
        // Check for existing credentials on initialization
        checkForExistingCredentials()
    }
    
    /// Check if user is already signed in and restore their session
    private func checkForExistingCredentials() {
        // First check if we have a stored Apple ID
        if let appleUserID = UserDefaults.standard.string(forKey: "evensharely_icloudID"),
           !appleUserID.isEmpty {
            
            // Get the stored name
            let fullName = UserDefaults.standard.string(forKey: "evensharely_fullName") ?? ""
            
            print("[AuthVM] Found existing credentials for Apple ID: \(appleUserID)")
            
            // Verify the Apple ID token is still valid
            verifyExistingCredentials(appleUserID: appleUserID, fullName: fullName)
        } else {
            print("[AuthVM] No existing credentials found")
        }
    }
    
    /// Verify that the stored Apple ID credentials are still valid
    private func verifyExistingCredentials(appleUserID: String, fullName: String) {
        // Create a request to check if the Apple ID is still valid
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        
        appleIDProvider.getCredentialState(forUserID: appleUserID) { [weak self] (credentialState, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch credentialState {
                case .authorized:
                    // The Apple ID credential is valid
                    print("[AuthVM] Existing credentials are valid, restoring session")
                    self.restoreUserSession(appleUserID: appleUserID, fullName: fullName)
                    
                case .revoked, .notFound, .transferred:
                    // The Apple ID credential is either revoked, not found, or transferred
                    print("[AuthVM] Existing credentials are invalid (state: \(credentialState)), requiring new sign-in")
                    // Clear any stored credentials
                    self.signOut()
                    
                @unknown default:
                    print("[AuthVM] Unknown credential state: \(credentialState), requiring new sign-in")
                    self.signOut()
                }
            }
        }
    }
    
    /// Restore user session with existing credentials
    private func restoreUserSession(appleUserID: String, fullName: String) {
        // Optional: Fetch latest user profile data from CloudKit
        CloudKitManager.shared.fetchPrivateUserProfile(forAppleUserID: appleUserID) { [weak self] fetchResult in
            guard let self = self else { return }
            
            switch fetchResult {
            case .success(let profile):
                // Update with latest profile data if needed
                let serverName = profile.fullName
                let nameToUse = serverName.isEmpty ? fullName : serverName
                
                // Fetch and cache friends (optional, can be skipped if not needed immediately)
                self.cacheFriendsIfNeeded(profile: profile, appleUserID: appleUserID, nameToUse: nameToUse)
                
            case .failure(let error):
                print("[AuthVM] Failed to fetch profile during session restore: \(error)")
                // Fall back to stored credentials
                self.finalizeSignIn(appleUserID, fullName: fullName)
            }
        }
    }
    
    /// Cache friends for the current user
    private func cacheFriendsIfNeeded(profile: UserProfile, appleUserID: String, nameToUse: String) {
        let friendAppleIDs = profile.friends
        
        if !friendAppleIDs.isEmpty {
            print("[AuthVM] ▶️ Refreshing cached friends for IDs: \(friendAppleIDs)")
            
            CloudKitManager.shared.fetchUserProfiles(forappleUserIDs: friendAppleIDs) { [weak self] friendsResult in
                guard let self = self else { return }
                
                switch friendsResult {
                case .success(let friendProfiles):
                    let cached = friendProfiles.map { fp in
                        CachedUser(id: fp.appleUserID, fullName: fp.fullName)
                    }
                    ProfileCache.save(cached)
                    print("[AuthVM] ✅ Cached \(cached.count) friends: \(cached.map(\.id))")
                    
                    // Ensure the extension sees this immediately
                    if let group = UserDefaults(suiteName: "group.com.marcsebes.evensharely") {
                        group.synchronize()
                    }
                    
                case .failure(let error):
                    print("[AuthVM] Failed to fetch friend profiles for cache: \(error)")
                }
                
                // Complete sign-in
                self.finalizeSignIn(appleUserID, fullName: nameToUse)
            }
        } else {
            // No friends to cache, just complete the sign-in
            finalizeSignIn(appleUserID, fullName: nameToUse)
        }
    }
    
    /// Sign the user out and clear credentials
    func signOut() {
        // Clear stored credentials
        UserDefaults.standard.removeObject(forKey: "evensharely_icloudID")
        UserDefaults.standard.removeObject(forKey: "evensharely_fullName")
        
        // Clear from App Group as well
        if let groupDefaults = UserDefaults(suiteName: "group.com.marcsebes.evensharely") {
            groupDefaults.removeObject(forKey: "evensharely_icloudID")
            groupDefaults.removeObject(forKey: "evensharely_fullName")
            groupDefaults.synchronize()
        }
        
        // Update UI state
        DispatchQueue.main.async {
            self.isSignedIn = false
        }
    }

    /// Called when Sign in with Apple completes.
    func handle(credentialResult: ASAuthorization) {
        print("[AuthVM] handle() invoked with result: \(credentialResult)")

        // 1) Extract Apple credentials
        guard let credential = credentialResult.credential as? ASAuthorizationAppleIDCredential else {
            print("[AuthVM] Invalid credential type")
            return
        }
        let appleUserID    = credential.user
        let nameComponents = credential.fullName
        let email          = credential.email

        // 2) Determine a fallback fullName if Apple didn't provide one
        let realNameKey = "evensharely_fullName"
        let fallbackName: String = {
            if let savedName = UserDefaults.standard.string(forKey: realNameKey),
               !savedName.isEmpty {
                return savedName
            }
            let formatter = PersonNameComponentsFormatter()
            let name = formatter.string(from: nameComponents ?? PersonNameComponents())
            if !name.isEmpty {
                UserDefaults.standard.set(name, forKey: realNameKey)
            }
            return name
        }()


        // 4) Upsert or create the UserProfile
        CloudKitManager.shared.saveOrUpdateUserProfile(
            appleUserID: appleUserID,
            nameComponents: nameComponents,
            email: email
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                print("[AuthVM] saveOrUpdateUserProfile failed: \(err)")
                // On failure, proceed with fallback
                self.finalizeSignIn(appleUserID, fullName: fallbackName)

            case .success:
                print("[AuthVM] saveOrUpdateUserProfile succeeded for Apple ID: \(appleUserID)")

                //5) Fetch the UserProfile including
                let group = DispatchGroup()
                group.notify(queue: .main) {
                    CloudKitManager.shared.fetchPrivateUserProfile(forAppleUserID: appleUserID) { fetchResult in
                        DispatchQueue.main.async {
                            // 6a) Unwrap fetched profile
                            let profile: UserProfile
                            do {
                                profile = try fetchResult.get()
                            } catch {
                                print("[AuthVM] fetchPrivateUserProfile error: \(error)")
                                self.finalizeSignIn(appleUserID, fullName: fallbackName)
                                return
                            }

                            // 6b) Decide which fullName to use
                            let serverName = profile.fullName
                            NSLog("[AuthVM] UserProfile full?Name = \(serverName)")
                            let nameToUse  = serverName.isEmpty ? fallbackName : serverName
                            NSLog("[AuthVM] using fullName:", nameToUse)

                            // 6c) Cache current user's friends into App Group defaults
                            let friendAppleIDs = profile.friends
                            print("[AuthVM] ▶️ Caching friends for IDs: \(friendAppleIDs)")
                            CloudKitManager.shared.fetchUserProfiles(forappleUserIDs: friendAppleIDs) { friendsResult in
                                switch friendsResult {
                                case .success(let friendProfiles):
                                    // Map each fetched profile's recordName (icloudID) →
                                   // into the one-true Apple ID you're using everywhere:
                                    let cached = friendProfiles.map { fp in
                                            CachedUser(id: fp.appleUserID, fullName: fp.fullName)
                                        }
                                         ProfileCache.save(cached)
                                        print("[AuthVM] ✅ Cached \(cached.count) friends: \(cached.map(\.id))")
                            
                                        // ensure the extension sees this immediately
                                        if let group = UserDefaults(suiteName: "group.com.marcsebes.evensharely") {
                                            group.synchronize()
                                        }
                                case .failure(let error):
                                    print("[AuthVM] failed to fetch friend profiles for cache: \(error)")
                                }
                                // 6d) Finally proceed to sign in
                                self.finalizeSignIn(appleUserID, fullName: nameToUse)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Persists the current user's Apple ID and fullName into both standard and App Group defaults, then sets `isSignedIn`.
    private func finalizeSignIn(_ appleUserID: String, fullName: String) {
        print("[AuthVM] finalizeSignIn: ID = \(appleUserID) fullName = \(fullName)")

        // A) Main app defaults
        UserDefaults.standard.set(appleUserID, forKey: "evensharely_icloudID")
        UserDefaults.standard.set(fullName, forKey: "evensharely_fullName")

        // B) Shared App Group defaults for extension
        if let groupDefaults = UserDefaults(suiteName: "group.com.marcsebes.evensharely") {
            groupDefaults.set(appleUserID, forKey: "evensharely_icloudID")
            groupDefaults.set(fullName,     forKey: "evensharely_fullName")
            groupDefaults.synchronize()
            print("[AuthVM] Synced to group defaults: \(appleUserID), \(fullName)")
        }

        // C) Trigger UI update
        DispatchQueue.main.async {
            self.isSignedIn = true
        }
    }
}

// MARK: – Presentation Context for ASAuthorizationController
extension AuthenticationViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
