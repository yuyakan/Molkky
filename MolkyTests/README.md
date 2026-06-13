# MolkyTests

純粋ロジック `GameEngine` の XCTest スイート。

## Xcode でテストターゲットを追加する手順

1. Xcode で `Molky.xcodeproj` を開く。
2. プロジェクトナビゲータでプロジェクト「Molky」を選択 → `+` で **Unit Testing Bundle** を追加。
3. ターゲット名は `MolkyTests`、Host Application は `Molky` を指定。
4. 既定で作成された `MolkyTests.swift` は削除して、本ディレクトリ内の `EngineTests/` 配下を Xcode のテストグループへドラッグ＆ドロップ（`Copy items if needed` は **OFF**、`Add to targets` で `MolkyTests` のみ ON）。
5. `Product > Test`（⌘U）で実行。

`GameEngine` は SwiftUI/SwiftData に依存しないため、UI が未完成でもこのスイートは独立して動作する。
