import SwiftUI
import UIKit
import Observation

/// ルートの NavigationStack の path を保持し、子から「ホームへ戻る」操作を可能にする。
/// アプリ全体で1つのインスタンスを共有する。
@Observable
final class NavigationCoordinator {
    static let shared = NavigationCoordinator()

    var path = NavigationPath()

    func popToRoot() {
        // SwiftUI の path を空に
        path = NavigationPath()
        // SwiftUI の NavigationLink で push されている画面に対しては、
        // UIKit 経由で UINavigationController を取得して popToRoot する
        DispatchQueue.main.async {
            Self.popUIKitNavigationToRoot()
        }
    }

    private static func popUIKitNavigationToRoot() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              let root = window.rootViewController else { return }
        if let nav = findNavigationController(in: root) {
            nav.popToRootViewController(animated: true)
        }
    }

    private static func findNavigationController(in vc: UIViewController) -> UINavigationController? {
        if let nav = vc as? UINavigationController { return nav }
        if let presented = vc.presentedViewController,
           let nav = findNavigationController(in: presented) {
            return nav
        }
        for child in vc.children {
            if let nav = findNavigationController(in: child) {
                return nav
            }
        }
        return nil
    }
}
