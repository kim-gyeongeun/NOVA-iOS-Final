import SwiftUI

@main struct NOVAApp: App {
    @StateObject private var store = NovaStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}

// Four primary destinations. Less frequently used experiments remain available
// through the Home > All tools route; no existing feature is deleted.
struct RootView: View {
    @State private var tab = 0
    @State private var requestedProvider: AIProvider?

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView(tab: $tab, requestedProvider: $requestedProvider)
            }
            .tabItem { Label("홈", systemImage: "house") }.tag(0)

            NavigationStack {
                AIHubView(requestedProvider: $requestedProvider)
            }
            .tabItem { Label("채팅", systemImage: "bubble.left.and.bubble.right") }.tag(1)

            NavigationStack {
                TeamsView()
            }
            .tabItem { Label("AI 협업", systemImage: "person.3") }.tag(2)

            NavigationStack {
                VaultView()
            }
            .tabItem { Label("보관함", systemImage: "square.stack") }.tag(3)
        }
        .tint(NovaStyle.accent)
    }
}
