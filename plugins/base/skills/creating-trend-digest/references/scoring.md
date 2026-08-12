# 注目スコアの設計

スコアは「サービス内での相対的な盛り上がり」と「鮮度」で決まり、並び順は
この素の話題性のみを反映する。ユーザーの興味は interest (星) の注釈として
表示に乗るだけで、順位には影響させない — 一覧は世間のトレンドのフラットな
写像を保ち、パーソナライズは注釈と highlights が担う。サービスごとに
エンゲージメントの単位が違う (HNのpt、はてなの users、GitHubのstars) ため、
絶対値ではなくサービス内percentileで正規化する。

## base_score (fetch_trends.py が算出)

```
base_score = round(100 × (0.75 × engagement_pct + 0.25 × freshness))
```

- `engagement_pct`: サービス内バッチでのエンゲージメントのpercentile (0-1)。
  同値は順位範囲の平均percentileを共有する (同値の並び順で順位が反転しない)。
  エンゲージメントの定義はソースごと:
  | ソース | engagement |
  |---|---|
  | Hacker News / Lobsters | points + comments÷2 |
  | Reddit | top一覧での順位 (RSSにスコアが載らないためReddit自身のランキングを保存) |
  | はてな | ブックマーク数 |
  | Zenn | いいね + ブクマ |
  | Qiita | LGTM + ストック |
  | dev.to | リアクション + コメント |
  | GitHub Trending | 当日のstar増加数 |
  | Techmeme | トップページの掲載順位 (編集部ランキング。カウント指標なし) |
  | Hugging Face Daily Papers | upvotes + comments÷2 |
- `freshness`: 公開からの経過時間による減衰。
  <6h: 1.0 / <12h: 0.9 / <24h: 0.75 / <48h: 0.55 / それ以降: 0.35 /
  不明 (GitHub等): 0.75

## 興味の注釈 (Claude が profile.md から判定)

```
score = base_score  (興味による増減はしない)
```

| profile.md とのマッチ | interest (星) |
|---|---|
| high テーマに合致 | 3 |
| mid テーマに合致 | 2 |
| 弱い・該当なし | 1 |
| 除外テーマに合致 | 表示しない |

かつては interest 倍率 (×1.3/1.0/0.6) を score に掛けていたが、高興味テーマ
が上位を独占して一覧が偏るため廃止した。順位はフラットに保ち、興味は星の
注釈・summary の観点・highlights の選定で表現する。

## チューニングの勘所

- 「興味ない記事が多すぎる」→ 星の注釈と highlights で拾う設計が前提。それ
  でも足りなければプロフィールの除外テーマを広げる。
- 「古い記事ばかり」→ freshness の重みを上げる (fetch_trends.py の 0.75/0.25)。
- 「サービス間で温度感が揃わない」→ 仕様通り。percentile正規化はサービス内の
  相対評価なので、サービス横断の比較はダイジェストのhighlightsが担う。
- `seen_before` は減点しない。既出でも伸び続ける記事は「本物のトレンド」の
  シグナルなので、バッジ表示のみで判断はユーザーに委ねる。
