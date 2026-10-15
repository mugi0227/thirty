# 審査素材の更新（2026年10月16日）

18コアテスト、3サイズの撮影、明暗のウォークスルー、動画編集、完成素材の検証がすべて成功。スクショ26枚と28.03秒の動画をApp Store Connectへ反映し、ビルド20と現在のThirty+を未提出の審査下書きに選択しました。

## 原因と修正

- 日本語フォントのCDN取得が403で失敗し、画像の見出し追加と動画編集が停止。OFLライセンスとともにフォント4点をリポジトリへ同梱し、SHA-256を検証する方式に変更。
- 大画面iPhoneの撮影で、初回起動時のbackground assertion取得と早送りでの終了待ちに失敗。撮影の再試行を最大2回に制限し、終了画面は30分の設定を保ったままデバッグ時計を締切へ進めて撮影。
- 最新録画では、古い「画面全体の変化量」しきい値で再生開始を検出できずStopIteration。再生ボタンの変化と棒が空になった状態を直接検出する方式に変更。生成した28.03秒の動画は、全840フレームのデコードまで確認。
- 撮影・編集の成果物と、掲載情報更新で使うコミット済み素材が別経路だった。全サイズの画像・動画を検証した `app-review-media` をまとめ、掲載情報更新へCI実行IDを指定できるように変更。撮影元と現在のアプリ製品コードの一致も、外部更新前に確認。
- Apple側ではバージョン1.0がREADY_FOR_REVIEW、未提出の下書きにビルド11と旧商品が残っていた。Appleの仕様ではこの状態の画像・動画は編集不可。未提出・対象バージョン一致を確認し、そのバージョンだけ下書きから外して編集可能に戻した。

## 使用したソース

- アプリ製品コードと撮影元：TestFlightビルド20の `7a1852383f497b3ae8739bed90a710500e88aebe`。
- 撮影・編集CI：[38774728798](https://github.com/mugi0227/thirty/actions/runs/38774728798)。以降の変更は掲載情報更新の順序指定・素材・文書のみ。
- ビルド20：署名・アップロード成功。Apple APIでVALID、IN_BETA_TESTINGを確認済み。ビルド19はキャンセル。
- App Reviewへの提出操作は行っていない。

## 検証リンク

- [撮影・編集・検証CI](https://github.com/mugi0227/thirty/actions/runs/38774728798)
- [ビルド20のアップロード](https://github.com/mugi0227/thirty/actions/runs/38774802517)
- [ビルド20・掲載情報の読み取り診断](https://github.com/mugi0227/thirty/actions/runs/38775407436)
- [下書きの読み取り確認](https://github.com/mugi0227/thirty/actions/runs/38772172924)
- [編集状態へ戻す操作のdry run](https://github.com/mugi0227/thirty/actions/runs/38772707783)
- [未提出の下書きを編集状態へ戻す](https://github.com/mugi0227/thirty/actions/runs/38773222416)

## 仕上がった素材と操作

- iPhone 17：9枚、1206×2622（横向きは逆）。
- iPhone 17 Pro Max：9枚、1320×2868（横向きは逆）。
- iPad Pro 13-inch (M5)：8枚、2064×2752（横向きは逆）。
- 動画：28.03秒、886×1920、30fps、H.264、ステレオAAC。全840フレームのデコードを確認。
- 全画像は不透明RGB PNG。CIの完成素材検証が成功し、同じ成果物を掲載用フォルダへ保存。
- 3機種で「普通のタップで休憩選択を開く→7分を選択→25分＋休憩7分＋くり返しを保存→休憩に移る」が初回で成功。
- 時間表示の隙間もタップできるようにし、時間設定のマイセット行を44pt、シートを520pt以上にしてホイールと一緒に表示。休憩の選択画面には1分刻みのホイールと定番候補を配置。

素材の撮影元と対象ビルドは [store/provenance.json](store/provenance.json) に記録。掲載順は基本機能の後に休憩・マイセットを案内するように設定。

## App Store Connectへの反映

- [掲載情報・素材のdry run](https://github.com/mugi0227/thirty/actions/runs/38777985290)：成功。
- [成功したCI成果物から掲載情報・画像・動画を更新](https://github.com/mugi0227/thirty/actions/runs/38778312479)：成功。
- [下書き仕上げのdry run](https://github.com/mugi0227/thirty/actions/runs/38778653307)：画像26枚＋動画1本すべてCOMPLETE。
- [ビルド20と現在のThirty+を下書きへ選択](https://github.com/mugi0227/thirty/actions/runs/38778801579)：成功。READY_FOR_REVIEW、submitted=falseを確認。
- 旧商品の審査項目だけを下書きから外し、商品本体と復元対応は維持。
- 公開設定はAFTER_APPROVAL（審査承認後に自動公開）。App Reviewへの送信はまだ実行していません。
