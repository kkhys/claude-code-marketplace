# セットアップ

認証不要の7ソース (Hacker News, Lobsters, GitHub Trending, dev.to,
はてなブックマーク, Zenn, Qiita) のみで動作する。追加設定なしで使い始められる。

## Qiita トークン (任意)

未認証だと IP あたり 60リクエスト/時。1回の実行で最大26リクエスト使うため、
同一時間内に何度も実行するなら
https://qiita.com/settings/applications で read_qiita スコープのトークンを
発行し `QIITA_ACCESS_TOKEN` に設定すると 1000/時 になる。

## Reddit について

2026年時点、Reddit Data API はアプリ作成が Responsible Builder Policy への
同意・承認制でゲートされており、個人利用でも「Data Access Request」の申請が
必要になったため導入を見送った。将来追加する場合は `fetch_trends.py` に
OAuth client_credentials (script アプリ) を使う fetcher を実装し、`SERVICES`
に登録する。

## X (Twitter) について

公式 X API は読み取りが実質有料 (Basic $200/月〜) のため組み込んでいない。
代替は xAI (Grok) API の Live Search で、`XAI_API_KEY` があれば X 上の話題を
検索できる (従量課金)。追加する場合は `fetch_trends.py` に xAI の
chat completions + search_parameters を使う fetcher を足し、`SERVICES` に
登録するだけでよい構造にしてある。

## 状態ファイル

`~/.claude/trend-digest/`:

| ファイル | 役割 |
|---|---|
| `profile.md` | 興味プロフィール。フィードバックで育つ |
| `config.json` | ソース設定 (hatena_categories, 表示件数など) と `site_repo` (公開先リポジトリのパス) |
| `seen.json` | 既出URL履歴 (「既出」バッジ用、自動管理) |
| `runs/<date>/` | raw.json (取得結果) |

## 公開

完成した digest は me リポジトリの `apps/trends/src/content/runs/<date>.json`
にコミットされ、`pnpm deploy:trends` で trends.kkhys.me にデプロイされる。
JSON のスキーマ検証は同リポジトリの `apps/trends/src/content.config.ts`
(zod) がビルド時に行う。ローカルプレビューは me リポジトリで
`pnpm dev:trends`。
