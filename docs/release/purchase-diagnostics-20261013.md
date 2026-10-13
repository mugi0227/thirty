# TestFlightの商品の取得を調べる

build 6では、契約・銀行・税務情報が有効になり、配信地域を設定した後も、`Product.products(for:)` が空の結果を返している。
iPhoneの再起動後も同じ表示だった。
商品IDは `jp.mugilab.thirty.plus`。
日本の500円・米国の2.99ドルと、両地域の販売対象をApp Store Connect APIで確認した。
原因はまだ確定していない。

診断用ブランチは、商品取得の失敗時に `Storefront.current` の国・ID、本体のBundle IDと版番号、所要時間を表示する。
「詳しい情報 → 接続状況を調べる」では、通常の商品取得を再実行した後、空の結果の場合だけ `SKProductsRequest` でも同じ商品を照会する。
返った商品と `invalidProductIdentifiers` を表示し、12秒で応答がなければ終了する。
通常の購入はStoreKit 2のままで、比較用の照会は支払いも利用権の変更も行わない。
古いAPIはAppleが非推奨としているため、診断用ブランチでの一時的な比較に使用する。

利用者はTestFlightで診断版へ更新し、Thirty+の「詳しい情報」を開く。
「接続状況を調べる」が終わったら「情報をコピー」で結果を共有する。
両方のAPIが商品を返さない場合でも、それだけで登録ミスや契約の反映遅延を断定しない。
StoreKit 2だけが空の場合は、取得APIや応答の処理を比較できる。

ログには商品ID・返った件数・販売地域・ビルド番号のみを追加し、Apple Accountや端末固有IDは記録しない。
取得した実機ログは公開リポジトリに保存しない。
この版は診断用で、審査提出用ビルドへの差し替えは行わない。

参照:

- [Storefront.current](https://developer.apple.com/documentation/storekit/storefront/current)
- [SKProductsResponse](https://developer.apple.com/documentation/storekit/skproductsresponse)
- [TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)
