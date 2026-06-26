import SwiftUI
import GoogleMobileAds

/// インタースティシャル広告の読み込みと表示を管理する。
/// アプリ全体で1つのインスタンスを共有し、広告は事前にロードしておく。
@Observable
final class InterstitialAdManager: NSObject, FullScreenContentDelegate {
    static let shared = InterstitialAdManager()

    /// テスト広告と本番広告の切り替えフラグ。
    /// - true:  Google 公式のテスト広告を表示（開発・デバッグ用）
    /// - false: 本番の広告を表示（リリース用）
    /// ここを切り替えるだけでテスト/本番を変更できる。
    ///
    /// なお Info.plist の GADApplicationIdentifier も合わせて切り替えること:
    /// - テスト用アプリID: ca-app-pub-3940256099942544~1458002511
    /// - 本番用アプリID:   ca-app-pub-3155724310732667~8195260762
    static let useTestAds = true

    /// Google 公式のテスト用インタースティシャル広告ユニットID。
    private static let testAdUnitID = "ca-app-pub-3940256099942544/4411468910"

    /// 本番のインタースティシャル広告ユニットID（"/"区切り）。
    private static let productionAdUnitID = "ca-app-pub-3155724310732667/2863043033"

    /// 実際に使用する広告ユニットID。useTestAds の値で切り替わる。
    private var adUnitID: String {
        Self.useTestAds ? Self.testAdUnitID : Self.productionAdUnitID
    }

    private var interstitial: InterstitialAd?
    private var isLoading = false

    /// 広告の表示頻度を制御するためのカウンタと時刻。
    /// 「2回に1回」かつ「前回表示から90秒以上経過」の両方を満たしたときだけ表示する。
    private var showRequestCount = 0
    private var lastShownAt: Date?

    /// 最低限あけるインターバル（秒）。
    private static let minimumInterval: TimeInterval = 90

    /// 今回の表示要求で広告を出してよいかを判定する。
    /// 偶数回目（2回に1回）かつ前回表示から90秒以上経過していれば true。
    private func shouldShowAd() -> Bool {
        showRequestCount += 1
        // 2回に1回（2,4,6回目…）のみ表示対象とする
        guard showRequestCount % 2 == 0 else { return false }
        // 前回表示から90秒経っていなければ表示しない
        if let lastShownAt, Date().timeIntervalSince(lastShownAt) < Self.minimumInterval {
            return false
        }
        return true
    }

    /// 広告が閉じられた（または表示できなかった）あとに呼ばれるクロージャ。
    /// 画面遷移などの「広告後の処理」をここで実行する。
    private var onDismiss: (() -> Void)?

    /// SDK初期化後やアプリ起動時に呼び、次の表示に備えて広告を先読みする。
    func loadAd() {
        guard !isLoading, interstitial == nil else { return }
        isLoading = true
        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                print("InterstitialAd load failed: \(error.localizedDescription)")
                self.interstitial = nil
                return
            }
            self.interstitial = ad
            self.interstitial?.fullScreenContentDelegate = self
        }
    }

    /// 広告を表示する。広告が準備できていれば表示し、閉じられたら completion を実行する。
    /// 準備できていない場合は即座に completion を実行し、次回用にロードを開始する。
    @MainActor
    func showAd(completion: @escaping () -> Void) {
        // 表示頻度の条件（2回に1回・前回から90秒以上）を満たさなければ表示しない
        guard shouldShowAd() else {
            completion()
            return
        }
        guard let interstitial,
              let root = Self.rootViewController() else {
            // 広告が無ければ待たせずに次へ進め、次回に備えてロードしておく
            completion()
            loadAd()
            return
        }
        lastShownAt = Date()
        onDismiss = completion
        interstitial.present(from: root)
    }

    // MARK: - GADFullScreenContentDelegate

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("InterstitialAd present failed: \(error.localizedDescription)")
        interstitial = nil
        let handler = onDismiss
        onDismiss = nil
        handler?()
        loadAd()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitial = nil
        let handler = onDismiss
        onDismiss = nil
        handler?()
        // 次の試合開始に備えて再ロード
        loadAd()
    }

    // MARK: - Helpers

    private static func rootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            return nil
        }
        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
