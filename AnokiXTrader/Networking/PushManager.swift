import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// The id fields a notification payload can carry. FCM `data` values are always strings,
/// while the in-app feed sends them as numbers — `PushIds` normalises both.
struct PushIds: Equatable {
    var orderId: Int?
    var grnId: Int?
    var grvId: Int?
    var invoiceId: Int?
    var productId: String?
    var promotionId: String?
    var transactionId: String?
    var notificationId: String?

    /// Reads the ids out of a push payload's `userInfo`, coercing `Int`/`String`/`"0"`.
    static func from(userInfo: [AnyHashable: Any]) -> PushIds {
        PushIds(orderId: int(userInfo["order_id"]),
                grnId: int(userInfo["grn_id"]),
                grvId: int(userInfo["grv_id"]),
                invoiceId: int(userInfo["invoice_id"]),
                productId: string(userInfo["product_id"]),
                promotionId: string(userInfo["promotion_id"]),
                transactionId: string(userInfo["transaction_id"]),
                notificationId: string(userInfo["notification_id"]))
    }

    /// `nil` for a missing id or the backend's "no id" placeholder of 0.
    private static func int(_ value: Any?) -> Int? {
        let n = (value as? Int) ?? Int((value as? String) ?? "")
        return (n ?? 0) > 0 ? n : nil
    }

    private static func string(_ value: Any?) -> String? {
        let s = (value as? String) ?? (value as? Int).map { String($0) }
        guard let s, !s.isEmpty, s != "0" else { return nil }
        return s
    }
}

/// Where a push (or an in-app notification row) navigates when tapped. Applied by
/// `Router.apply` — the iOS counterpart of the Android `PushManager.navigate`.
enum PushRoute: Equatable {
    case order(Int?)
    /// The trader has no Deliveries screen — this opens the order's tracking timeline, i.e.
    /// the same destination as `.order`. Kept separate so the feed row can show the delivery
    /// icon rather than the orders one (parity with Android's `ROUTE_DELIVERY`).
    case delivery(Int?)
    case grv
    case returns
    case invoice
    case finance
    case wallet
    case inventory
    case vas
    case promotion
    case product(String?)
    case marketplace
    case cart
    case report
    case rewards
    case settings
    /// The feed itself — also the fallback for a payload we can't place.
    case notifications

    /// Resolves the destination for a payload. An explicit, recognised `route` wins;
    /// otherwise the `type` prefix decides. Kept in lockstep with the Android
    /// `PushManager.routeKey` — see `FCM-settings/3-Event-Catalogue.md`.
    ///
    /// The ids break a tie when the two disagree. The server groups events into broad
    /// screen families, so a payload can name a route it cannot actually be placed on:
    /// `grv.confirmed` arrives as `route=delivery` carrying only a `grv_id`, and the
    /// delivery screens are keyed by order. When the named route needs an id the payload
    /// does not carry and the `type` resolves to somewhere we *can* open, the type wins.
    static func resolve(type: String?, route: String?, ids: PushIds) -> PushRoute {
        let derived = fromType(type, ids: ids)
        guard let explicit = fromRoute(route, ids: ids) else { return derived ?? .notifications }
        if let derived, explicit != derived, !explicit.canOpen, derived.canOpen { return derived }
        return explicit
    }

    /// True when this payload can actually land somewhere. Only the destinations that
    /// dead-end at the notifications feed without an id are "can't open" — the rest fall
    /// back to their own list screen, which is a real answer and must not be overridden.
    private var canOpen: Bool {
        switch self {
        case .order(let id), .delivery(let id): return id != nil
        default:                                return true
        }
    }

    /// The destination named outright by `route`, or nil when it names none we know.
    private static func fromRoute(_ route: String?, ids: PushIds) -> PushRoute? {
        switch (route ?? "").trimmingCharacters(in: .whitespaces).lowercased() {
        case "order":             return .order(ids.orderId)
        case "delivery":          return .delivery(ids.orderId)
        case "grv":               return .grv
        case "return":            return .returns
        case "invoice":           return .invoice
        case "finance":           return .finance
        case "wallet":            return .wallet
        case "inventory":         return .inventory
        case "vas":               return .vas
        case "promotion":         return .promotion
        case "product":           return .product(ids.productId)
        case "marketplace":       return .marketplace
        case "cart":              return .cart
        case "report":            return .report
        case "rewards":           return .rewards
        case "settings":          return .settings
        case "notifications":     return .notifications
        default:                  return nil
        }
    }

    /// The destination implied by the event type, e.g. "order.status" → `.order`;
    /// nil when the type says nothing, so it never overrides an explicit route.
    private static func fromType(_ type: String?, ids: PushIds) -> PushRoute? {
        let t = (type ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if t.hasPrefix("order")     { return .order(ids.orderId) }
        if t.hasPrefix("delivery")  { return .delivery(ids.orderId) }
        if t.hasPrefix("grv")       { return .grv }
        if t.hasPrefix("return")    { return .returns }
        if t.hasPrefix("invoice")   { return .invoice }
        if t.hasPrefix("payment") || t.hasPrefix("payout") || t.hasPrefix("finance") { return .finance }
        if t.hasPrefix("wallet")    { return .wallet }
        if t.hasPrefix("stock")     { return .inventory }
        if t.hasPrefix("vas")       { return .vas }
        if t.hasPrefix("promotion") { return .promotion }
        if t.hasPrefix("product")   { return .product(ids.productId) }
        if t.hasPrefix("cart")      { return .cart }
        if t.hasPrefix("report") || t.hasPrefix("pos") { return .report }
        if t.hasPrefix("rewards")   { return .rewards }
        if t.hasPrefix("security")  { return .settings }
        return nil
    }
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
/// Backend contract: iOS needs the alert in `apns.payload.aps`, with the routing fields
/// (`type`, `route`, `order_id`, `grn_id`, `product_id`, …) alongside it so they land in
/// `userInfo` for `routeFromUserInfo`. See `FCM-settings/3-Event-Catalogue.md`.
final class PushManager: NSObject, ObservableObject {

    static let shared = PushManager()

    /// Set when a notification tap should navigate; `MainTabView` consumes and clears it.
    @Published var pendingRoute: PushRoute?

    private let lastRegisteredKey = "fcm_last_registered_token"
    private var currentToken: String?

    /// Recently-handled `notification_id`s. FCM delivers at-least-once, so the same push
    /// can arrive twice; without this the duplicate would trigger a second badge refresh
    /// and re-navigate. Bounded — the app can run for days.
    private var seen: [String] = []
    private let seenLimit = 64

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

    /// Decodes a push payload's routing fields into a `PushRoute`, using the same
    /// resolver as the in-app feed (`NotificationDTO.route`).
    func routeFromUserInfo(_ userInfo: [AnyHashable: Any]) -> PushRoute {
        PushRoute.resolve(type: userInfo["type"] as? String,
                          route: userInfo["route"] as? String,
                          ids: PushIds.from(userInfo: userInfo))
    }

    /// True the first time this payload is seen, false for an FCM redelivery of it.
    /// Payloads with no `notification_id` are always treated as new.
    func isFirstDelivery(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let id = PushIds.from(userInfo: userInfo).notificationId else { return true }
        if seen.contains(id) { return false }
        seen.append(id)
        if seen.count > seenLimit { seen.removeFirst() }
        return true
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
        guard isFirstDelivery(notification.request.content.userInfo) else { return }
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
