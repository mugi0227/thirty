# Sandboxの商品カタログ比較（2026年10月15日）

Thirty+がTestFlightで取得できない件の続き。原因はまだ確定していない。
利用者から、Appleサポートには問い合わせ済みであること、読み取り診断の後に別商品IDで比較したい旨を引き継いだ。

## 09:51 UTC時点の登録状態

[09:51 UTCのGETのみの診断](https://github.com/mugi0227/thirty/actions/runs/38715968857)は成功し、APIエラーは0件だった。

| 項目 | 確認結果 |
| --- | --- |
| アプリ | `6822135223` / `jp.mugilab.thirty` |
| Thirty+ | `6822135374` / `jp.mugilab.thirty.plus` |
| 種類・状態 | `NON_CONSUMABLE` / `READY_TO_SUBMIT` |
| 商品バージョン1 | `READY_FOR_REVIEW` |
| ローカライズ | 日本語 `ja` のみ。表示名・説明文あり |
| 価格 | 日本500円・米国2.99ドル。将来の開始日・終了日なし |
| 販売地域 | アプリとIAPで同じ175か国 |
| 識別子 | ソースと完全一致、ASCIIのみ、直接のIAP照会でも一致 |
| 署名設定 | 明示的なBundle ID、`IN_APP_PURCHASE`有効、App Storeプロファイルは`ACTIVE` |
| Sandboxテスター | 日本のテスター1件。購入中断設定は無効。アカウントの識別情報は記録しない |

[10月13日の診断](https://github.com/mugi0227/thirty/actions/runs/38406929561)との差分は、確認時刻と日本のSandboxテスター1件の追加だけだった。
契約・銀行・税務情報の有効性と適用開始日は、今回のAPI診断では独立に確認していない。
APIの登録情報が正常でも、Sandboxでの配信や購入が可能であることまでは保証しない。
日本語のみであることを商品0件の原因とは断定しない。

## 別の商品IDによる比較

比較用商品は `jp.mugilab.thirty.diagnostic`（Apple ID `6823121323`）。
非消耗型、日本語の商品情報、日本500円・米国2.99ドル、同じ175か国への配信を設定した。
日米の価格は診断用商品に明示的に設定し、他地域は日本を基準に自動計算する。
Thirty+の米国価格は自動計算、診断用商品の米国価格は明示設定なので、この属性は異なる。
既存アプリの審査用画像を診断用に複製した。診断用商品の審査メモは、アプリから利用せず審査提出もしない商品だと明記している。
アプリのコードは引き続きThirty+だけを取得するため、比較はiPhoneのSandbox設定から直接行う。
この商品IDは削除後も再利用できない。

[作成前のGETのみの計画確認](https://github.com/mugi0227/thirty/actions/runs/38716618693)では、同じ診断用IDが未作成であることと、価格・175か国を確認した。
[価格・配信設定の読み戻し](https://github.com/mugi0227/thirty/actions/runs/38716890305)では、日米の価格と175か国が一致し、既存Thirty+の属性・ローカライズ・配信設定・価格が作成前後で一致した。
新規商品にも価格が空のスケジュールが存在するため、スケジュールの存在だけで設定済みとは判定しない。

[審査用画像を含む最終設定と読み戻し](https://github.com/mugi0227/thirty/actions/runs/38717249972)も成功した。
10:02 UTC（日本時間19:02）に、診断用商品が `READY_TO_SUBMIT` となり、価格・175か国・既存Thirty+の設定一致を再確認した。
実機比較の目安は11:02 UTC（日本時間20:02）以降。

## 実機からの比較結果

利用者がiPhoneのSandbox「アプリ内購入をテストする」から、同じBundle IDを指定して順に照会したスクリーンショットを共有した。

| 商品ID | 確認できた表示 |
| --- | --- |
| `jp.mugilab.thirty.diagnostic` | 「Thirty 診断用」、¥500、1回払い、テスト用で請求なしと記された購入確認画面 |
| `jp.mugilab.thirty.plus` | 「このアイテムはご利用いただけません。」「[Environment: Sandbox]」 |

診断用商品の**認識・購入確認画面の表示**は成功した。購入の確定・決済成功やアプリでの利用権付与は確認していない。
元のThirty+のエラー画面には端末時刻19:08が写っている。
この比較はアプリ本体のStoreKit実装を経由しないため、元の商品固有の登録・配信状態を重点的に調べる根拠となる。
Apple側の具体的な原因や障害を確定するものではない。両商品の作成時期と米国価格の自動／明示設定には差がある。
スクリーンショットに含まれるアカウント情報は転記せず、画像原本を公開リポジトリに保存しない。

[元の商品の英語情報追加](https://github.com/mugi0227/thirty/actions/runs/38718548373)は、Appleから409で拒否された。
応答には `STATE_ERROR.INVALID_REQUEST_ENTITY_STATE_INVALID` と `Cannot create new localization, change pending review.` が含まれ、追加は完了していない。
この直前のGETでは、両商品の親リソースは `READY_TO_SUBMIT` だが、商品バージョン1は元のThirty+が `READY_FOR_REVIEW`、診断用が `PREPARE_FOR_SUBMISSION` だった。
Appleの現行仕様では、審査準備へ追加したバージョンのローカライズは編集できず、編集には下書きバージョンを使う。
この状態差がSandboxの取得結果の原因だとまでは断定しない。

その後、利用者から「診断用を本番用に使ってよい」と明示された。
編集用の新バージョン作成や元の商品の審査準備の変更は実行せず、取得できる `jp.mugilab.thirty.diagnostic` を正式なThirty+として整える方針へ進む。

## 実機比較の手順

商品設定の最後の更新から1時間程度置いて、同じ端末・同じSandboxアカウント・同じ通信環境で比較する。
Sandboxの「アプリ内購入をテストする」で、Bundle IDに `jp.mugilab.thirty` を指定し、次の2つを順に試す。

1. `jp.mugilab.thirty.plus`
2. `jp.mugilab.thirty.diagnostic`

商品が認識されたか、表示されたエラー、確認時刻、販売地域が分かる範囲で記録する。
両方失敗した場合はWi-Fiとモバイル通信でも比較する。端末ログやアカウント情報を公開リポジトリに保存しない。

| 実機結果 | 次に調べる対象 |
| --- | --- |
| 診断用だけ成功 | Thirty+の商品固有の登録・配信状態を重点的に調べる |
| 両方失敗 | 新商品の反映時間も考慮し、アプリ・アカウント・端末・Sandbox配信を引き続き調べる |
| 両方成功 | Thirty+も復旧。時間経過・再試行・新商品作成のどれが効いたかは断定しない |
| Thirty+だけ成功 | 新商品の反映・登録状態を調べる |

送付済みのAppleサポートへの問い合わせと、上記の事実を照合する。問い合わせの追加送信はしていない。

## 実行手順と確認

`codex/iap-catalog-comparison` ブランチの `asc-metadata.yml` には `diagnostic_product` 入力がある。
`none` が既定値、`plan` はGETのみ、`create` は固定の診断用IDだけを作成・設定する。
診断用商品を作成するスクリプトには、元のThirty+への書き込み、商品削除、レビュー提出、アプリのバージョンやビルドの差し替えを実装していない。
既存の `repair_app_availability` は今回すべて `false` で実行した。

`plus_english_localization` は `none` が既定値、`plan` はGETのみ、`add` は固定の商品・英文によるローカライズ追加だけを許可する。
`scripts/add_plus_english.py` は価格、配信設定、既存の日本語などが保存前後で一致することを確認する。
商品ID変更、価格更新、既存ローカライズの上書き、審査提出は行わない。

Pythonの構文・差分確認、Apple公開OpenAPI 4.5.1による作成リクエストの検証、許可した商品・操作以外への書き込みを拒否するガードを確認した。
実機では診断用の購入確認画面を確認済み。アプリ内の商品取得・購入完了は引き続き未確認。

参照:

- [TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox): Sandboxのテストに審査提出は不要。商品情報の変更反映は最大1時間と説明されている。
- [IAP情報の編集](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/view-and-edit-in-app-purchase-information/): 審査用画像・メモの用途と商品情報の反映時間。
- [IAP情報](https://developer.apple.com/help/app-store-connect/reference/in-app-purchase-information/): Product IDは保存後に変更できず、削除後も再利用できない。
- [IAP状態](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-statuses/): `READY_FOR_REVIEW` は審査準備へ追加済み、提出前の状態。
- [商品バージョン](https://developer.apple.com/documentation/appstoreconnectapi/working-with-in-app-purchase-versions): バージョン単位の編集・審査モデル。
