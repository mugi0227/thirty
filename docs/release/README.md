# リリースの準備

2026年10月12日時点のAppleの要件を確認して作成したチェックリストです。
自動で用意できるもの（スクリーンショット、プレビュー動画、文章）と、Apple Developerアカウントで本人が行う手続きを分けています。

## 自動で用意しているもの

| もの | 場所 | 状態 |
| --- | --- | --- |
| App Storeのスクリーンショット（キャプション付き） | [store/iphone-medium](store/iphone-medium/)（1206×2622、必須）、[store/iphone-large](store/iphone-large/)（1320×2868）、[store/ipad-13](store/ipad-13/)（2064×2752、必須）。CIの成果物 `store-*` からも取得可 | 撮影済み |
| App プレビュー動画（886×1920、30fps、H.264、約28秒。デバッグ版で時間を100倍に早送り） | [store/app-preview-iphone-6.9.mp4](store/app-preview-iphone-6.9.mp4) | 録画済み |
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
5. **App内課金を作成**：非消耗型、製品ID `jp.mugilab.thirty.plus`、価格は¥500。表示名と説明、審査用スクリーンショット（Thirty+の画面）は [review-notes.md](review-notes.md)。
6. **署名してアップロード（Macなし、GitHub Actionsで）**
   1. App Store Connect →「ユーザとアクセス」→「統合」→「App Store Connect API」→「チームキー」で「＋」。名前は自由、アクセスは **Admin**（Appleのクラウド署名を使うため）。
   2. 作成後に一度だけダウンロードできる `AuthKey_XXXXXXXXXX.p8` を保存。画面に出る **キーID** と、一覧の上の **Issuer ID** も控える。
   3. GitHubのリポジトリ →「Settings」→「Secrets and variables」→「Actions」→「New repository secret」で3つ登録。
      - `ASC_KEY_ID`：キーID
      - `ASC_ISSUER_ID`：Issuer ID
      - `ASC_KEY_P8`：.p8ファイルをテキストで開いた中身すべて（`-----BEGIN PRIVATE KEY-----` から最後の行まで）
   4. 「Actions」→「Upload to App Store Connect」→「Run workflow」。約15〜25分でTestFlightにビルドが届きます。ビルド番号はワークフローの実行番号で自動的に増えます。
   - 署名証明書やプロビジョニングプロファイルを手で作る必要はありません（Xcodeのクラウド署名）。
   - 先にApp Store Connectで「新規App」を作っておかないと、アップロードは失敗します。
   - Macがある場合は、`cd ios && xcodegen generate` のあとXcodeで Product > Archive → Distribute App でも同じです。
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
今回の申請（Xcode 26、iOS 26 SDK）には不要です。

GitHubのXcode 27イメージ（2026年10月時点）には「iPhone Duo」の機種定義がありますが、それを起動できるiOSのランタイムがありません。iOS 27.0と、ダウンロードしたiOS 27.2のどちらでも「Incompatible device」になりました。
CIの `iphone-duo` ジョブは、Duoに対応したランタイムが入っているかを毎回確かめ、入っていれば撮影まで自動で行います。今はスキップの記録だけが残ります。

## スクリーンショットの作り方

- `ios/UITests/StoreScreenshotTests.swift` がSimulatorを操作して撮影します。時刻は9:41、Simulatorの言語は日本語、通知の許可は出さない設定です。
- 計測中の画面は、開始直後に時計を進める（デバッグ版だけの `-ThirtyJumpAfterStart`）ことで、毎回同じくらいの残り時間で撮れます。
- `scripts/make_store_screenshots.py` が見出しを付けます。書体は日本語の **Zen Kaku Gothic New**（`STORE_FONT=mincho` で **Zen Old Mincho**）。どちらもOFLで、`scripts/fetch_fonts.sh` が取得します。中国語用の書体に切り替わって字形が変わることはありません。
- 横向きの画面は、横長のストア画像（例：2622×1206）として出力します。
- ロック画面の画像は、時計とライブアクティビティの部分だけを切り出し、Simulatorのホーム画面やテスト用のアイコンが写らないようにしています。
