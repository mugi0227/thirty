# リリースの準備

2026年10月12日時点のAppleの要件を確認して作成したチェックリストです。
自動で用意できるもの（スクリーンショット、プレビュー動画、文章）と、Apple Developerアカウントで本人が行う手続きを分けています。

## 自動で用意しているもの

| もの | 場所 | 状態 |
| --- | --- | --- |
| App Storeのスクリーンショット（キャプション付き） | GitHub Actionsの成果物 `store-iphone-medium` / `store-iphone-large` / `store-ipad-13`、[images](images/) | CIで撮影 |
| App プレビュー動画（886×1920、30fps、H.264、約25秒） | 成果物 `app-preview-video`、[images](images/) | CIで録画 |
| 説明文、キーワード、サブタイトルなど | [metadata-ja.md](metadata-ja.md) | 下書き済み |
| プライバシーポリシー | [privacy-policy.md](privacy-policy.md) | 下書き済み |
| サポートページ | [support.md](support.md) | 下書き済み |
| App Reviewへのメモ、App内課金の情報 | [review-notes.md](review-notes.md) | 下書き済み |
| プライバシーマニフェスト | `ios/Thirty/PrivacyInfo.xcprivacy`、`ios/Widgets/PrivacyInfo.xcprivacy` | 追加済み（追跡なし、収集なし、UserDefaultsの理由 CA92.1） |
| 暗号化の申告 | `ITSAppUsesNonExemptEncryption = NO` | 設定済み |
| バージョン | 1.0.0（ビルド1） | 設定済み |

## Appleの要件で確認したこと

- **Xcode 26以降でのビルドが必須**（2026年4月28日から）。CIは `macos-26` イメージ（Xcode 26.6）に切り替えました。手元でアーカイブする場合もXcode 26以降を使ってください。
- **スクリーンショットの必須サイズ**
  - iPhone with Dynamic Island（中）：1206×2622 など。**必須**。iPhone 17のSimulatorで撮影。
  - iPhone with Dynamic Island（大）：1320×2868 など。任意だが用意（iPhone 17 Pro Max）。
  - iPad 13インチ：2064×2752 など。**iPadで動くので必須**（iPad Pro 13-inch (M5)）。
  - 1サイズあたり1〜10枚、JPEG/PNG、透明なし。小さいサイズは自動で縮小されます。
- **iPhone Duo**：外側 1398×2034、内側 2007×2853。**2027年4月から、iOS 27.1 SDK以降でビルドするアプリで必須**。今の提出（iOS 26 SDK）では不要です。GitHubのXcode 27イメージにDuoのSimulatorがあるかをCIで調べています（下記）。
- **App プレビュー動画**：任意。15〜30秒、30fps以下、H.264、iPhone 6.9インチとiPhone Duoは886×1920。音声はステレオが必要なので無音のステレオトラックを付けています。
- **年齢制限**：新しい質問票（4+／9+／13+／16+／18+）。Thirtyはすべて「なし」で4+になる想定です。
- **アクセシビリティ（Nutrition Labels）**：現在は任意。実機で確認できた項目だけ申告してください。

## あなたが行う手続き

1. **Apple Developer Program** に登録（年会費あり）。
2. App Store Connectの「契約／税金／口座情報」で **有料App契約** を有効にする（App内課金に必要）。税と銀行口座も登録。
3. **App IDを作る**：`jp.mugilab.thirty`（App）と `jp.mugilab.thirty.widgets`（ウィジェット拡張）。Xcodeの自動署名でも作られます。
4. App Store Connectで **新規App** を作成。名前は [metadata-ja.md](metadata-ja.md) の案、プライマリ言語は日本語、Bundle IDは上記。
5. **App内課金を作成**：非消耗型、製品ID `jp.mugilab.thirty.plus`、価格は案で¥480。表示名と説明、審査用スクリーンショット（Thirty+の画面）は [review-notes.md](review-notes.md)。
6. **署名してアップロード**
   ```sh
   cd ios
   DEVELOPMENT_TEAM=あなたのチームID xcodegen generate
   open Thirty.xcodeproj   # Product > Archive → Distribute App → App Store Connect
   ```
7. **TestFlightで実機確認**。特に次の項目：
   - ロック画面、StandBy、Dynamic Islandの表示（Thirty+）
   - ホーム／ロック画面のウィジェット、コントロールセンター、アクションボタン、アイコン長押し
   - アクセスガイドの開始と、「×3」の案内が消えること
   - 伏せたときに画面が消えること、画面の明るさが元に戻ること
   - 終了音と背景の通知、Sandboxでの購入と復元
8. App Store Connectに **文章、スクリーンショット、動画** を入れ、**Appのプライバシー** は「データを収集しない」、**年齢制限** の質問票に回答、**App内課金をこのバージョンに追加** して審査に提出。
9. EUでも配信する場合は **DSAのトレーダー情報** の申告が必要です（個人の場合、住所などが公開されます）。最初は日本だけで配信する選択もできます。

## iPhone Duoについて

App Storeの仕様ページにiPhone Duoの画面サイズが載っています。必須になるのは2027年4月からで、条件はiOS 27.1 SDK以降でのビルドです。
今回の申請には要りませんが、CIの `iphone-duo-probe` ジョブで、GitHubのXcode 27イメージにDuoのSimulatorが入っているかを毎回記録します。入り次第、撮影ジョブに追加します。
