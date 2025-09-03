import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseMessaging

// MARK: - Song Model
struct Song: Identifiable, Codable, Hashable {
    let id: UInt8
    let title: String
    let lyrics: String
    let backgroundColor: String
    let foregroundColor: String
}

// MARK: - App State
final class AppState: ObservableObject {
    @Published var songs: [Song] = []
    @Published var selectedSong: Song? = nil
}

// MARK: - Color Extension
extension Color {
    init(hexOrName: String) {
        self = Color.fromHexOrName(hexOrName) ?? .white
    }

    static func fromHexOrName(_ str: String) -> Color? {
        let s = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "red","rot": return .red
        case "green","grün": return .green
        case "blue","blau": return .blue
        case "black","schwarz": return .black
        case "white","weiß": return .white
        case "yellow","gelb": return .yellow
        case "orange": return .orange
        case "purple","lila": return .purple
        case "pink","rosa": return .pink
        case "gray","grey","grau": return .gray
        default:
            let hex = s.replacingOccurrences(of: "#", with: "")
            if (hex.count == 6 || hex.count == 8), let value = UInt64(hex, radix: 16) {
                let r = Double((value & 0xFF0000) >> 16)/255.0
                let g = Double((value & 0x00FF00) >> 8)/255.0
                let b = Double(value & 0x0000FF)/255.0
                let a: Double = hex.count == 8 ? Double(value & 0x000000FF)/255.0 : 1.0
                return Color(red: r, green: g, blue: b, opacity: a)
            }
            return nil
        }
    }
}

// MARK: - Push Coordinator
final class PushCoordinator: NSObject, ObservableObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = PushCoordinator()
    weak var state: AppState?

    func configure(state: AppState) {
        self.state = state
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(fcmToken ?? "nil")")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handlePush(notification.request.content.body)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        handlePush(response.notification.request.content.body)
        completionHandler()
    }

    private func handlePush(_ body: String) {
        if let song = state?.songs.first(where: { $0.title.lowercased() == body.lowercased() }) {
            DispatchQueue.main.async {
                self.state?.selectedSong = song
            }
        }
    }
}

// MARK: - App Delegate
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
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationView {
            ZStack {
                Color.pink.edgesIgnoringSafeArea(.all)

                VStack(spacing: 12) {
                    Image("tiefblau_white")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250)

                    Image("poster")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)

                    Text("Wilkommen zu 2025/26 Tour!")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    List {
                        ForEach(state.songs) { song in
                            NavigationLink(destination: SongView(song: song)) {
                                Text(song.title)
                            }
                            .listRowBackground(Color.pink)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadSongs()
            }
            // Safe programmatic navigation for push notifications
            .background(
                Group {
                    if let selectedSong = state.selectedSong {
                        NavigationLink(
                            destination: SongView(song: selectedSong),
                            isActive: Binding(
                                get: { state.selectedSong != nil },
                                set: { if !$0 { state.selectedSong = nil } }
                            )
                        ) {
                            EmptyView()
                        }
                    }
                }
            )
        }
    }

    func loadSongs() {
        guard let url = Bundle.main.url(forResource: "songs", withExtension: "json") else {
            print("Songs JSON not found")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            state.songs = try decoder.decode([Song].self, from: data)
        } catch {
            print("Failed to load songs: \(error)")
        }
    }
}

// MARK: - SongView
struct SongView: View {
    let song: Song

    var body: some View {
        ZStack {
            Color(hexOrName: song.backgroundColor).edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 20) {
                    Text(song.title)
                        .font(.largeTitle.bold())
                        .foregroundColor(Color(hexOrName: song.foregroundColor))
                        .multilineTextAlignment(.center)
                    Text(song.lyrics)
                        .font(.body)
                        .foregroundColor(Color(hexOrName: song.foregroundColor))
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }
        }
    }
}

// MARK: - App Entry
@main
struct SongBroadcastApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .onAppear {
                    PushCoordinator.shared.configure(state: state)
                }
        }
    }
}
