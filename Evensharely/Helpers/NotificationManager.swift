import SwiftUI
import UserNotifications
import UIKit

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var permissionGranted: Bool = false

    func requestBadgePermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.badge]) { [weak self] granted, _ in
            Task { // runs on the main actor
                self?.permissionGranted = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

/// A SwiftUI button that asks the user for badge notification permission and displays the result
struct NotificationPermissionButton: View {
    @ObservedObject private var manager = NotificationManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                manager.requestBadgePermission()
            }) {
                Text("Enable App Badge Notifications")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            if manager.permissionGranted {
                Label("Permission Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Label("Permission Not Granted", systemImage: "xmark.octagon.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}
