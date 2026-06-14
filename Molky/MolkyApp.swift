import SwiftUI
import SwiftData
import UIKit

@main
struct MolkyApp: App {
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
