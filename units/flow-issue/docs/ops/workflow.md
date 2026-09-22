# 作業フロー（Issue 版）

着手前の合意を `issues/` の Issue ファイルに残す。作業が複数の PR にまたがる、着手が数日後に
なる、担当者が複数いる、といった場合はこちら。1本の PR に収まるなら `flow-single` を選ぶ。

役割の境界は [roles.md](roles.md) にある。

## 入るもの

```text
issues/                                   Issue ファイルの置き場。ここが唯一の真実
.claude/skills/new-issue/                 相談者が Issue を設計して書き出す
.claude/skills/pr-workflow/               実行者が Issue に基づき実装しコミットする
docs/ops/roles.md                         三役の境界と、分業を緩める3経路
docs/ops/workflow.md                      この文書
```

## 一周の流れ

```text
draft ──（user が保証節を裁可）──> open ──（実装・レビュー・マージ）──> close
```

1. **起票**（相談者） — `new-issue` で `issues/{id}_{slug}.md` を `status: draft` で書き出す
2. **裁可**（user） — 保証節を読み、削る・足す・直したうえで `status: open` にする。
   **open とは裁可済みという意味である。** 実行者は `status:` を触らない
3. **起動**（user） — 作業ブランチ `claude/{id}-{slug}` を切り、実行者をそこで起動する
4. **実装**（実行者） — `pr-workflow` に従って実装し、ローカルコミットで止まる
5. **レビュー**（user） — `git diff main...{branch}` を読み、動作を確かめる
6. **公開**（user） — push → PR 作成 → マージ。PR 本文はコミットメッセージ本文をそのまま使う
7. **クローズ**（user） — Issue の `status:` を `close` にする

**リモートに載るのは、user がローカルでレビューしたものだけになる。**

## 起動と公開の手順

ここは各自の手元の道具で回す。下は素の git と gh で書いた最小形で、自分のシェル関数や
エイリアスに畳んでよい。

### 起動（3 に相当）

```bash
id=07; slug=fix-loader
wt=../$(basename "$PWD").wt/${id}-${slug}
git worktree add "$wt" -b claude/${id}-${slug}
# issue ファイルを worktree へ持ち込み、ブランチ上でコミットしてから実行者を起動する
cp issues/${id}_${slug}.md "$wt/issues/"
cd "$wt"
git add issues/${id}_${slug}.md && git commit -m "chore: open issue ${id}"
```

worktree を使うのは、main のチェックアウトを汚さずに複数の Issue を並列で走らせるため。
issue ファイルは main 側では untracked のまま残す。**ブランチ上でコミットしてから**
起動すると、並行する Issue が互いのブランチに混入しない。

### 公開（6 に相当）

```bash
git push -u origin claude/${id}-${slug}
gh pr create --fill          # コミットメッセージ本文がそのまま PR 本文になる
gh pr merge --squash --delete-branch
git worktree remove ../$(basename "$PWD").wt/${id}-${slug}
```

実行者は 6 のコマンドを実行できない（`guards` のフックが遮断する）。押すのは user である。

## 派生 Issue

検証で問題が出たら、元の Issue を `close` し、`{id}a` として新しい Issue を作る。

**元の Issue を再 open しない。実行者のセッションに追加のプロンプトを送らない。**
記録を上書きすると、何をどう裁可したかが後から読めなくなる。常に Issue ファイルを起点にする。

## 取り込んだあとにやること

1. `issues/` に最初の Issue を置く（`.gitkeep` は消してよい）
2. `CLAUDE.md` に三役と作業フローへの参照を1行書く。**規約そのものを書き写さない**
3. `CLAUDE.md` に静的チェックの表を書く（実行者が提出前に回す手段）。`new-issue` の「確認」
   フィールドと `pr-workflow` の手順4がここを参照する
4. 起動と公開の手順を、自分の手元の形に畳む
