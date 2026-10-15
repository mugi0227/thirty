# Sandboxの商品カタログ比較（2026年10月15日）

Thirty+がTestFlightで取得できない件の続き。原因はまだ確定していない。
利用者から、Appleサポートには問い合わせ済みであること、読み取り診断の後に別商品IDで比較したい旨を引き継いだ。

## 現在の登録状態

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

## 実機での次の確認

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
元のThirty+への書き込み、商品削除、レビュー提出、アプリのバージョンやビルドの差し替えは実装していない。
既存の `repair_app_availability` は今回すべて `false` で実行した。

Pythonの構文・差分確認、Apple公開OpenAPI 4.5.1による作成リクエストの検証、参照商品への書き込みを拒否するガードを確認した。
実機での商品の取得と購入は未確認。

参照:

- [TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox): Sandboxのテストに審査提出は不要。商品情報の変更反映は最大1時間と説明されている。
- [IAP情報の編集](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/view-and-edit-in-app-purchase-information/): 審査用画像・メモの用途と商品情報の反映時間。
- [IAP情報](https://developer.apple.com/help/app-store-connect/reference/in-app-purchase-information/): Product IDは保存後に変更できず、削除後も再利用できない。
