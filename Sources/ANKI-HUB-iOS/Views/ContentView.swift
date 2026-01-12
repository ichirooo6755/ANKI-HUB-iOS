import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(0)
            
            WordbookView()
                .tabItem {
                    Label("ライブラリ", systemImage: "books.vertical.fill")
                }
                .tag(1)
            
            ManagementView()
                .tabItem {
                    Label("管理", systemImage: "gear")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "person.fill")
                }
                .tag(3)
        }
        .applyAppTheme()
    }
}

// Previews removed for SPM
