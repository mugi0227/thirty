# 掲載素材の価格表現を修正（2026年10月21日）

App Reviewガイドライン2.3.7に関する懸念を減らすため、掲載用の画像・動画から価格表現を外しました。2026年10月21日16:24 UTCに修正素材での再提出が受理され、ビルド22とThirty+が審査待ちになっています。

## 変更

- プレビュー動画の末尾を「無料・広告なし」から「広告なし・登録不要」に変更。
- iPadのスキン一覧を、Thirty+購入済みの通常画面で撮影。購入価格・購入ボタン・復元ボタンが写らない画面を使う。
- スキン一覧の補足を「6種類のスキンを切り替え（Thirty+）」へ変更。有料機能を示す「Thirty+」は維持。
- 撮影手順も変更し、今後の自動生成で価格表示が戻るのを防ぐ。

アプリ本体の製品コードは変更していません。購入処理や価格設定の変更もありません。

## ソースと実行

- 変更前のmain：`a37b77caf6fac8475914ba3b7c64a328c8d03baf`。
- 撮影・生成コード：`7eccddfcb284536b69d163385f319cde59914d52`。
- [撮影・生成・検証CI](https://github.com/mugi0227/thirty/actions/runs/39596760433)。
- [修正PR #24](https://github.com/mugi0227/thirty/pull/24)。

## 検証

- 上記CIは成功。18件の単体テスト、Releaseビルド、明暗のウォークスルー、3機種の撮影、動画生成、素材一式の検証を実行。
- iPhoneは各9枚、iPadは8枚。全26枚が不透明RGB PNGで、掲載サイズを確認し、目視でも確認。
- 動画は24.15秒、886×1920、30fps、H.264とステレオAAC。映像・音声の全編デコードと、末尾の「広告なし・登録不要」を確認。
- iPadのスキン画像に価格・購入ボタンがないことと、購入済み画面の案内を確認。
- 標準サイズiPhoneの休憩設定テストは、PickerWheelの値の取得に一度失敗し、既存の自動再試行で成功。iPadの変更対象の撮影は初回で成功。
- `app-review-media` 成果物（ID `12345642700`）をリポジトリに取り込み、全画像が目視確認した個別成果物と一致することを確認。ZIPのSHA-256は `ed1eb3527a6811ca15d511da98e58fbeb2a0ac61dfb83d7e17f416bfabfbfad9`。
- [provenance.json](store/provenance.json)に撮影・生成コミットとCIの実行URLを保存。現在の製品コードと撮影元が一致。

## Apple側の初回確認

[GETのみの確認](https://github.com/mugi0227/thirty/actions/runs/39596776199)で、2026年10月21日12:05 UTC時点のバージョン1.0・ビルド22は `WAITING_FOR_REVIEW` でした。ビルドはVALIDで、現在のThirty+も審査待ちです。公開設定は `AFTER_APPROVAL` です。

この最初の素材準備では、審査の取り下げや再提出を行いませんでした。[Appleの説明](https://developer.apple.com/help/app-review/after-submitting-for-review/review-status)では、審査待ちの画像・動画は編集できません。ユーザーが反映を承認した後、以下の操作を行いました。

## 承認後の反映

- PR #24をmainへマージ（`84fbee3f40c11b1f1e5c1e3c6a7891f2e5c27790`）。取り込んだ素材は上記CI成果物と一致します。
- [反映前のGET確認](https://github.com/mugi0227/thirty/actions/runs/39628581404)で、ビルド22と現在のThirty+が引き続き審査待ちであることを確認。
- [提出の取り下げ](https://github.com/mugi0227/thirty/actions/runs/39630076043)に成功。旧提出IDは `f1a06610-bb5a-48b4-aabc-6864ad123317`。版の状態が `DEVELOPER_REJECTED`、旧提出が最終的に `COMPLETE` となりました。
- [素材だけの差し替え](https://github.com/mugi0227/thirty/actions/runs/39630736341)に成功。日本語の画像26枚・動画1本を更新。アプリ情報・説明文・審査メモ・価格・製品・選択ビルド・公開方式の書き込みはありません。
- [詳細状態のGET確認](https://github.com/mugi0227/thirty/actions/runs/39633402453)では、動画を含む26点が処理済み・チェックサム一致。iPhone中サイズの横向き画像 `02-landscape.png` 1枚だけが `UPLOAD_COMPLETE` のままでした。
- [1枚だけの再送](https://github.com/mugi0227/thirty/actions/runs/39634018854)に成功。新しい画像が処理済み・チェックサム一致になってから元の画像を外し、表示順を維持。画像26枚・動画1本すべてが `COMPLETE`、27点すべてのチェックサムが一致しました。
- [下書きの復元](https://github.com/mugi0227/thirty/actions/runs/39634173687)に成功。新提出IDは `afaeddf2-73e6-4f12-995b-e1b1cd6a6e1d`。バージョン1.0・ビルド22と、同じThirty+審査版 `9582d94e-37e0-4c6b-8f21-347d7b877804` だけを含む `READY_FOR_REVIEW` の下書きを作成しました。
- [提出前のdry run](https://github.com/mugi0227/thirty/actions/runs/39634327586)に成功。選択されたビルド・Thirty+・掲載説明文・審査連絡先・審査メモ・暗号化申告・全27点の処理完了を確認しました。
- [実際の再提出](https://github.com/mugi0227/thirty/actions/runs/39634461373)は2026年10月21日16:24:36.330 UTCに受理されました。新提出とバージョン1.0の状態はいずれも `WAITING_FOR_REVIEW`。選択ビルドは22、Thirty+は `jp.mugilab.thirty.diagnostic`、公開方式は引き続き `AFTER_APPROVAL` です。
- [提出後のGET検証](https://github.com/mugi0227/thirty/actions/runs/39634564419)も成功。新提出とアプリ版がともに `WAITING_FOR_REVIEW`、ビルド22と同じThirty+の2項目だけが対象、画像26枚・動画1本すべてが `COMPLETE`、27点すべてのチェックサム一致を確認しました。

確認中に、動画用の `assetDeliveryState` が非推奨であることも確認しました。[AppleのAPI 3.7の説明](https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-3-7-release-notes)に従い `videoDeliveryState` を優先します。新しい状態が失敗・処理中の場合に、古い `COMPLETE` で通過させないテストを追加しています。

初回の処理待ち確認は8分で停止し、提出は行いませんでした。詳細状態を取得できるようにし、残った1枚だけを、新しいファイルの処理・チェックサム確認後に置き換える操作を追加しました。

[操作補助のPR #25](https://github.com/mugi0227/thirty/pull/25)には、取り下げ・素材だけの差し替え・下書き復元・詳細状態のGET確認・1枚だけの再送を追加しました。Pythonテスト28件、構文確認、差分チェックが成功。別ビルドや旧課金商品の混入、応答喪失時の重複操作、処理失敗時に元画像を消さないことを検証しています。
