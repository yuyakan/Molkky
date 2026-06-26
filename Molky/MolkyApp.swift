import SwiftUI
import SwiftData
import UIKit
import GoogleMobileAds

@main
struct MolkyApp: App {
    init() {
        // Google Mobile Ads SDK を初期化し、最初のインタースティシャル広告を先読みする
        MobileAds.shared.start { _ in
            InterstitialAdManager.shared.loadAd()
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Member.self, Game.self, Team.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .dynamicTypeSize(UIDevice.current.userInterfaceIdiom == .pad ? .xxLarge : .large)
        }
        .modelContainer(sharedModelContainer)
    }
}
