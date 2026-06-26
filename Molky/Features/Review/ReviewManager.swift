import SwiftUI
import UIKit

/// レビュー誘導まわりの定数と処理をまとめたヘルパー。
enum ReviewManager {
    /// App Store の Apple ID（数字のみ）。App Store Connect で採番されたら設定する。
    /// 例: "1234567890"
    static let appStoreID = "0000000000"

    /// 初回のレビュー誘導を表示済みかどうかを保存するキー。
    static let hasShownFirstReviewKey = "hasShownFirstReview"

    /// App Store のレビュー投稿画面を直接開く URL。
    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    /// App Store のレビュー投稿画面を開く。
    @MainActor
    static func openWriteReview() {
        guard let url = writeReviewURL else { return }
        UIApplication.shared.open(url)
    }
}
