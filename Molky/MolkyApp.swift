import SwiftUI
import SwiftData
import UIKit
import GoogleMobileAds

@main
struct MolkyApp: App {
    init() {
        // まず GDPR（EEA・英国・スイス）向けの同意を取得する。
        // 同意が確定（または対象外地域）してから広告 SDK を初期化・先読みすることで、
        // 同意なしに広告データ処理が始まらないようにする。
        ConsentManager.shared.gatherConsentIfNeeded {
            guard ConsentManager.shared.canRequestAds else { return }
            MobileAds.shared.start { _ in
                InterstitialAdManager.shared.loadAd()
            }
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
