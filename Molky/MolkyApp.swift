import SwiftUI
import SwiftData
import UIKit

@main
struct MolkyApp: App {
    // 広告フロー（UMP 同意 → ATT → 広告初期化）は ATT ダイアログの都合上、
    // アプリがアクティブになってから開始する必要があるため、
    // init() ではなく HomeView の .task から ConsentManager.startAdvertisingFlow() を呼ぶ。

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
