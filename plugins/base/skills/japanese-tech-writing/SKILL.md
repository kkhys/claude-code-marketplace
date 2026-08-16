---
name: japanese-tech-writing
description: >-
  Norms for Japanese technical prose — book chapters, articles, explainers.
  Covers formatting, paragraph and argument construction, argumentative
  rigour, reader load, voice and narration, restraint on rhetoric, the empty
  LLM register, redundancy, and headings. Writes to the norms, and dispatches
  four specialist auditors over a draft.
when_to_use: >-
  Always consult when writing or revising Japanese technical prose —
  「記事を書いて」「章の草稿」「解説を書いて」「この原稿を推敲して」「リライトして」
  「文章をレビューして」, "write a Japanese technical article", "review this
  draft", or when a Japanese draft is shared for feedback. Also when a
  Japanese draft reads flat, LLM-ish, padded, or logically loose. Not for
  emails, chat messages, commit messages, or short transactional text.
argument-hint: "[draft path, or the topic to write about]"
allowed-tools:
  - Agent
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Japanese Tech Writing

日本語の技術原稿（書籍の章、記事、解説文）のための規範。二つの仕事をする。規範に従って書くことと、書かれた原稿を四人の専門家に監査させることである。

Target: `$ARGUMENTS` — a draft path to revise, or a topic to write about. When
blank, use the draft or topic under discussion.

These norms describe how Japanese prose should read. They are not a style
sheet for humans; they exist because an LLM left to itself produces fluent,
padded, self-narrating Japanese that says less than it appears to.

## 核

The rules below fire on every sentence, in both modes. Everything else is
disclosed through the pointers under [規範の所在](#規範の所在).

### 一文一行

一文ごとに改行する。段落の区切りは空行で示す。コード、差分、ログ、設定ファイルの断片はコードブロックに置く。

### 話題テスト

その文が更新するのは「状況」か、「文書」か。判定の軸はこれだけである。

- 状況を更新する文：対象世界の出来事・データ・発言、あるいは語り手の判断の状態（思い込み、保留、後悔、譲歩、告白）を新しく伝える。残す。
- 文書を更新する文：この章・この節・ここまでの話が「どう見えるか」「次に何を書くか」だけを伝える。削る。

文書について述べる文で残せるのは、次の四つの形だけである。

1. 反論処理：退ける誤読を「」で具体的に引用して退ける（「ここまでの話を『〜せよ』という主張と読まれると、それは違う」）。漠然と「誤解しないでほしい」だけの文は削る。
2. 問いの設置と回収：境界に置く問いの文と、その回収の文。「〜の列挙はしない」「〜の話ではない」は問いの設置ではなく、削る対象である。
3. 読者への依頼・断り：章の冒頭・結びにだけ置く（「どうか〜と割り切って読んでほしい」）。
4. 例の枠の開閉：「〜としよう」「冒頭の例にオチを付けておこう」。

最大の混入経路は、文書更新の文を短い断定調に整形した決め台詞である。拍が効いて見えるだけで、状況の情報はゼロである。リズムのよさは残す理由にならない。

### LLM 口調

論点を増やさず「ちゃんと書いている感」だけを付ける型を使わない。左の型が出たら、右の書き方に替える。

| 使わない | 代わりに |
|---|---|
| 「重要なのは〜である」「本章では〜を探求する」「ここでは〜について見ていく」 | 主張・内容をそのまま書く |
| 「正面から扱う」「正面から回収する」 | 「扱う」「回収する」 |
| 「不可欠」「核心的」「鍵となる」「根本的な」 | その主張の中身を書く |
| 「多角的」「包括的」「総合的」 | 何をどう見たかを書く |
| 「掘り下げる」「深掘りする」「言語化する」「触れる」「言及する」 | 何をどう書いたかを書く |
| 「〜において」「〜という側面から」「〜の観点から」 | 助詞でつなぐか、文を分ける |
| 「さらに」「また」「加えて」の連打 | 論理関係を示す接続表現を選ぶ |
| 「非常に」「極めて」「大いに」 | 程度を数値か事実で示す |
| 「まとめると」「要するに」（直前の言い換えだけのとき）、「〜に他ならない」 | 削る |

領域の術語を議論に使うのはよい。空虚な装飾として使うのが問題である。

### 段落は論証の一歩

一つの段落には一つのトピックだけを置く。段落の最初の文を読めば、その段落が何の話かわかるようにする。段落の先頭では、前の段落との論理関係を接続表現で明示する（「であれば」「実際」「しかし」「この例自体からも」）。

### 未回収の緊張

文章は常に、少なくとも一つの未回収の緊張（答えの出ていない問い、裏の取れていない確信、あとで返すと約束した答え）を開いておく。緊張がすべて閉じた瞬間、読者は読むのをやめられる。

### 断定の境界

推量・可能性・読者の疑念・反実仮想として書かれている文を、機械的に断定へ変えない。「かもしれない」「だろう」を削ってよいのは、根拠なく主張を弱めている場合だけである。本文内の根拠で命題が確定しているときに限り、強く具体的に言い切る。

## 規範の所在

| Reference | 扱う範囲 | 読むとき |
|---|---|---|
| `${CLAUDE_SKILL_DIR}/references/argument.md` | 段落と論証の構成、論証の厳密さ、論証ギャップの検出と修正、読者への誠実さ | 論証を組む・点検するとき（ほぼ常時） |
| `${CLAUDE_SKILL_DIR}/references/rhythm.md` | 認知リズム、文の拍、密度波形、冒頭と節の入り方、緩みと駄文、読み手の負荷、執筆後の点検手順 | 読み物として読ませたいとき、平坦さを診断するとき |
| `${CLAUDE_SKILL_DIR}/references/prose.md` | 整形と記号、見出しの付け方、視点と語り、演出の抑制、冗長の排除 | 文字面を整えるとき（ほぼ常時） |

## 執筆

1. 扱う長さに応じて references を読む。記事や章を書くなら三つとも読む。段落単位の書き直しなら、該当するものだけでよい。
2. 書く。核の六項目は書きながら守る。出力先のパスが指定されていればそこへ書き、指定がなければ応答に本文を返す。
3. `references/rhythm.md` の「執筆後の点検手順」を機械的に回す。話題テストと LLM 口調の点検はここで必ず通す。
4. 章や記事の全体を新規に書き下ろしたときは、[推敲](#推敲)へ進んで監査にかける。段落単位の修正なら不要。

## 推敲

1. 原稿を全文読む。
2. 下の表でエージェントを選び、選んだ理由をユーザーに一言で伝える。
3. 選んだエージェントを一度の応答でまとめて起動し、並列に走らせる。
4. 返ってきた指摘を統合レポートにまとめる。
5. 修正を適用するかユーザーに確認する。適用するときは、指摘の単位ではなく段落の単位で書き直す。

### エージェントの選択

| Agent | `subagent_type` | 専門規範 | 走らせる | 飛ばす |
|---|---|---|---|---|
| argument-auditor | `base:argument-auditor` | `references/argument.md` | 常時。論証の筋はすべての原稿にある | なし |
| prose-auditor | `base:prose-auditor` | `references/prose.md` | 常時。表記と冗長はすべての原稿にある | なし |
| rhythm-designer | `base:rhythm-designer` | `references/rhythm.md` | 読み物として読ませたい章、記事、解説文 | API リファレンス、手順書、変更履歴など、通読を前提としない文書 |
| technical-accuracy-checker | `base:technical-accuracy-checker` | なし（検証手順はエージェント定義が持つ） | コードブロック、API 参照、性能や仕様についての主張があるとき | 技術的主張を含まない随筆や意見文 |

### 起動プロンプト

各エージェントに次を渡す。`{norm_path}` は上の表の専門規範の絶対パス、`{article_path}` は原稿の絶対パスである。technical-accuracy-checker には専門規範の行を落として渡す。

```
あなたの専門に従って次の原稿を監査する。

共通規範: ${CLAUDE_SKILL_DIR}/SKILL.md の「核」節
専門規範: {norm_path}
原稿: {article_path}

規範を先に読み、次に原稿を全文読む。原稿の言語は日本語であり、指摘も日本語で書く。

指摘は次の三段階に分けて出す。

1. critical — 論理が通らない、事実が誤っている、規範の中核に反する
2. warning — 読者の理解や興味を明確に損なう
3. suggestion — 直せばよくなる

各指摘には次を含める。

- 位置：見出し名か、該当段落の冒頭数語の引用
- 症状：規範のどの項目に反しているか
- 修正案：置き換える文そのもの。方針の説明だけで終えない

規範に照らして問題のない箇所は挙げない。称賛も書かない。
```

## 統合レポート

### 重複の統合

複数のエージェントが同じ箇所を別の角度から指摘することがある。一つの項目にまとめ、どの視点から挙がったかを併記し、最も具体的な修正案を残す。

### 深刻度の調整

- 二人以上が挙げた項目は一段上げる（suggestion → warning、warning → critical）
- technical-accuracy-checker の事実誤りは、他の信号によらず常に critical
- argument-auditor の指摘のうち、読者が論証を追えなくなるものは常に critical

### 出力の形

````markdown
## 総評

全体の水準を二、三文で。強みを一文で述べたあと、直すべき箇所の中心を書く。

## critical

公開前に直す項目。各項目に、位置、症状、修正案、指摘したエージェントを書く。

## warning

質を上げるために直す項目。形式は critical と同じ。

## suggestion

任意の改善。形式は critical と同じ。

## 各エージェントの所見

<details> で畳んだ、エージェントごとの全文。
````

該当項目のない段階は、見出しごと省く。空の節を残さない。
