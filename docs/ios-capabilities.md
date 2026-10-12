# iOSでできることと制約

2026年10月12日に確認したAppleの公開資料と、現在の実装を整理しています。

## アクセスガイドの設定と実行状態

アクセスガイドは、設定アプリで有効にしたあと、使用するアプリ内で物理ボタンを3回押して開始するiOSの機能です。
Thirtyでは、設定アプリへ移動する手順を案内します。
設定のスイッチや、アクセスガイド内のFace ID／Touch ID設定の状態は読み取りません。

アプリ内では `UIAccessibility.isGuidedAccessEnabled` と `guidedAccessStatusDidChangeNotification` を使い、現在のアクセスガイドの実行状態を扱います。
開始と終了の変化を監視し、実行中なら「×3」の案内を消します。
オンボーディングの既読は、説明を閉じたというアプリ内の記録です。

[Appleのアクセスガイド手順](https://support.apple.com/ja-jp/111795)、[状態取得](https://developer.apple.com/documentation/uikit/uiaccessibility/isguidedaccessenabled)、[セッション開始と終了の通知](https://developer.apple.com/documentation/uikit/uiaccessibility/guidedaccessstatusdidchangenotification)を参照しています。

## アプリからの自動開始と設定へのリンク

一般の個人用端末で、アプリからアクセスガイドの設定スイッチをオンにする処理はありません。
`UIAccessibility.requestGuidedAccessSession` によるSingle App Modeの開始は、MDMで管理され、そのモードを許可された監視対象端末に限られます。
このアプリはその管理構成を前提にしていません。[AppleのAPI説明](https://developer.apple.com/documentation/uikit/uiaccessibility/requestguidedaccesssession(enabled:completionhandler:))

公開APIの `AccessibilitySettings.openSettings(for:)` で開ける項目にも、アクセスガイドの設定先は確認できませんでした。
未公開の設定URLには依存せず、図と文字で手動の移動先を示します。
アプリの通知設定を開く処理には、公開の `UIApplication.openNotificationSettingsURLString` を使用しています。[アクセシビリティ設定の公開項目](https://developer.apple.com/documentation/accessibility/accessibilitysettings/feature)、[通知設定へのリンク](https://developer.apple.com/documentation/uikit/uiapplication/opennotificationsettingsurlstring)

## 物理ボタンと解除

| 端末 | 開始に使うボタン |
| --- | --- |
| ホームボタンのないiPhone | サイドボタン |
| ホームボタンのないiPad | トップボタン |
| ホームボタンのある機種 | ホームボタン |

現在のAppleの手順では、該当ボタンを3回押して開始します。
終了は、再びボタンを3回押して認証し、アクセスガイドの「終了」を選びます。
iOS／iPadOS 18以前の解除では2回押す方式が案内されているため、OSのバージョンに応じて説明を変えます。[Appleの操作手順](https://support.apple.com/ja-jp/111795)

Thirtyのタイマーとアクセスガイドの時間制限は別の機能です。
タイマーが終了しても、アクセスガイドを自動で解除しません。
物理ボタンの種類は端末種別とセーフエリアから推定し、画面上の案内は位置の目安として表示します。
全機種、全画面方向での位置の検証は未実施です。

## 画面の明るさ

アプリから画面輝度を変更するには `UIScreen.brightness` を使用できます。
Appleの説明では変更がアプリを閉じたあとにも残る場合があるため、Thirtyは変更前の値を保存し、前景を離れる際に復元する実装にしています。[Appleの輝度API](https://developer.apple.com/documentation/uikit/uiscreen/brightness)

月アイコンは、計測中と一時停止中に画面を暗くする設定です。
iOSの低電力モードを切り替える処理はありません。
プロセスの強制終了など、通常のライフサイクルを経ない終了時の輝度の挙動は未確認です。

## 特定のアプリだけを制限する拡張

特定のSNSだけを一定時間制限する場合は、FamilyControls、ManagedSettings、DeviceActivityを使う別の実装が必要です。
本人の個人認可とFamily Controls entitlementが必要で、配布時にはAppleの承認も必要になります。
個人認可は本人が設定から取り消せるため、本人が解除できないロックとしては扱えません。
現在のThirtyには、その制限機能を含めていません。[Screen Timeの個人認可](https://developer.apple.com/videos/play/wwdc2022/110336/)、[配布権限の申請](https://developer.apple.com/documentation/FamilyControls/requesting-the-family-controls-entitlement)

## 画面の向きの切り替え

iOS 16以降の `UIWindowScene.requestGeometryUpdate` で、アプリから横向きや縦向きを要求できます。
要求する向きは、アプリデリゲートの `supportedInterfaceOrientationsFor` が許可している必要があるため、Thirtyは一時的にその戻り値を固定します。
画面の縦向きロックがオンでも、アプリが要求した向きには回転する想定です。実機での確認はしていません。[AppleのAPI説明](https://developer.apple.com/documentation/uikit/uiwindowscene/requestgeometryupdate(_:errorhandler:))
