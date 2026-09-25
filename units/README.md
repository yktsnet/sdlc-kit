# Units

取り込み先のリポジトリへ**コピーして使う**配布物。目的ごとに1つの単位にまとめてある。

取り込みは [../README.md](../README.md) の Install にある `install.sh` で行う。
スクリプトを通さないなら、単位のディレクトリの中身をそのままコピーすればよい。単位は
取り込み先の配置を写した形になっている。

```bash
cp -R units/<単位名>/. <取り込み先>/
```

ここには、単位ごとに何が入るかと、入れる前に読むものを置く。

## doc-style — 日本語文書の書き方

文体と、書かないものを1枚に置く。README・CLAUDE.md・`docs/` 配下・PR 本文と、コード中の
日本語コメントに当たる。

**選ばせない。** どの単位を選んでも一緒に入る。理由は
[doc-style.md](doc-style/docs/ops/doc-style.md) にある。

```text
.claude/skills/jp-writing/    文章規範の本体
docs/ops/doc-style.md         リポに置く理由と、リポ固有に決めること
```

## guards — 公開経路を塞ぐ

実行者が自分の変更を自分で公開に載せられない状態を作る。main への push、force push、
`gh pr merge` を拒否する。

**選ばせない。** どの単位を選んでも一緒に入る。

```text
.claude/hooks/no-push-to-main.sh   行為で判定する遮断
.claude/settings.guards.snippet.json   フックの登録と、文字列で足りる deny
docs/ops/guards.md                 なぜ文書でなく機構か、取り込んだあとにやること
```

入れる前に読む: [guards.md](guards/docs/ops/guards.md)

## branch-pr — ブランチと PR の扱い

ブランチの単位＝PR の単位。戻す範囲を変更1本に閉じるための決まりと、済んだブランチを
残さないための機構を置く。

**選ばせない。** どの単位を選んでも一緒に入る。

```text
.claude/hooks/branch-check.sh          セッション開始時にマージ済みブランチを掃除し、居残りを報告
.claude/settings.branch-pr.snippet.json  上記フックの登録
.github/workflows/                     マージされた PR の head ブランチを削除する
docs/ops/branch-and-pr.md              何を1本にするか、マージ、片付け、載せないもの
```

フックとワークフローは対で働く。リモートはマージ時にワークフローが消し、フックが報告するのは
その取りこぼし（マージ前に閉じた PR など）だけになる。

入れる前に読む: [branch-and-pr.md](branch-pr/docs/ops/branch-and-pr.md)

## phase-mvp — 立ち上がり期の駆動文書

`PLAN.md`（何ができたら終わりか）と `JUDGE.md`（なぜその実装なのか）を対で持ち、実装中に
育てる。README へ昇華したら削除する。

```text
.claude/skills/mvp-docs/      2文書の作り方・記録する判断の粒度・テンプレ3枚
docs/ops/phase-mvp.md         足場として扱う理由、畳み方、次のフェーズへの移り方
```

入れる前に読む: [mvp-docs](phase-mvp/.claude/skills/mvp-docs/SKILL.md) /
[phase-mvp.md](phase-mvp/docs/ops/phase-mvp.md)

## phase-guarantee — リリース後の駆動文書

公開面の保証を `docs/guarantees.md` に固定し、各保証をテストが継続検証する。保証の宣言は
user が裁可し、テストの実装は実行者が書く。

既存リポに後から敷く用途で単独で入れてよい。

```text
.claude/skills/guarantee-audit/   初版の敷き方、乖離チェック、書式のサンプル
docs/ops/phase-guarantee.md       何を載せるか、追従のしかた、取り込んだあとにやること
```

入れる前に読む: [guarantee-audit](phase-guarantee/.claude/skills/guarantee-audit/SKILL.md) /
[phase-guarantee.md](phase-guarantee/docs/ops/phase-guarantee.md)

## daily-report — 日報

push 済みのコミットから、Issue も PR も開かない読み手（上司・ステークホルダー）へ向けた1枚を
書く。入力が git なので、どちらの作業フローとも組める。単独で入れてもよい。**作業フローを
入れると一緒に入る。** 作業フローは PR をこまめに出し、その本数を日報が吸収する前提に立つ。

日報だけは `docs/reports/<担当者>/` と担当者ごとに分かれる。日報がファイル名を日付だけで
決めるからで、同じ日に2人が書くと1枚を取り合う。

```text
docs/reports/                 日報の置き場。担当者ごとのディレクトリは skill が作る
.claude/skills/daily-report/  日報 skill と出力テンプレート
docs/ops/daily-report.md      何のためにあるか、取り込んだあとにやること
```

入れる前に読む: [daily-report.md](daily-report/docs/ops/daily-report.md) /
[daily-report](daily-report/.claude/skills/daily-report/SKILL.md)

## walkthrough — 中核の機能の説明資料

中核の機能を1本作り終えたときに、その機能が何を受け取り、どう判断し、何を出すかを1本の解説書に
書き起こす。エージェントと進める実装は人の理解より速く進むので、作った直後に認知負債を返しておく
ためにある。読む人は資料を読み、資料を前提に AI へ質問し、必要になったときに手で確かめて動かす。
どこまで深めるかは読む人が決める。読む人には数か月後の作った本人も含むので、担当が1人でも効く。
作業フローとは独立していて、どちらとも組める。単独で入れてもよい。

```text
.claude/skills/walkthrough/   資料が持つ要素と、書き方の決まり。資料と一覧の型は reference/
docs/ops/walkthrough.md       何のためにあるか、取り込んだあとにやること
```

入れる前に読む: [walkthrough.md](walkthrough/docs/ops/walkthrough.md) /
[walkthrough](walkthrough/.claude/skills/walkthrough/SKILL.md)

## flow-issue — 起票 → 実装 → 完了

着手前の合意を `issues/` の Issue ファイルに残す。三役（user / 相談者 / 実行者）の分業つき。
作業が複数の PR にまたがる、担当者が複数、といった場合はこちら。

```text
issues/                       Issue ファイルの置き場
.claude/skills/new-issue/     相談者が Issue を設計して書き出す。テンプレを同梱
.claude/skills/pr-workflow/   実行者が Issue に基づき実装しコミットする
docs/ops/roles.md             三役の境界と、分業を緩める3経路
docs/ops/workflow.md          一周の流れ、起動と公開の手順、取り込んだあとにやること
```

入れる前に読む: [roles.md](flow-issue/docs/ops/roles.md) /
[workflow.md](flow-issue/docs/ops/workflow.md) /
[new-issue](flow-issue/.claude/skills/new-issue/SKILL.md)

## flow-single — 実装 → 引き渡し

着手前の合意を PR 本文に残す。Issue ファイルを持たない。変更が1本の PR に収まり、担当が
実質1人ならこちら。

```text
.claude/skills/work/          完了条件を宣言し、実装してコミットまで
.claude/skills/hand-off/      完了条件を証拠で裏付け、PR を立てる。PR 本文の型を同梱
docs/ops/workflow.md          一周の流れ、乗り換える合図、取り込んだあとにやること
```

入れる前に読む: [workflow.md](flow-single/docs/ops/workflow.md) /
[work](flow-single/.claude/skills/work/SKILL.md)

## 取り込んだあと

**各単位の `docs/ops/` を読む。** 何をやるか（settings のマージ・穴埋め・CLAUDE.md への
記載）はそこに書いてある。配布元へ戻る必要はない。

共通してやることは3つ。

1. `.claude/settings.*.snippet.json` をすべて `.claude/settings.json` へマージし、snippet を消す
2. `<...>` の形で残してある穴を埋める（`grep -rn "<[^>]*>" .claude/skills docs/ops`）
3. `CLAUDE.md` に、フェーズと作業フローへの**参照**を書く

**`CLAUDE.md` へ単位の規約を書き写さない。** 書き写すと取り込むたびに書き起こしが要り、
リポジトリごとに文言が分かれる。`CLAUDE.md` に置くのは、そのリポ固有のことと参照だけにする。

## 文書・skill・材料の受け持ち

単位の中身は3か所に分かれる。**同じことを2か所に書かない。** 書くと片方だけが直され、
規則と手順が食い違う。単位を直すとき、足すときもこれに沿って分ける。

| 置き場 | 持つもの | 読む人 |
|---|---|---|
| `docs/ops/*.md` | なぜそうするか、変えない決まり、取り込んだあとに1回だけやること | 人。複数の skill も指す |
| `.claude/skills/<name>/SKILL.md` | 手順。段の順、コマンド、止まるところ、人に尋ねること | skill を呼んだときのエージェント |
| `.claude/skills/<name>/reference/` | 実行中に使う材料。型、checklist、聞き取りの質問 | 実行中のエージェント |

- **文書を残すのは、skill を通らない作業にも規則を効かせるためである。** マージする人、
  レビューする人、エージェントを使わずに手で直す人も同じ規則の下にいる。skill は呼んだときに
  しか読まれない
- **複数の skill にまたがる決まりは文書に1つだけ置く。** skill は「どこそこの表に従う」と
  指し、中身を写さない
- **skill は理由を繰り返さない。** 理由が要る段では文書の節を指す
- **文書は手順を書かない。** 段の順とコマンドは skill が持つ
