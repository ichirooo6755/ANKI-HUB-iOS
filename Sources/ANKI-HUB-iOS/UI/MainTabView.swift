import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    @State private var timerStartRequest: PomodoroStartRequest?

    @ObservedObject private var theme = ThemeManager.shared
    
    enum Tab {
        case home
        case calendar
        case study
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

                CalendarView()
                    .tabItem {
                        Label("カレンダー", systemImage: "calendar")
                    }
                    .tag(Tab.calendar)

                StudyView()
                    .tabItem {
                        Label("学習", systemImage: "book.fill")
                    }
                    .tag(Tab.study)

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
        }
        .onOpenURL { url in
            #if os(iOS)
            SupabaseAuthService.shared.handleIncomingCallbackURL(url)
            #endif
            handleDeepLink(url)
        }
        .sheet(item: $timerStartRequest) { req in
            PomodoroView(startRequest: req)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "sugwranki" else { return }
        guard url.host == "timer" else { return }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let minutes = comps?.queryItems?.first(where: { $0.name == "minutes" })?.value
        let parsedMinutes = Int(minutes ?? "")
        let safeMinutes = max(1, min(180, parsedMinutes ?? 25))

        if url.path == "/start" {
            timerStartRequest = PomodoroStartRequest(mode: "custom", minutes: safeMinutes, open: true)
        }
    }
}
