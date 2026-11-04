## 別のコンテキストで点検する役（確認者・校正役・構成の点検役）を単位に足す
id: 01
branch-slug: add-separate-context-checkers
status: open
type: feat
対象:
- units/flow-team/.claude/agents/issue-verifier.md (新規)
- units/flow-team/.claude/skills/issue-work/SKILL.md
- units/flow-team/docs/ops/roles.md
- units/flow-team/docs/ops/workflow.md
- units/flow-solo/.claude/agents/completion-verifier.md (新規)
- units/flow-solo/.claude/skills/work/SKILL.md
- units/flow-solo/.claude/skills/hand-off/SKILL.md
- units/flow-solo/docs/ops/workflow.md
- units/doc-style/.claude/agents/jp-proofreader.md (新規)
- units/doc-style/.claude/agents/md-reviewer.md (新規)
- units/doc-style/.claude/skills/md-writing/SKILL.md (新規)
- units/doc-style/docs/ops/doc-style.md
- units/README.md
- README.md
- docs/flows/solo.md
- docs/flows/team.md
内容: 作った本人・書いた本人は自分の意図どおりに読むので、約束から外れたところや自分の文の癖が見えない。今の単位は、実装の確かめも文書の校正も本人のコンテキストで済ませている。`docs/design-philosophy.md` が2段目に置く「エージェントの点検」を、本人とは別のコンテキストで走る subagent として配る。flow-team には Issue を基準に判定する確認者を、flow-solo には `work` が宣言した完了条件を基準に判定する確認者を入れる。doc-style には日本語の表現を直す校正役と、Markdown の組み立てを点検する役を入れる。下敷きは dotfiles-public の `.claude/agents/` にある同名の4本（`screen-operator` は除く）。
対象外:
- `screen-operator` の移植。画面の操作は確認者が手段の有無を見て「判定できない」に回す
- 差分のファイル一覧と `対象` の一致をスクリプトで判定する仕組み（dotfiles 版の `check-scope.sh` に当たるもの）。今回の確認者は `git diff --name-only` の出力を証拠に添えて判定する
- flow-client の skill（`client-next`）と `docs/flows/client.md`。flow-client は flow-team に重ねて入れるので、確認者は flow-team 側から入る
- `docs/design-philosophy.md` と `docs/task-flows.md` の書き換え
- 実際のリポへの取り込みと動作確認
仮定:
- 1本の Issue にまとめる（user の指定）。対象は16本で、目安の7本を超える
- 確認者はフローごとに別の定義にする。判定の基準（GitHub Issue と、`work` のコミットに残る完了条件）が違うため。名前は `issue-verifier`（flow-team）と `completion-verifier`（flow-solo）
- agent 定義の `model:` は書かない（呼び出し元のモデルを継ぐ）。モデル ID を固定すると、コピー先で古い ID が残り続けるため。固定したいリポは取り込み後に書き足す、と各単位の `docs/ops/` の「取り込んだあとにやること」に書く
- `md-reviewer` が読む規範として `md-writing` を doc-style 単位に同梱する。`~/.claude/skills/md-writing/SKILL.md` を下敷きにし、取り込み先のリポ内で完結する形に作り直す
- 校正役と点検役の規範の既定は、取り込み先のリポ内のパス（`.claude/skills/jp-writing/SKILL.md`・`.claude/skills/md-writing/SKILL.md`）にする。`~/.claude/` は参照しない
確認:
- 新規の agent 定義4本が frontmatter（`name`・`description`・`tools`）を持ち、`tools` が下記の詳細どおりであること
- `grep -rn "~/\|dotfiles\|screen-operator\|check-scope\|pr-workflow\|issues/done\|crit" units/` が、新規・変更した行で1件も出ないこと
- `grep -rn "claude-opus\|claude-sonnet\|claude-haiku" units/` が0件であること
- `issue-work` の手順に確認者を呼ぶ段があり、「否」「判定できない」のときの扱い（直して再開させる／user に残す）と、直したあとの再呼び出しが書かれていること。`hand-off` も同じ
- `issue-work`・`work` に、日本語の `.md` を書き換えたらコミットの前に `jp-proofreader` を呼ぶ段があり、新しい `.md` か見出しの増減があれば `md-reviewer` も並べて呼ぶと書かれていること
- `units/README.md` の各単位のツリーと、README の Units 表・Required Units が、新しく入るファイルと一致していること
- 文書・skill・材料の受け持ち（`units/README.md` の表）に沿っていること。理由は `docs/ops/`、手順は SKILL.md、agent 定義はその役が実行中に従う決まりだけを持ち、同じことを2か所に書いていないこと
- 変更した文書内の相対リンクがすべて実在するファイルを指していること
人が見るもの: 実際のリポへ取り込み、確認者・校正役・点検役を1回ずつ呼んで、判定の表や報告が使える粒度かを見る

---

### 保証
- 保証: なし（文書と agent 定義だけの変更で、テストを持たないリポのため）

### units/flow-team/.claude/agents/issue-verifier.md（新規）

dotfiles-public の `.claude/agents/issue-verifier.md` を下敷きにする。変えない芯は次の3つ。

- 基準は Issue だけで、実行者の説明を判定の根拠にしない
- 証拠にしたテストの期待値を、テストから読まずに Issue とテストの入力から出し直す
- 直さない。worktree の編集と git・`gh` の書き込みをしない

書き換えるところ:

- 受け取るものは「Issue 番号」「worktree のパス」。Issue は `gh issue view {N}` で読む（読み取りのみ）
- 読むものから `issues/done` などファイルの Issue に依存する箇所を外す
- 範囲の判定は `git diff --name-only main...HEAD` の出力と Issue の `対象` を突き合わせ、出力を証拠に貼る
- 画面に出る項目は、ヘッドレスのブラウザ（Playwright 等）がリポで使えるなら確かめ、無ければ「判定できない」にする。`screen-operator` への言及は消す
- 「再開されたとき」と「返すもの」の表はそのまま残す
- `tools: Bash, Read, Grep, Glob`。dotfiles 版にある `Write` は外す（直さない役なので）

### units/flow-team/.claude/skills/issue-work/SKILL.md

- 手順6の `git add` の前に、日本語の `.md` を書き換えていれば `jp-proofreader` を呼ぶ段を足す。新しい `.md` か見出しの増減があれば `md-reviewer` も並べて呼ぶ。渡すものと呼び方の決まりは doc-style.md の節を指し、中身を写さない
- 手順7（コミット）のあとに、`issue-verifier` へ Issue 番号と worktree のパスを渡す段を足す。実装の説明は渡さない
  - 「否」があれば直して追加コミットし、前回の判定以降のコミット範囲を渡して同じ確認者を再開させる。「否」が消えるまで繰り返す
  - 「判定できない」は直さず、手順8の出力に残す
- 手順8の出力に、確認者の判定の表と「user に残る確認」を載せる。user は挙動の照合ではなく、使い心地と、確認者が判定できなかったものを見る
- 手順9（直し）のあとも、確認者を再開させてから手順8に戻る

### units/flow-team/docs/ops/roles.md

三役の表は変えず、確認者を役の外の道具として書き足す。実行者の境界に「コミットのあと確認者の判定を受ける」を入れる。確認者を置く理由（作った本人は自分の意図どおりに読む）はここに1回だけ書き、SKILL.md と workflow.md はここを指す。

### units/flow-team/docs/ops/workflow.md

「一周の流れ」の 4 と 5 のあいだに確認者の判定を入れ、5 で user が見るものを「使い心地と、確認者が判定できなかったもの」に寄せる。「入るもの」に agent 定義を足す。

### units/flow-solo/.claude/agents/completion-verifier.md（新規）

`issue-verifier` と同じ芯で、基準を `git log main..HEAD` に残る `work` の宣言（対象・完了条件・対象外・仮定・保証）に替える。完了条件ごとに自分で実行して合否と証拠を返す。返す表は `hand-off` が `## 証拠` に貼れる形（完了条件と1対1、出力を要約しない）にする。`tools: Bash, Read, Grep, Glob`。

### units/flow-solo/.claude/skills/work/SKILL.md

コミットの前に `jp-proofreader`（必要なら `md-reviewer`）を呼ぶ段を足す。決まりは doc-style.md を指す。

### units/flow-solo/.claude/skills/hand-off/SKILL.md

手順2を、実装者が自分で裏付けるのではなく `completion-verifier` に判定させる形に変える。

- 「否」があれば PR を立てずに直し、確認者を再開させる
- 「判定できない」は `## 検証手順` へ回す。「確認済み」と書かない
- `## 証拠` には確認者が返した証拠を貼る

### units/flow-solo/docs/ops/workflow.md

「証拠の無い完了を書かない」の節に、証拠を取るのは別のコンテキストの確認者である理由を足す。「入るもの」に agent 定義を足す。

### units/doc-style/.claude/agents/jp-proofreader.md・md-reviewer.md（新規）

dotfiles-public の同名の定義を下敷きにする。`tools` は元のまま（`jp-proofreader` は `Read, Edit`、`md-reviewer` は `Read, Grep, Glob`）。規範の既定のパスだけを、取り込み先のリポ内（`docs/ops/doc-style.md` → `.claude/skills/jp-writing/SKILL.md`、`md-reviewer` は `.claude/skills/md-writing/SKILL.md`）に替える。

### units/doc-style/.claude/skills/md-writing/SKILL.md（新規）

`~/.claude/skills/md-writing/SKILL.md` を下敷きにする。環境に依存する記述があれば一般の条件へ言い換える。

### units/doc-style/docs/ops/doc-style.md

校正役と点検役を呼ぶ決まりを置く。複数の skill から指される決まりなので、ここが正本になる。

- 日本語の `.md` を書き換えたら、コミットの前に `jp-proofreader` を呼ぶ。渡すのは分岐元から書き換えた `.md` のパスと、`git diff -U0` の hunk 見出しから取った行の範囲
- 新しい `.md` を作ったか、見出しを足した・消した・動かしたら、`md-reviewer` も並べて呼ぶ
- 校正役が意図を変えた直しは戻す。報告に回された点は書き手が直すか残すかを決める
- 呼ぶのは1回で終える。直した行のために呼び直さない
- 理由（書いた本人は自分の文の癖に気づけない）

### units/README.md・README.md

各単位のツリーに `.claude/agents/` を足す。README の Required Units の doc-style の説明に校正役と点検役を足す。flow-solo・flow-team の Units 表の説明は、確認者を一言で足す程度にする。

### docs/flows/solo.md・team.md

一周の案内のうち、実装と確認の場面に確認者の判定が挟まることを書き足す。図（Mermaid）にノードを足すかは書き手が決める。
