# 注目スコアの設計

最終スコアは「サービス内での相対的な盛り上がり」「鮮度」「ユーザーの興味」の
3要素の積で決まる。サービスごとにエンゲージメントの単位が違う (HNのpt、はてなの
users、GitHubのstars) ため、絶対値ではなくサービス内percentileで正規化する。

## base_score (fetch_trends.py が算出)

```
base_score = round(100 × (0.75 × engagement_pct + 0.25 × freshness))
```

- `engagement_pct`: サービス内バッチでのエンゲージメントのpercentile (0-1)。
  エンゲージメントの定義はソースごと:
  | ソース | engagement |
  |---|---|
  | Hacker News / Lobsters | points + comments÷2 |
  | はてな | ブックマーク数 |
  | Zenn | いいね + ブクマ |
  | Qiita | LGTM + ストック |
  | dev.to | リアクション + コメント |
  | GitHub Trending | 当日のstar増加数 |
- `freshness`: 公開からの経過時間による減衰。
  <6h: 1.0 / <12h: 0.9 / <24h: 0.75 / <48h: 0.55 / それ以降: 0.35 /
  不明 (GitHub等): 0.75

## 興味倍率 (Claude が profile.md から判定)

```
score = min(100, round(base_score × multiplier))
```

| profile.md とのマッチ | interest (星) | multiplier |
|---|---|---|
| high テーマに合致 | 3 | 1.3 |
| mid テーマに合致 | 2 | 1.0 |
| 弱い・該当なし | 1 | 0.6 |
| 除外テーマに合致 | — | 表示しない |

## チューニングの勘所

- 「興味ない記事が上位に来る」→ 倍率ではなくプロフィールのテーマ定義を先に
  疑う。テーマが曖昧だと判定がぶれる。
- 「古い記事ばかり」→ freshness の重みを上げる (fetch_trends.py の 0.75/0.25)。
- 「サービス間で温度感が揃わない」→ 仕様通り。percentile正規化はサービス内の
  相対評価なので、サービス横断の比較はダイジェストのhighlightsが担う。
- `seen_before` は減点しない。既出でも伸び続ける記事は「本物のトレンド」の
  シグナルなので、バッジ表示のみで判断はユーザーに委ねる。
