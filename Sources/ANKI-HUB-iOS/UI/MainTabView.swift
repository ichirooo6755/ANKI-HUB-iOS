import SwiftUI
import OSLog

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    @State private var activeSheet: ActiveSheet?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject private var theme = ThemeManager.shared

    private let logger = Logger(subsystem: "com.ankihub.ios", category: "MainTabView")

    @AppStorage(
        "anki_hub_front_camera_start_request_v1",
        store: UserDefaults(suiteName: "group.com.ankihub.ios")
    ) private var frontCameraStartRequest: Double = 0

    private let scanStartRequestKey = "anki_hub_scan_start_request_v1"

    private struct ActiveSheet: Identifiable {
        enum Kind {
            case timer(TimerStartRequest)
            case scan
            case frontCamera
            case sessionPin
        }

        let kind: Kind

        var id: String {
            switch kind {
            case .scan:
                return "scan"
            case .frontCamera:
                return "frontCamera"
            case .timer(let req):
                return "timer_\(req.mode)_\(req.minutes)"
            case .sessionPin:
                return "sessionPin"
            }
        }
    }
    
    enum Tab {
        case home
        case study
        case calendar
        case profile
    }
    
    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("ホーム", systemImage: "house.fill")
                    }
                    .tag(Tab.home)

                StudyView()
                    .tabItem {
                        Label("学習", systemImage: "book.fill")
                    }
                    .tag(Tab.study)

                AppCalendarView()
                    .tabItem {
                        Label("カレンダー", systemImage: "calendar")
                    }
                    .tag(Tab.calendar)

                SettingsView()
                    .tabItem {
                        Label("マイページ", systemImage: "person.circle.fill")
                    }
                    .tag(Tab.profile)
            }
        }
        .applyAppTheme()
        .onAppear {
            MasteryTracker.shared.loadData()
            consumeFrontCameraRequest()
            checkScanRequest()
        }
        .onOpenURL { url in
            #if os(iOS)
            SupabaseAuthService.shared.handleIncomingCallbackURL(url)
            #endif
            handleDeepLink(url)
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                consumeFrontCameraRequest()
                checkScanRequest()
                theme.updateSystemColorScheme(colorScheme)
            }
            logger.log("scenePhase changed to \(String(describing: newValue), privacy: .public) selectedThemeId=\(theme.selectedThemeId, privacy: .public)")
        }
        .onChange(of: colorScheme) { _, newValue in
            theme.updateSystemColorScheme(newValue)
        }
        .onChange(of: frontCameraStartRequest) { _, _ in
            consumeFrontCameraRequest()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet.kind {
            case .timer(let req):
                TimerView(startRequest: req)
            case .scan:
                ScanView(startScanning: true)
            case .frontCamera:
                FrontCameraView()
            case .sessionPin:
                PinRecordingSheet()
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "sugwranki" else { return }
        switch url.host {
        case "timer":
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let minutes = comps?.queryItems?.first(where: { $0.name == "minutes" })?.value
            let parsedMinutes = Int(minutes ?? "")
            let safeMinutes = max(1, min(180, parsedMinutes ?? 25))

            if url.path == "/start" {
                activeSheet = ActiveSheet(kind: .timer(TimerStartRequest(mode: "custom", minutes: safeMinutes, open: true)))
            }
        case "scan":
            if url.path == "/start" {
                startScannerFlow()
            }
        case "camera":
            if url.path == "/front" || url.path == "/start" {
                startFrontCameraFlow()
            }
        case "tab":
            switch url.path {
            case "/study":
                selectedTab = .study
            case "/calendar":
                selectedTab = .calendar
            case "/home":
                selectedTab = .home
            case "/profile":
                selectedTab = .profile
            default:
                break
            }
        case "session":
            switch url.path {
            case "/start":
                selectedTab = .study
                StudySessionManager.shared.startSession()
            case "/stop":
                selectedTab = .study
                StudySessionManager.shared.stopSession()
            case "/pin":
                selectedTab = .study
                if !StudySessionManager.shared.isSessionActive {
                    StudySessionManager.shared.startSession()
                }
                activeSheet = ActiveSheet(kind: .sessionPin)
            default:
                break
            }
        default:
            break
        }
    }

    private func checkScanRequest() {
        guard let defaults = UserDefaults(suiteName: "group.com.ankihub.ios") else { return }
        guard defaults.object(forKey: scanStartRequestKey) != nil else { return }
        defaults.removeObject(forKey: scanStartRequestKey)
        startScannerFlow()
    }

    private func consumeFrontCameraRequest() {
        guard frontCameraStartRequest > 0 else { return }
        frontCameraStartRequest = 0
        startFrontCameraFlow()
    }

    private func startScannerFlow() {
        selectedTab = .study
        activeSheet = ActiveSheet(kind: .scan)
    }

    private func startFrontCameraFlow() {
        selectedTab = .study
        activeSheet = ActiveSheet(kind: .frontCamera)
    }
}
