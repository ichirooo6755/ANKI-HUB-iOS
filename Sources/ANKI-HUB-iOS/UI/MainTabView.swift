import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    @State private var timerStartRequest: TimerStartRequest?
    @State private var showScanSheet = false
    @State private var showFrontCameraSheet = false

    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var theme = ThemeManager.shared

    @AppStorage(
        "anki_hub_front_camera_start_request_v1",
        store: UserDefaults(suiteName: "group.com.ankihub.ios")
    ) private var frontCameraStartRequest: Double = 0

    private let scanStartRequestKey = "anki_hub_scan_start_request_v1"
    
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
            }
        }
        .onChange(of: frontCameraStartRequest) { _, _ in
            consumeFrontCameraRequest()
        }
        .sheet(item: $timerStartRequest) { req in
            TimerView(startRequest: req)
        }
        .sheet(isPresented: $showScanSheet) {
            ScanView(startScanning: true)
        }
        .sheet(isPresented: $showFrontCameraSheet) {
            FrontCameraView()
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
                timerStartRequest = TimerStartRequest(mode: "custom", minutes: safeMinutes, open: true)
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
        showFrontCameraSheet = false
        showScanSheet = true
    }

    private func startFrontCameraFlow() {
        selectedTab = .study
        showScanSheet = false
        showFrontCameraSheet = true
    }
}
