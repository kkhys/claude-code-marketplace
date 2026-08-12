# セットアップ

認証不要の10ソース (Hacker News, Lobsters, Reddit, GitHub Trending, dev.to,
Techmeme, Hugging Face Daily Papers, はてなブックマーク, Zenn, Qiita) のみで
動作する。追加設定なしで使い始められる。

## Qiita トークン (任意)

未認証だと IP あたり 60リクエスト/時。1回の実行で最大26リクエスト使うため、
同一時間内に何度も実行するなら
https://qiita.com/settings/applications で read_qiita スコープのトークンを
発行し `QIITA_ACCESS_TOKEN` に設定すると 1000/時 になる。

## Reddit について

Reddit Data API (JSON) はアプリ作成が Responsible Builder Policy への同意・
承認制でゲートされているため使わず、認証不要で公式提供されている RSS
(`/r/<sub>/top/.rss?t=day` と記事単位の `.rss`) から取得している。対象
subreddit は config.json の `subreddits` (デフォルト `["programming"]`) で
変更できる。RSS にはスコアが載らないため、順位は Reddit 自身の top
ランキング順をそのまま使う。コメント取得はバースト時に 429 が返ることが
あり、リトライしても失敗した記事は discussion_summary なしで載る
(ベストエフォート)。

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
| `config.json` | ソース設定 (hatena_categories, subreddits, 表示件数, comments_top_n など) と `site_repo` (公開先リポジトリのパス) |
| `seen.json` | 既出URL履歴 (「既出」バッジ用、自動管理) |
| `runs/<date>/` | raw.json (取得結果) |

## 公開

完成した digest は me リポジトリの `apps/trends/src/content/runs/<date>.json`
にコミットされ、`pnpm deploy:trends` で trends.kkhys.me にデプロイされる。
JSON のスキーマ検証は同リポジトリの `apps/trends/src/content.config.ts`
(zod) がビルド時に行う。ローカルプレビューは me リポジトリで
`pnpm dev:trends`。
