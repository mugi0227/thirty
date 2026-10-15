# リリースの準備

2026年10月12日時点のAppleの要件を確認して作成したチェックリストです。
自動で用意できるもの（スクリーンショット、プレビュー動画、文章）と、Apple Developerアカウントで本人が行う手続きを分けています。

## 自動で用意しているもの

| もの | 場所 | 状態 |
| --- | --- | --- |
| App Storeのスクリーンショット（キャプション付き） | [store/iphone-medium](store/iphone-medium/)（1206×2622、必須）、[store/iphone-large](store/iphone-large/)（1320×2868）、[store/ipad-13](store/ipad-13/)（2064×2752、必須）。CIの成果物 `store-*` からも取得可 | 撮影済み |
| App プレビュー動画（886×1920、30fps、H.264、約23.6秒。デバッグ版の早送り録画に見出し、Dynamic Islandの拡大、音を追加） | [store/app-preview-iphone-6.9.mp4](store/app-preview-iphone-6.9.mp4) | 編集済み |
| 説明文、キーワード、サブタイトルなど | [metadata-ja.md](metadata-ja.md) | 下書き済み |
| プライバシーポリシー | [site/privacy-policy.md](../../site/privacy-policy.md)（公開先と手順は [site/README.md](../../site/README.md)） | 下書き済み |
| サポートページ | [site/support.md](../../site/support.md)（公開先と手順は [site/README.md](../../site/README.md)） | 下書き済み |
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
- **App プレビュー動画**：任意。15〜30秒、30fps以下、H.264、iPhone 6.9インチとiPhone Duoは886×1920。今回はステレオの背景音、開始操作の音、アプリの終了音を付けています。
- **年齢制限**：新しい質問票（4+／9+／13+／16+／18+）。Thirtyはすべて「なし」で4+になる想定です。
- **アクセシビリティ（Nutrition Labels）**：現在は任意。実機で確認できた項目だけ申告してください。

## あなたが行う手続き

1. **Apple Developer Program** に登録（年会費あり）。
2. App Store Connectの「契約／税金／口座情報」で **有料App契約** を有効にする（App内課金に必要）。税と銀行口座も登録。
3. **App IDを作る**：`jp.mugilab.thirty`（App）と `jp.mugilab.thirty.widgets`（ウィジェット拡張）。本体は明示的なIDでIn-App Purchaseを有効にします。
4. App Store Connectで **新規App** を作成。名前は [metadata-ja.md](metadata-ja.md) の案、プライマリ言語は日本語、Bundle IDは上記。
5. **App内課金を確認**：非消耗型、製品ID `jp.mugilab.thirty.diagnostic`、価格は¥500。2026年10月15日に実機で取得できた既存レコードを正式なThirty+に転用したため、新規作成は不要です。表示名と説明、審査用スクリーンショット（Thirty+の画面）は [review-notes.md](review-notes.md)。旧ID `jp.mugilab.thirty.plus` は購入履歴の復元用としてアプリが認識します。
6. **署名してアップロード（Macなし、GitHub Actionsで）**
   1. App Store Connect →「ユーザとアクセス」→「統合」→「App Store Connect API」→「チームキー」で「＋」。名前は自由、アクセスは **Admin**（配布用プロファイルの取得・作成に使います）。
   2. 作成後に一度だけダウンロードできる `AuthKey_XXXXXXXXXX.p8` を保存。画面に出る **キーID** と、一覧の上の **Issuer ID** も控える。
   3. GitHubのリポジトリ →「Settings」→「Secrets and variables」→「Actions」→「New repository secret」で、APIキー3つと配布用署名2つを登録（2026/10/13時点では登録済み）。
      - `ASC_KEY_ID`：キーID
      - `ASC_ISSUER_ID`：Issuer ID
      - `ASC_KEY_P8`：.p8ファイルをテキストで開いた中身すべて（`-----BEGIN PRIVATE KEY-----` から最後の行まで）
      - `THIRTY_SIGNING_P12`：既存の配布用証明書と秘密鍵を含む、暗号化したPKCS#12のBase64
      - `THIRTY_SIGNING_PASSWORD`：PKCS#12のパスワード
   4. 「Actions」→「Upload to App Store Connect」→「Run workflow」。アップロードとAppleの処理が終わるとTestFlightにビルドが届きます。ビルド番号はワークフローの実行番号で自動的に増えます。
   - CIは既存の配布用署名を再利用し、本体とウィジェットに合うApp Store用プロファイルを取得・作成します。新しい証明書の発行や既存証明書の失効は行いません。
   - 署名を更新する場合は、`scripts/ci/install_signing.py` の証明書ID・指紋と上の署名Secrets、対応するプロファイルを合わせて更新します。秘密鍵・パスワードはGitに入れません。
   - 先にApp Store Connectで「新規App」を作っておかないと、アップロードは失敗します。
   - Macがある場合は、`cd ios && xcodegen generate` のあとXcodeで Product > Archive → Distribute App でも同じです。
7. **TestFlightで実機確認**。特に次の項目：
   - ロック画面、StandBy、Dynamic Islandの表示（Thirty+）
   - ホーム／ロック画面のウィジェット、コントロールセンター、アクションボタン、アイコン長押し
   - アクセスガイドの開始と、「×3」の案内が消えること
   - 伏せたときに画面が消えること、画面の明るさが元に戻ること
   - 終了音と背景の通知、Sandboxでの購入と復元
8. 「Actions」→「Fill App Store listing」→「Run workflow」で、**文章、カテゴリ、URL、審査メモ、スクリーンショット、動画** をまとめて入力（`release/metadata-ja.json` と `scripts/asc_metadata.py`）。残りは画面で：価格（無料）、**Appのプライバシー**（データを収集しない）、**年齢制限**（すべて「なし」）、審査の連絡先、**ビルドとApp内課金をこのバージョンに追加**、審査に提出。
9. EUでも配信する場合は **DSAのトレーダー情報** の申告が必要です（個人の場合、住所などが公開されます）。最初は日本だけで配信する選択もできます。

## iPhone Duoについて

App Storeの仕様ページにiPhone Duoの画面サイズが載っています。必須になるのは2027年4月からで、条件はiOS 27.1 SDK以降でのビルドです。
今回の申請（Xcode 26、iOS 26 SDK）には不要です。

GitHubのXcode 27イメージ（2026年10月時点）には「iPhone Duo」の機種定義がありますが、それを起動できるiOSのランタイムがありません。iOS 27.0と、ダウンロードしたiOS 27.2のどちらでも「Incompatible device」になりました。
CIの `iphone-duo` ジョブは、Duoに対応したランタイムが入っているかを毎回確かめ、入っていれば撮影まで自動で行います。今はスキップの記録だけが残ります。

## スクリーンショットの作り方

- `ios/UITests/StoreScreenshotTests.swift` がSimulatorを操作して撮影します。時刻は9:41、Simulatorの言語は日本語、通知の許可は出さない設定です。
- 計測中の画面は、開始直後に時計を進める（デバッグ版だけの `-ThirtyJumpAfterStart`）ことで、毎回同じくらいの残り時間で撮れます。
- `scripts/make_store_screenshots.py` が見出しを付けます。書体は日本語の **Zen Kaku Gothic New**（`STORE_FONT=mincho` で **Zen Old Mincho**）。どちらもOFLで、ライセンスとともに `assets/store-fonts/` に同梱しています。`scripts/fetch_fonts.sh` はハッシュを確認して準備するだけなので、CDNの障害で撮影・編集が止まることはありません。中国語用の書体に切り替わって字形が変わることはありません。
- 横向きの画面は、横長のストア画像（例：2622×1206）として出力します。
- ロック画面は画面全体を撮影します。Dynamic Islandは設定アプリの上に出ている通常のコンパクト表示を別の画像にし、ホーム画面のアイコンが入らないようにしています。

## 2026年10月13日の動画と画像の更新

[検証記録](preview-verification-20261013.md)に、使用したCIの録画と画像、動画の再生成手順、確認結果を記録しています。
Dynamic Islandの場面では上端を固定して最大1.5倍まで拡大し、最後の0.5秒はその倍率を維持します。
棒と残り時間を画面内に収めるため、拡大するのはこの場面だけです。

## 最新の素材を掲載情報へ反映する

1. `Build iOS` を最新ブランチで実行します。mainへのiOS・スクリプト変更でも実行されます。
2. すべての撮影と編集が成功すると、画像・動画のサイズと形式を検証した `app-review-media` 成果物ができます。iPhoneは各9枚、iPadは8枚で、休憩カップとマイセットを含みます。`provenance.json` に元コミットと実行URLが入ります。
3. 成果物をダウンロードして内容を確認します。
4. `Fill App Store listing` の `media_run_id` に、その成功した `Build iOS` の実行IDを入力します。`media=true` で、新しく撮影した素材が使われます。空欄の場合は従来どおりリポジトリ内の素材を使います。
5. `dry_run=true` で変更対象を確認し、その後 `dry_run=false` で掲載情報を保存します。`prepare_review` は価格・年齢制限・ビルド選択も更新するため、素材だけ更新する場合は `false` にします。

このワークフローはApp Reviewへの提出を行いません。提出前に、最新のTestFlightビルドと実際に購入できるThirty+（`jp.mugilab.thirty.diagnostic`）が審査対象になっていることを確認します。

### 「審査へ追加済み・未提出」から素材を更新する場合

Appleの `READY_FOR_REVIEW` では画像・動画を編集できません（[App and submission statuses](https://developer.apple.com/help/app-store-connect/reference/app-and-submission-statuses/)）。
`Fill App Store listing` の `draft_action=inspect` で未提出であることを確認し、`reopen` でこのアプリ版だけを下書きから外します。`dry_run=true` なら変更しません。実際に編集状態へ戻す場合は `dry_run=false` にします。

その後 `draft_action=listing` と成功した `media_run_id` で素材を更新します。素材の元コミットと現在のアプリ製品コードが違う場合は、外部への変更前に停止します。
`draft_action=finish` と確認済みの `target_build` を指定すると、画像と動画の処理完了を確認して、そのビルドとアプリが実際に使うThirty+を下書きへ追加します。旧商品の審査項目は、新しい商品の追加が成功してから外します。

この操作は未提出の下書きだけを対象にします。送信済み・審査中の版には対応せず、App Reviewへの送信は行いません。
