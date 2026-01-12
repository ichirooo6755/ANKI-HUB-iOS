import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

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
    }
}
