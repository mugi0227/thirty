# 公開サイト（thirty-support）

App Storeのサポートページとプライバシーポリシーです。
本体リポジトリを非公開にしてもリンクが切れないように、このフォルダの中身を公開リポジトリ `mugi0227/thirty-support` に置き、GitHub Pagesで配信します。

| ページ | URL |
| --- | --- |
| トップ（マーケティングURL） | https://mugi0227.github.io/thirty-support/ |
| サポート | https://mugi0227.github.io/thirty-support/support/ |
| プライバシーポリシー | https://mugi0227.github.io/thirty-support/privacy-policy/ |

このフォルダが原本です。内容を変えたら、`thirty-support` 側にも同じ変更をコピーしてください。
`README.md`（このファイル）はコピー不要です（`_config.yml` で除外しています）。

## 最初の公開手順

1. GitHubで **Public** のリポジトリ `mugi0227/thirty-support` を作る（Issuesは有効のまま。問い合わせ先になります）。
2. このフォルダの `_config.yml`、`index.md`、`privacy-policy.md`、`support.md` をリポジトリの直下に置いてpush。
3. 「Settings」→「Pages」→「Build and deployment」で Source を **Deploy from a branch**、Branch を `main` / `/ (root)` にして保存。
4. 数分後、上の3つのURLが開けることを確認。
5. App Store Connectの「Appのプライバシー」のプライバシーポリシーURLと、バージョンのサポートURL・マーケティングURLを差し替える（「Fill App Store listing」ワークフローでも入ります）。
6. 新しいURLを含むビルドを配信してから、本体リポジトリを非公開にする。
