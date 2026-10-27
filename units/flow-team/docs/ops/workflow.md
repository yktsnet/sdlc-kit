# 作業フロー（チーム）

着手前の合意を GitHub Issue に残す。作る人が複数いて、誰が何を持っているか・何が裁可済みかを
共有する必要があるなら、こちらを選ぶ。決める人と作る人が同じなら `flow-solo` を選ぶ。

役割の境界は [roles.md](roles.md)、ブランチと PR の単位は [branch-and-pr.md](branch-and-pr.md) にある。

## 入るもの

```text
.claude/skills/issue-draft/               相談者が Issue を設計して起票する。本文の型を同梱
.claude/skills/issue-work/                実行者が Issue に基づき実装し、確認を受けて PR を出す
docs/ops/roles.md                         三役の境界と、分業を緩める3経路
docs/ops/workflow.md                      この文書
```

## 一周の流れ

```text
draft ──（user が保証節を裁可）──> open ──（着手で assignee）──> PR ──（マージで Closes）──> closed
```

1. **起票**（相談者）: `issue-draft` で GitHub Issue を立て、`draft` ラベルを付ける
2. **裁可**（user）: 保証節を読み、削る・足す・直したうえで `draft` ラベルを外す。
   **`draft` の無い open とは、裁可済みという意味である。**
3. **着手**（user）: Issue に自分を assignee として付け、作業ブランチ `issue/{N}-{slug}` を
   worktree に切り、実行者をそこで起動する
4. **実装**（実行者）: `issue-work` に従って実装し、コミットで止まる
5. **確認と直し**（user と実行者）: user が `git diff main...{branch}` を読み、動作を確かめる。
   直す点は同じセッションで伝え、実行者が追加コミットで直す。OK が出るまで繰り返す
6. **公開**（実行者）: user の OK を受けて自分のブランチを push し、本文に `Closes #N` を
   入れた PR を出す
7. **マージ**（user）: PR を読んでマージする。Issue はマージで閉じる

**リモートに載るのは、user が実行者のセッションで確かめて OK を出したものだけになる。**
実行者が push できるのは自分のブランチだけで、main への push とマージは `guards` のフックが
遮断する。

**確認と直しを同じセッションで回す。** 実行者は実装の文脈を保ったまま止まっているので、
指摘をそこで直すのが最も安い。PR の前に別の Issue を起こすと、合意の置き場が2つに割れる。

**Issue はマージで閉じる。** 閉じるのを別の手で行うと、main に実装はあるのに Issue が open の
まま残る期間ができる。マージせずに PR を閉じれば、Issue は open のまま残る。

## 一覧の読み方

置き場が GitHub Issue なので、残作業の一覧は `gh issue list` でそのまま出せる。

| 状態 | 見分け方 |
|---|---|
| 裁可待ち | `draft` ラベルが付いている |
| 着手できる | `draft` が無く、assignee も無い |
| 作業中・PR 待ち | assignee が付いている |
| 済み | closed |

**番号は GitHub が振る。** 起票する人が何人いても番号を取り合わない。マイグレーションや保証台帳の
区切りのように順に並べるものも、連番ではなく Issue 番号で名付けると、並行する Issue が同じ番号を
取らずに済む。

## 一次情報を洗ってから書く

要件は1か所にまとまっていない。仕様書・既存のコード・過去の Issue に散っている。起票する
相談者が作業の主な語でリポ全体を検索し、当たった資料を全文読んでから書く。抜粋で済ませると、
別の箇所にある要件が Issue から落ち、落ちた分は実行者には見えない。

「定めが無い」「存在しない」と書くのは、検索した語と範囲を添えるときだけにする。

## 読み手向けの文書は実装と同じ PR で直す

README や `docs/` のように、振る舞いを説明する文書は実装と同じ PR で直す。後回しにすると、
main の実装と説明が食い違う期間ができる。`issue-work` は差分が Issue の「対象」と一致することを
求めるので、直す文書は起票の段で「対象」に入れておく。

## 起動と片付けの手順

ここは各自の手元の道具で回す。下は素の `git` と `gh` で書いた最小形で、自分のシェル関数や
エイリアスに畳んでよい。

### 起動（3 に相当）

```bash
n=42; slug=fix-loader
gh issue edit "$n" --add-assignee @me
git fetch origin
git worktree add "../$(basename "$PWD").wt/${n}-${slug}" -b "issue/${n}-${slug}" origin/main
cd "../$(basename "$PWD").wt/${n}-${slug}"
# ここで実行者を起動し、issue-work に Issue 番号を渡す
```

worktree を使うのは、main のチェックアウトを汚さずに複数の Issue を並行で走らせるため。

### 片付け（6 と 7 の後）

worktree は PR を出したら消し、ブランチはマージの後に消す。

```bash
# PR を出したら: 実行者のセッションを閉じ、main のチェックアウトで worktree を消す
git worktree remove "../$(basename "$PWD").wt/${n}-${slug}"
```

ブランチは、マージの後に `branch-pr` の `branch-check.sh` がセッション開始時に消す。
PR の後に直しが要ったら、origin のブランチから worktree を作り直す。

マージせずに PR を閉じて捨てると決めたら、ブランチを `git branch -D` で消し、Issue の assignee を
外す。外すと、その Issue は「着手できる」に戻る。

## 派生 Issue

PR を出す前の問題は、5 の中で実行者が直す。新しい Issue にしない。

マージした後に問題が出たら、閉じた Issue を開き直さず、元の番号を本文で指す新しい Issue を
立てる。記録を上書きすると、何をどう裁可したかが後から読めなくなる。

## 取り込んだあとにやること

1. GitHub に `draft` ラベルを作る（`gh label create draft`）
2. `CLAUDE.md` に三役と作業フローへの参照を1行書く。**規約そのものを書き写さない**
3. `CLAUDE.md` に静的チェックの表を書く（実行者が提出前に回す手段）。Issue 本文の「確認」と
   `issue-work` の手順4がここを参照する
4. 起動と片付けの手順を、自分の手元の形に畳む
