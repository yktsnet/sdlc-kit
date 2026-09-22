# sdlc-kit

AI エージェントと開発を回すときの型を、1リポジトリずつ取り込める単位に切り出したもの。

エージェントを走らせると、ボトルネックは生成から検証と意図伝達へ移る。何を約束したのか、
誰が裁可したのか、何を確かめて終わったと言っているのか。これらはコードには残らない。
ここで配るのは、それを残すための置き場と手順である。

型にするのは、エージェントが自力で越えられないところだけにしている。判断基準は
[docs/design-philosophy.md](docs/design-philosophy.md) にある。

## Install

このリポジトリを clone し、取り込み先を指定して実行する。

```bash
git clone https://github.com/yktsnet/sdlc-kit.git
cd sdlc-kit
./install.sh ~/repos/myrepo single
```

引数は「取り込み先・作業フロー・追加単位」の順。作業フローは省略できる。

```bash
./install.sh ~/repos/myrepo issue mvp guarantee
./install.sh ~/repos/myrepo guarantee          # 既存リポに保証台帳だけ敷く
```

| 引数 | 入る単位 |
|---|---|
| `issue` | `flow-issue` — 合意を `issues/` の Issue ファイルに残す。三役の分業つき |
| `single` | `flow-single` — 合意を PR 本文に残す。担当が実質1人ならこちら |
| `mvp` | `phase-mvp` — `PLAN.md` / `JUDGE.md`。立ち上がり期の駆動文書 |
| `guarantee` | `phase-guarantee` — `docs/guarantees.md`。リリース後の駆動文書 |

選ぶときに効く決まりが2つある。

- **作業フローは1つだけ選ぶ。** `issue` と `single` を同居させない。選び方は
  [docs/task-flows.md](docs/task-flows.md) にある
- **`doc-style` と `guards` は選ばせない。** どれを選んでも一緒に入る。文体の規範と遮断は、
  書き手や走らせ方が替わった時点で最初に崩れる

既存ファイルと中身が違う場合は差分を見せて確認する。黙って上書きはしない。

**グローバル（`~/.claude/`）には入れられない。** 各単位は `docs/ops/` の文書と、そのリポの
事情を書き込む穴（`<検証コマンド>` など）を持っていて、リポジトリの中にあって初めて成立する。

**コピーした先は、その時点でそのリポの持ち物になる。** 以降はコピー先を直し、取り込み元へは
戻さない。取り込み以降に配布元が何を変えたかは `./install.sh --diff ~/repos/myrepo` で見る。
当てるかどうかは人が決める。自動では更新しない。

**次に読むのは、コピーされた `docs/ops/` の文書**である。そのリポの事情を書き込む穴が
残っていて、埋め方と `CLAUDE.md` への記載が書いてある。スクリプトも最後にその一覧を出す。

## 何が入るか

### 2つの駆動文書

開発文書には寿命がある。単一の仕様書を永続させようとせず、フェーズごとに駆動文書を
交代させる。

- **MVP 期** — `PLAN.md`（何ができたら終わりか）と `JUDGE.md`（なぜその実装なのか）。
  README へ昇華したら削除する足場であり、永続を求めない
- **Issue ドリブン期** — 保証台帳（`docs/guarantees.md`）。「何を約束し、何を約束して
  いないか」だけを記し、各約束は対応するテストが継続検証する。README と違い、破れば落ちる
  ため黙って腐らない

台帳が正式運用に上がる瞬間が交代点である。詳細は
[docs/lifecycle.md](docs/lifecycle.md)。

### 保証の裁可（GDD）

保証の宣言（何が成り立つべきか）は user が裁可し、テストの実装はエージェントが書く。

TDD がテストを先に書く規律だとすれば、**GDD は約束の裁可を先に行う規律**である。人間の
仕事はテストを書くことから、約束を裁可することへ移る。テストそのものが正なのではなく、
裁可された保証を実行可能な形に書き下ろしたものが正である。

### 役割の分離

決定と実行を同じ時間の中でやると、決定が実行の都合に引きずられて検証できなくなる。

`flow-issue` は三役に分ける。**user**（保証の裁可・レビュー・マージ）、**相談者**（調査と
Issue 設計。実装しない）、**実行者**（Issue に基づく実装とローカルコミット。リモートに
触れない）。`flow-single` は実装者と user の2者で、合意は PR 本文に残る。

どちらも、リモートに載るのは user がローカルでレビューしたものだけになる。

硬直を避けるため、Issue 化を飛ばしてよい経路も定めてある（障害対応・単発の明示例外・
ロジックに触れない小さな差分）。

### 遮断

禁止は `CLAUDE.md` ではなく `settings.json` の deny とフックに置く。同じ内容でも、置き場所が
違えば守られる確率の桁が違う。

フックの利得は、拒否と同時に正しい経路へ寄せられる点にある。エージェントは拒否されると別の
手を試すので、何を試すかを拒否文で指定できる。**遮断は否定ではなく分岐器である。**

## Repository Structure

| | 持つもの |
|---|---|
| `units/` | 取り込んで使う配布物（[units/README.md](units/README.md)） |
| `docs/` | 配るものの根拠（[design-philosophy.md](docs/design-philosophy.md)）、駆動文書の交代（[lifecycle.md](docs/lifecycle.md)）、作業フローの選び方（[task-flows.md](docs/task-flows.md)） |
| `install.sh` | 選んだ単位を取り込み先へコピーする |

## 出どころ

個人のインフラ設定リポ [yktsnet/dotfiles-public](https://github.com/yktsnet/dotfiles-public)
で回している運用から、環境に依存しない部分だけを切り出した。あちらが正本であり、こちらは
抽出版である。

配布元で使っているシェル関数（worktree の作成からマージまでを一括で畳んだもの）は配らない。
worktree を切ってエージェントを起動し、レビューを経て push・PR・マージへ進むという**手順**を
[flow-issue の workflow.md](units/flow-issue/docs/ops/workflow.md) に書いてある。実行は素の
git と gh で足りる。自分のシェル関数に畳むかどうかは取り込んだ側が決める。

## License

MIT
