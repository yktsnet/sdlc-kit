# 作業フロー（Issue 版）

着手前の合意を `issues/` の Issue ファイルに残す。作業が複数の PR にまたがる、着手が数日後に
なる、担当者が複数いる、といった場合はこちら。1本の PR に収まるなら `flow-single` を選ぶ。

役割の境界は [roles.md](roles.md)、ブランチと PR の単位は [branch-and-pr.md](branch-and-pr.md) にある。

## 入るもの

```text
issues/                                   Issue ファイルの置き場。ここが唯一の真実
.claude/skills/local-issue/               相談者が Issue を設計して書き出す
.claude/skills/pr-workflow/               実行者が Issue に基づき実装し、確認を受けて PR を出す
docs/ops/roles.md                         三役の境界と、分業を緩める3経路
docs/ops/workflow.md                      この文書
```

## 一周の流れ

```text
draft ──（user が保証節を裁可）──> open ──（実装・確認・close を載せた PR をマージ）──> close
```

1. **起票**（相談者） — `local-issue` で `issues/{id}_{slug}.md` を `status: draft` で書き出す
2. **裁可**（user） — 保証節を読み、削る・足す・直したうえで `status: open` にする。
   **open とは裁可済みという意味である。**
3. **起動**（user） — 作業ブランチ `claude/{id}-{slug}` を worktree に切り、実行者をそこで起動する
4. **実装**（実行者） — `pr-workflow` に従って実装し、コミットで止まる
5. **確認と直し**（user と実行者） — user が `git diff main...{branch}` を読み、動作を確かめる。
   直す点は同じセッションで伝え、実行者が追加コミットで直す。OK が出るまで繰り返す
6. **公開**（実行者） — user の OK を受けて、Issue の `status:` を `close` にしてコミットし、
   自分のブランチを push して PR を出す
7. **マージ**（user） — PR を読んでマージする

**リモートに載るのは、user が実行者のセッションで確かめて OK を出したものだけになる。**
実行者が push できるのは自分のブランチだけで、main への push とマージは `guards` のフックが
遮断する。

**確認と直しを同じセッションで回す。** 実行者は実装の文脈を持ったまま止まっているので、
指摘をそこで直すのが最も安い。PR の前に別の Issue を起こすと、合意の置き場が2つに割れる。

**close は実装の PR に載せる。** マージした時点で、実装と close が同時に main に入る。マージの後で
close を別に書くと、main に実装はあるのに Issue が open のまま残る期間ができ、close だけの
コミットが1本増える。マージせずに PR を閉じたら close も main に入らないので、Issue は open の
ままになる。

## 起動と片付けの手順

ここは各自の手元の道具で回す。下は素の git で書いた最小形で、自分のシェル関数や
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

main 側の issue ファイルは、マージで close の版が戻るまで `status: open` のまま残る。
着手済みかどうかはファイルの `status:` では分からないので、`claude/{id}-{slug}` の
ブランチの有無で見る。手元の道具で着手できる Issue を並べるなら、ブランチのあるものを外す。

### 片付け（6 と 7 の後）

worktree は PR を出したら消し、ブランチはマージの後に消す。片付けを1回にまとめず、
起きる時点で分ける。

```bash
# PR を出したら: 実行者のセッションを閉じ、main のチェックアウトで worktree を消す
git worktree remove ../$(basename "$PWD").wt/${id}-${slug}
# 承認済みでまだ残っている main 側の issue ファイル（untracked）は、マージで戻る版と衝突するので消す
rm issues/${id}_${slug}.md
```

ブランチは、マージの後に `branch-pr` の `branch-check.sh` がセッション開始時に消す。
worktree に取り出したままのブランチは `git branch -d` で消せないので、worktree を先に
消しておく。PR の後に直しが要ったら、origin のブランチから worktree を作り直す。

マージせずに PR を閉じたブランチは、`branch-check.sh` が消さない（マージ済みしか見ない）。
捨てると決めたら `git branch -D claude/${id}-${slug}` で手で消す。消すと、上の見分け方で
その Issue は未着手に戻る。

この起動から片付けまでを1コマンドに畳んだ例として、[dotfiles-public](https://github.com/yktsnet/dotfiles-public)
の `i`（`home-manager/modules/zsh/functions/aiagent.sh`）がある。

## 派生 Issue

PR を出す前の問題は、5 の中で実行者が直す。新しい Issue にしない。

マージした後に問題が出たら、元の Issue を再 open せず、`{id}a` として新しい Issue を作る。
記録を上書きすると、何をどう裁可したかが後から読めなくなる。

## 取り込んだあとにやること

1. `issues/` に最初の Issue を置く（`.gitkeep` は消してよい）
2. `CLAUDE.md` に三役と作業フローへの参照を1行書く。**規約そのものを書き写さない**
3. `CLAUDE.md` に静的チェックの表を書く（実行者が提出前に回す手段）。`local-issue` の「確認」
   フィールドと `pr-workflow` の手順4がここを参照する
4. 起動と片付けの手順を、自分の手元の形に畳む
