import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// Where a push should navigate when tapped — mirrors `NotificationDTO.route`
/// and the Android `PushManager.handleRouting`.
enum PushRoute: Equatable {
    case order(Int?)
    case returns
    case inventory
    case notifications
}

/// Central Firebase Cloud Messaging handler for the iOS app (parity with the
/// Android `messaging.PushManager` + `AxFirebaseMessagingService`).
///
/// Responsibilities:
///  - `configure()` boots Firebase and wires the messaging / notification-center delegates,
///  - `requestAuthorization()` asks for the alert/badge/sound permission and registers with APNs,
///  - the messaging delegate registers the rotated FCM token with the backend (when signed in),
///  - notification taps are decoded into a `PushRoute` published on `pendingRoute`, which
///    `MainTabView` observes and applies to the `Router`.
///
/// Backend recommendation: send the routing fields (`type`, `route`, `order_id`) inside the
/// push payload so `routeFromUserInfo` can resolve the destination.
final class PushManager: NSObject, ObservableObject {

    static let shared = PushManager()

    /// Set when a notification tap should navigate; `MainTabView` consumes and clears it.
    @Published var pendingRoute: PushRoute?

    private let lastRegisteredKey = "fcm_last_registered_token"
    private var currentToken: String?

    private override init() { super.init() }

    // MARK: Setup

    /// Boots Firebase and registers the delegates. Call once from the app delegate.
    func configure() {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    /// Requests notification authorization, then registers with APNs on the main thread.
    /// Safe to call after login / when the main UI first appears.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: Token registration

    /// Registers the cached token with the backend if the user is signed in and the
    /// token is new. Called after login and whenever a fresh token arrives.
    func registerCurrentToken() {
        guard let token = currentToken, !token.isEmpty else { return }
        guard let auth = APIClient.shared.token, !auth.isEmpty else { return }   // signed in?
        if UserDefaults.standard.string(forKey: lastRegisteredKey) == token { return }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        Task {
            do {
                try await APIClient.shared.registerDeviceToken(token, deviceId: deviceId)
                UserDefaults.standard.set(token, forKey: lastRegisteredKey)
            } catch {
                // Endpoint may not be live yet — leave it unregistered so a later call retries.
            }
        }
    }

    /// Removes this device's token from the backend (call on logout, before clearing auth).
    func unregister() {
        let token = currentToken ?? Messaging.messaging().fcmToken
        UserDefaults.standard.removeObject(forKey: lastRegisteredKey)
        guard let token, !token.isEmpty else { return }
        Task { try? await APIClient.shared.unregisterDeviceToken(token) }
    }

    // MARK: Routing

    /// Decodes a push payload's routing fields into a `PushRoute`. Mirrors
    /// `NotificationDTO.route`: order → order detail, return → GRN, stock → inventory.
    func routeFromUserInfo(_ userInfo: [AnyHashable: Any]) -> PushRoute {
        let type = (userInfo["type"] as? String) ?? ""
        let route = (userInfo["route"] as? String) ?? ""
        let orderId = Int((userInfo["order_id"] as? String) ?? "")
            ?? (userInfo["order_id"] as? Int)

        if type.hasPrefix("order") || route == "order" { return .order(orderId) }
        if type.hasPrefix("return") || route == "return" { return .returns }
        if type.hasPrefix("stock") || route == "inventory" { return .inventory }
        return .notifications
    }
}

// MARK: - MessagingDelegate

extension PushManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        currentToken = fcmToken
        registerCurrentToken()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushManager: UNUserNotificationCenterDelegate {
    /// Foreground: still show the banner + play sound (matches Android building the
    /// notification in `onMessageReceived`).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
        Task { await NotificationBadge.shared.refresh() }
    }

    /// Tap: decode the destination and publish it for `MainTabView` to navigate.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let route = routeFromUserInfo(userInfo)
        DispatchQueue.main.async {
            self.pendingRoute = route
        }
        completionHandler()
    }
}
