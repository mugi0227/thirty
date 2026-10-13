# Appプレビュー動画とDynamic Islandの確認

2026年10月13日、CIの録画からストア用動画を再生成しました。
Dynamic Islandの場面を最大1.5倍まで拡大し、棒と残り時間が両方見えることを確認しています。

## 素材とアプリの検証

使用した素材は[Build iOS 38365468435](https://github.com/mugi0227/thirty/actions/runs/38365468435)の成果物です。
対象のコミットは `2455b6a14c3339d182333b4d573b070659ecbd33` です。

- `app-preview-video`：編集前のSimulator録画。
- `store-iphone-large`：iPhone 17 Pro Maxのロック画面、Dynamic Islandの画像。
- `store-iphone-medium`：iPhone 17の同じ2画面。

このCIではReleaseビルド、Swiftの検査、明暗のUI検査、iPhone 17、iPhone 17 Pro Max、iPad 13インチのストア画像、動画の録画と編集が成功しました。
iPhone Duoは対応ランタイムがなく、撮影をスキップしています。
今回追加した変更は動画の編集と保存済み媒体、文書です。
SwiftのソースはこのCIで検証した内容と同じです。

## 動画の再生成

Pillow、numpy、ffmpeg、ffprobeと、`scripts/fetch_fonts.sh` で取得する日本語フォントが必要です。
CIの `app-preview` ジョブでも同じ編集スクリプトを使います。

```sh
python scripts/make_app_preview.py \
  video/app-preview-iphone.mp4 \
  docs/release/store/app-preview-iphone-6.9.mp4 \
  large/raw/07-dynamic-island.png
```

Dynamic Islandの場面では、画面中央を基準に横方向を切り取り、上端を固定して通常の倍率から1.5倍まで拡大します。
最後の0.5秒は拡大を止めます。
拡大前、途中、最大倍率のフレームを確認し、黒い部分の両端、棒、残り時間「21:55」が収まっていました。
設定画面の左右は拡大に伴って切り取られます。

| 項目 | 結果 |
| --- | --- |
| 長さ | 23.566667秒 |
| 映像 | H.264、886×1920、30fps |
| 音声 | AAC、ステレオ、48kHz |
| 全フレームのデコード | ffmpegで成功 |
| 動画のSHA256 | `7072f1578880f61a7cc94ed79453ad6ae6be3f5a433dd249d3cec7d4027e283b` |
| iPhone中サイズの画像 | RGB、1206×2622 |
| iPhone大サイズの画像 | RGB、1320×2868 |

## 残っている確認

Simulatorでの成功は、実機でのLive Activityや購入の確認とは別です。
このブランチの新しいコンパクト表示はTestFlightの実機で確認する必要があります。
更新した媒体のApp Store Connectへの反映も必要です。
