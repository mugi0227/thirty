# App Review と App内課金の情報

## App Reviewへのメモ（App Store Connectの「メモ」欄に貼る）

Thirty is a single-screen focus timer. No account or login is needed.

- Start: tap the play button. The whole screen becomes a bar timer; controls hide after 4 seconds and come back with a tap.
- Guided Access: the app only explains how to turn on the system's Guided Access feature (Settings > Accessibility > Guided Access) and shows which button to triple-click. It does not start or detect the setting by itself, and the timer works without it.
- In-app purchase "Thirty+" (non-consumable, jp.mugilab.thirty.diagnostic) unlocks extra skins, end sounds, repeat, optional breaks, saved timer sets, display options, alternate icons and the Live Activity. Open it from the palette icon or Settings (gear icon) > "Thirty+ でできること". "購入を復元" restores purchases.
- The Live Activity (Lock Screen, StandBy, Dynamic Island) appears while a timer runs after purchasing Thirty+.
- Repeat and breaks: the repeat button is to the left of Play, and the cup button to the right. Tap the cup to choose common break lengths, or hold it to choose 1–60 minutes. With repeat off, focus → optional break → finish. With repeat on, the same sequence repeats. During a break, the bars become a pixel coffee cup.
- My Sets: tap the time while stopped, then save the current time, break length and repeat setting. Up to eight sets can be saved; hold a saved set to delete it.
- Local notifications announce the end of focus and break segments. No server, account or login is required.

日本語の補足：タイマー本体は無料で、広告はありません。アクセスガイドはiOS標準機能の案内のみです。

## App内課金（Thirty+）

| 項目 | 内容 |
| --- | --- |
| 種類 | 非消耗型 |
| 参照名 | Thirty+ |
| 製品ID | jp.mugilab.thirty.diagnostic |
| 価格 | ¥500 |
| 表示名 | Thirty+ |
| 説明（45文字まで） | スキン、ロック画面表示、終了音などが使えます。買い切りです。 |
| 審査用スクリーンショット | `docs/release/store/iap-review-thirty-plus.png`（1206×2622。縮小版は寸法エラーになる） |
| 画像（1024×1024） | `docs/release/store/iap-thirty-plus-1024.png`（`scripts/make_iap_image.py` で作成） |
| ファミリー共有 | オフ（現在の登録内容） |

## App内課金の「審査メモ」欄（Thirty+）

```
Thirty+ is a one-time, non-consumable purchase. The timer itself is free and has no ads.

Where to find it: tap the palette icon (top right) or the gear icon > "Thirty+ でできること". Locked items show a lock icon; tapping one opens the purchase sheet. "購入を復元" restores the purchase.

What it unlocks immediately:
- 5 extra skins (Paper, Mint, Amber, Night Blue, Ruby). Locked skins can be previewed before buying.
- End sounds, 60 slats, minutes-only display, alternate app icons (Settings). Repeat and breaks are beside Play; saved sets are in the time picker.
- Live Activity on the Lock Screen / Dynamic Island while a timer runs.

No account or server is involved.
```
