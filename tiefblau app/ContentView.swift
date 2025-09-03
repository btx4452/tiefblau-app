// Capabilities: Push Notifications; Background Modes → Remote notifications
// Swift Package Manager: add Firebase iOS SDKs → FirebaseMessaging, FirebaseCore

import SwiftUI
import UserNotifications
import UIKit
import FirebaseCore
import FirebaseMessaging

// MARK: - App State
final class AppState: ObservableObject {
    @Published var songs: [Song] = []
    @Published var activeSong: Song? = nil
    @Published var useRemoteSetlist: Bool = false
}

// MARK: - Song Model
struct Song: Identifiable, Codable {
    var id: UInt8
    var title: String
    var lyrics: String
    var backgroundColor: String
    var foregroundColor: String
}

// MARK: - Color Extension
extension Color {
    init?(anyHexOrName: String) {
        let s = anyHexOrName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "red", "rot": self = .red
        case "green", "grün": self = .green
        case "blue", "blau": self = .blue
        case "black", "schwarz": self = .black
        case "white", "weiß", "weiss": self = .white
        case "yellow", "gelb": self = .yellow
        case "orange": self = .orange
        case "purple", "lila": self = .purple
        case "pink", "rosa": self = .pink
        case "gray", "grey", "grau": self = .gray
        default:
            let hex = s.replacingOccurrences(of: "#", with: "")
            guard let intVal = UInt64(hex, radix: 16) else { return nil }
            switch hex.count {
            case 6:
                let r = Double((intVal & 0xFF0000) >> 16)/255
                let g = Double((intVal & 0x00FF00) >> 8)/255
                let b = Double(intVal & 0x0000FF)/255
                self = Color(red: r, green: g, blue: b)
            case 8:
                let r = Double((intVal & 0xFF000000) >> 24)/255
                let g = Double((intVal & 0x00FF0000) >> 16)/255
                let b = Double((intVal & 0x0000FF00) >> 8)/255
                let a = Double(intVal & 0x000000FF)/255
                self = Color(red: r, green: g, blue: b, opacity: a)
            default: return nil
            }
        }
    }
}

// MARK: - PushCoordinator
final class PushCoordinator: NSObject, ObservableObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = PushCoordinator()
    weak var appState: AppState?

    private var hasAPNsToken = false
    private var lastFCMToken: String?

    func configure(appState: AppState) {
        self.appState = appState
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    func noteAPNsTokenSet() {
        hasAPNsToken = true
        maybeSubscribe()
    }

    private func maybeSubscribe() {
        guard hasAPNsToken, lastFCMToken != nil else { return }
        Messaging.messaging().subscribe(toTopic: "broadcast") { error in
            if let error = error { print("Topic sub error: \(error)") }
            else { print("Subscribed to topic 'broadcast'") }
        }
    }

    private func activateSong(fromTitle title: String) {
        guard let song = appState?.songs.first(where: { $0.title == title }) else { return }
        DispatchQueue.main.async { self.appState?.activeSong = song }
    }

    func applyNotification(userInfo: [AnyHashable: Any]) {
        var title: String? = nil
        if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any], let body = alert["body"] as? String {
                title = body
            } else if let body = aps["alert"] as? String {
                title = body
            }
        }
        if let title = title {
            activateSong(fromTitle: title)
        }
    }

    // MARK: MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        lastFCMToken = fcmToken
        print("FCM token: \(fcmToken ?? "nil")")
        maybeSubscribe()
    }

    // MARK: UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        applyNotification(userInfo: notification.request.content.userInfo)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        applyNotification(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }
}

// MARK: - AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        let center = UNUserNotificationCenter.current()
        center.delegate = PushCoordinator.shared
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error { print("Notification auth error: \(error)") }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }

        UIApplication.shared.isIdleTimerDisabled = true
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs token: \(tokenString)")
        PushCoordinator.shared.noteAPNsTokenSet()
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
}

// MARK: - Views

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Image("tiefblau_white")
                    .resizable()
                    .scaledToFit()
                Image("tour")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .background(Color.clear)
                Text("Tour 2025/2026")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

//                Toggle("Load setlist from remote JSON", isOn: $state.useRemoteSetlist)
//                    .padding()

                List(state.songs) { song in
                       NavigationLink(song.title, destination: SongView(song: song))
                           .listRowBackground(Color.pink) // row background
                   }
                   .listStyle(PlainListStyle()) // remove default inset/grouped style
                   .background(Color.pink)
            }
            .padding()
            .onAppear { loadSetlist() }
            .background(Color.pink.ignoresSafeArea()) // <--- pink background
        }
    }

    func loadSetlist() {
        if state.useRemoteSetlist {
            guard let url = URL(string: "https://example.com/setlist.json") else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data else { return }
                if let songs = try? JSONDecoder().decode([Song].self, from: data) {
                    DispatchQueue.main.async { state.songs = songs }
                }
            }.resume()
        } else {
            if let url = Bundle.main.url(forResource: "localSetlist", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let songs = try? JSONDecoder().decode([Song].self, from: data) {
                state.songs = songs
            }
        }
    }
}

struct SongView: View {
    let song: Song

    var body: some View {
        ZStack {
            Color(anyHexOrName: song.backgroundColor)?.ignoresSafeArea() ?? Color.gray.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Text(song.title)
                        .font(.largeTitle.bold())
                        .foregroundColor(Color(anyHexOrName: song.foregroundColor) ?? .white)
                    Text(song.lyrics)
                        .font(.body)
                        .foregroundColor(Color(anyHexOrName: song.foregroundColor) ?? .white)
                        .padding()
                }
                .padding()
            }
        }
    }
}


// MARK: - Main App

@main
struct BroadcastSongApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let activeSong = state.activeSong {
                    SongView(song: activeSong)
                        .environmentObject(state)
                } else {
                    ContentView()
                        .environmentObject(state)
                        .onAppear { PushCoordinator.shared.configure(appState: state) }
                }
            }
        }
    }
}
