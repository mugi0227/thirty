# 掲載素材の価格表現を修正（2026年10月21日）

App Reviewガイドライン2.3.7に関する懸念を減らすため、掲載用の画像・動画から価格表現を外します。

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

## Apple側の状態

[GETのみの確認](https://github.com/mugi0227/thirty/actions/runs/39596776199)で、2026年10月21日12:05 UTC時点のバージョン1.0・ビルド22は `WAITING_FOR_REVIEW` でした。ビルドはVALIDで、現在のThirty+も審査待ちです。公開設定は `AFTER_APPROVAL` です。

この素材修正では、審査の取り下げや再提出を行っていません。[Appleの説明](https://developer.apple.com/help/app-review/after-submitting-for-review/review-status)では、審査待ちの画像・動画は編集できません。Apple側へ反映する場合は、提出を取り下げて差し替え、再提出する必要があります。

反映時は、上記CIの `app-review-media` を使います。`Fill App Store listing` の `media_run_id=39596760433`、`media=true`、`prepare_review=false` で素材を指定できます。既存の未提出下書き用 `reopen` は、提出済みの審査には対応しません。
