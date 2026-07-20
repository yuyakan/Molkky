import SwiftUI
import UserMessagingPlatform
import AppTrackingTransparency
import GoogleMobileAds

/// 広告表示の前段となる「同意」まわりを一手に管理する。
///
/// アプリ起動時に次の順序で実行する（`startAdvertisingFlow()`）:
///   1. GDPR（EEA/英国/スイス）向けの UMP 同意フォームを必要に応じて表示
///   2. iOS の ATT（App Tracking Transparency）許可をリクエスト
///   3. 上記が確定してから Google Mobile Ads SDK を初期化し、広告を先読みする
///
/// この順序は Google の推奨に従う。ATT は「アプリがアクティブ状態」でないと
/// ダイアログが出ないため、`MolkyApp.init()` ではなく画面表示後
/// （`HomeView` の `.task`）から呼ぶこと。
///
/// 対象地域（EEA/英国/スイス）以外のユーザーには UMP 同意フォームは表示されず、
/// `canRequestAds` は true のまま進むため、日本などの体験は従来どおり変わらない。
/// ATT ダイアログは地域に関わらず（初回のみ）表示される。
@Observable
@MainActor
final class ConsentManager {
    static let shared = ConsentManager()

    /// 広告フローを二重に開始しないためのガード。
    private var didStartFlow = false

    /// テスト時に同意フォームを EEA ユーザーとして強制表示するためのフラグ。
    /// - true:  地域を EEA に偽装して常に同意フォームの挙動を確認できる（開発用）
    /// - false: 実際のユーザー所在地に従う（リリース用）
    ///
    /// リリース前に必ず false に戻すこと。
    static let useDebugEEA = false

    /// テスト端末のハッシュ化 ID。debug 地域偽装を効かせるために設定する。
    /// Xcode 実行時のコンソールログ（"To enable debug mode for this device..."）に
    /// 表示される値を貼り付ける。空のままでもシミュレータでは EEA 偽装が効く。
    private static let testDeviceIdentifiers: [String] = []

    /// 広告リクエストが可能かどうか。
    /// `requestConsentInfoUpdate` を呼ぶまでは常に false。同意取得（または対象外地域での
    /// 即時許可）後に true になる。広告の初期化・ロードはこれが true になってから行う。
    var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    /// 設定画面に「プライバシー設定」導線を出すべきかどうか。
    /// 同意フォームを再提示できる地域（EEA など）でのみ true になる。
    var isPrivacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// アプリ起動後（画面表示後）に一度だけ呼ぶ。
    /// UMP 同意 → ATT 許可 → 広告 SDK 初期化・先読み、の順に実行する。
    /// ATT ダイアログはアプリがアクティブ状態でないと出ないため、
    /// `HomeView` の `.task` など画面表示後のタイミングから呼ぶこと。
    func startAdvertisingFlow() {
        guard !didStartFlow else { return }
        didStartFlow = true

        gatherConsentIfNeeded { [weak self] in
            // UMP 同意が確定してから ATT を要求し、その完了後に広告を初期化する。
            self?.requestTrackingThenStartAds()
        }
    }

    /// ATT（App Tracking Transparency）の許可をリクエストし、
    /// 結果に関わらず（許可・拒否とも）広告 SDK の初期化へ進む。
    private func requestTrackingThenStartAds() {
        ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
            // このコールバックは任意スレッドで来るため、MainActor に戻して続行する。
            Task { @MainActor in
                self?.startAdsIfAllowed()
            }
        }
    }

    /// 同意状況が許せば Google Mobile Ads SDK を初期化し、最初の広告を先読みする。
    private func startAdsIfAllowed() {
        guard canRequestAds else { return }
        MobileAds.shared.start { _ in
            InterstitialAdManager.shared.loadAd()
        }
    }

    /// 同意状況を更新し、必要であれば同意フォームを提示する。
    /// 完了（同意取得済み・対象外地域・エラーのいずれか）後に completion を呼ぶ。
    private func gatherConsentIfNeeded(completion: @escaping () -> Void) {
        let parameters = RequestParameters()

        if Self.useDebugEEA {
            let debugSettings = DebugSettings()
            debugSettings.geography = .EEA
            debugSettings.testDeviceIdentifiers = Self.testDeviceIdentifiers
            parameters.debugSettings = debugSettings
        }

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            if let error {
                // 同意情報の更新に失敗しても、アプリの利用は妨げない。
                // canRequestAds は false のままになり得るため、広告は出ないが安全側に倒す。
                print("Consent info update failed: \(error.localizedDescription)")
                completion()
                return
            }
            // 対象地域なら同意フォームを提示し、対象外なら即座に完了する。
            self?.presentFormIfRequired(completion: completion)
        }
    }

    private func presentFormIfRequired(completion: @escaping () -> Void) {
        guard let root = Self.rootViewController() else {
            completion()
            return
        }
        ConsentForm.loadAndPresentIfRequired(from: root) { error in
            if let error {
                print("Consent form present failed: \(error.localizedDescription)")
            }
            completion()
        }
    }

    /// 設定画面の「プライバシー設定」から呼び、同意フォームを再提示する。
    /// ユーザーが後から同意内容を変更・撤回できるようにするための導線（EU の要件）。
    func presentPrivacyOptions() {
        guard let root = Self.rootViewController() else { return }
        ConsentForm.presentPrivacyOptionsForm(from: root) { error in
            if let error {
                print("Privacy options form present failed: \(error.localizedDescription)")
            }
        }
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
