import SwiftUI
import UIKit

/// レビュー誘導まわりの定数と処理をまとめたヘルパー。
enum ReviewManager {
    /// App Store の Apple ID（数字のみ）。App Store Connect で採番された値。
    static let appStoreID = "6779970818"

    /// 初回のレビュー誘導を表示済みかどうかを保存するキー。
    static let hasShownFirstReviewKey = "hasShownFirstReview"

    /// App Store のレビュー投稿画面を直接開く URL。
    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    /// App Store のアプリページ URL（レビュー投稿画面が開けなかった場合のフォールバック）。
    static var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    /// App Store のレビュー投稿画面を開く。
    /// 投稿画面が開けなかった場合はアプリページにフォールバックする。
    @MainActor
    static func openWriteReview() {
        guard let url = writeReviewURL else { return }
        UIApplication.shared.open(url) { success in
            if !success, let fallback = appStoreURL {
                UIApplication.shared.open(fallback)
            }
        }
    }
}
