# team の回し方

作る人が複数いる場合の1周を、[solo](solo.md) と同じ「二重予約を拒否する」で示す。選び方は
[task-flows.md](../task-flows.md)、導入した先で守る規約は `units/flow-team/docs/ops/` にある。

solo との違いは、合意を PR より前の GitHub Issue に置くことと、決める役と作る役を分けることである。
誰が何を持っているか、何が裁可済みかを、作る人どうしで Issue の一覧から読めるようにする。

## 三役

| 役 | すること | しないこと |
|---|---|---|
| **user** | 保証の裁可、着手、レビュー、マージ | — |
| **相談者** | 調べて Issue を設計し、起票する（skill `issue-draft`） | 実装 |
| **実行者** | Issue に基づいて実装し、PR を出す（skill `issue-work`） | main への push、マージ |

相談者と実行者はどちらもエージェントで、別のセッションで動く。相談者は main のチェックアウトで、
実行者は Issue ごとの作業ブランチで動く。決める場と作る場を分けるのは、実装の都合で約束を
書き換えさせないためである。

## 1周の流れ

```mermaid
flowchart TD
    subgraph p1 ["① 起票"]
        R(["👤 頼む"]) --> C{{"相談者<br/>/issue-draft"}}
        C --> I["Issue（draft）"]
    end
    subgraph p2 ["② 裁可と着手"]
        I --> A{"👤 保証節"}
        A -->|直し| I
        A -->|"裁可：draft を外す"| O[open な Issue]
        O ==>|"👤 assignee"| E(["実行者のセッション"])
    end
    subgraph p3 ["③ 実装と確認"]
        E --> W[worktree で作る]
        W --> V{"👤 差分と動き"}
        V -->|直し| W
    end
    subgraph p4 ["④ PR とマージ"]
        V -->|OK| P["PR（Closes #12）"]
        P ==>|"👤 マージ"| M[main・Issue が閉じる]
    end
```

### ① 起票（相談者）

相談者は既存のコード・仕様・過去の Issue を「予約」「重複」などの語で検索し、読んだうえで
Issue を書く。本文の主な欄は次のとおりである。

```text
対象: api/reservations.py, tests/test_reservations.py
対象外: 予約の編集時の重複チェック（別 Issue）
仮定: 時間帯の境界は半開区間とする（11:00 終了と 11:00 開始は重ならない）
根拠: "reservation" "overlap" で api/ と docs/ を検索。docs/spec.md の 2.3 節

### 保証
- 新たに宣言する保証: 同じ部屋で時間帯が重なる予約は 409 を返し、保存しない
- 維持する保証: 接している予約と、別の部屋の予約は受け付ける
```

**保証節** は solo の保証と同じものを、Issue の中に置いた節である。`対象外` と `仮定` を書かせるのは、
相談者が user に聞かずに決めたことを、そこ以外に残す場所が無いからである。起票した Issue には
`draft` ラベルを付けて止まる。

### ② 裁可と着手（user）

user は保証節・`対象外`・`仮定` を読んで直し、`draft` ラベルを外す。**`draft` の無い open な Issue は、
裁可済みという意味になる。** 着手するときは自分を assignee に付け、作業ブランチ
`issue/12-reject-double-booking` を worktree に切って実行者を起動する。

### ③ 実装と確認（実行者と user）

実行者は Issue を読んで実装し、`対象` に無いファイルには手を広げずにコミットで止まる。user は差分を
読んで動きを確かめ、直す点は同じセッションで伝える。指摘のために別の Issue は立てない。合意の置き場が
2つに分かれるからである。

### ④ PR とマージ

user の OK を受けて、実行者は自分のブランチを push し、本文に `Closes #12` を入れた PR を出す。
PR 本文には、保証ごとの証拠を貼る。user がマージすると Issue #12 が閉じる。

保証台帳（`docs/guarantees.md`、`phase-guarantee` を入れたリポだけ）があれば、起票の時点で台帳を
`対象` に入れておき、同じ PR で台帳に保証を足す。

## 一覧から読めること

| 状態 | 見分け方 |
|---|---|
| 裁可待ち | `draft` ラベルが付いている |
| 着手できる | `draft` が無く、assignee も無い |
| 作業中・PR 待ち | assignee が付いている |
| 済み | closed |

依頼主の答えを待つ問いが積み上がってきたら、[client](client.md) を重ねる。
