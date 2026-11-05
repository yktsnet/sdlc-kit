## 秘密情報が GitHub に届くのを手元と CI で止める secret-guard 単位を足す
id: 02
branch-slug: add-secret-guard
status: open
type: feat
対象:
- units/secret-guard/.claude/hooks/no-secret-commit.sh (新規)
- units/secret-guard/.claude/settings.secret-guard.snippet.json (新規)
- units/secret-guard/.claude/secret-guard.gitignore.snippet (新規)
- units/secret-guard/.github/workflows/gitleaks.yml (新規)
- units/secret-guard/docs/ops/secret-guard.md (新規)
- units/README.md
- README.md
- docs/design-philosophy.md
目的: エージェントと開発するリポで、パスワード・API キー・秘密鍵がコミットに入り、GitHub へ届くことを減らす。今の単位は main への push とマージは止めるが、何を push するかの中身は見ていない。
内容: 秘密情報を止める層を、手元と GitHub の両方に置く単位を足す。手元では `.gitignore` の行と、Claude が `git commit`・`git push` を打つ前に差分を調べる PreToolUse の hook を置く。GitHub では PR ごとに gitleaks で調べるワークフローを置き、push protection と push ruleset は管理者に頼む設定として文書に書く。
対象外:
- GitHub の push protection と push ruleset を設定するスクリプト。プランと権限で使えるかが変わるので、文書で管理者に頼む
- `gitleaks-action` の利用。組織のアカウントでは有料のライセンスが要る
- 人が手で打つ `git commit`・`git push` を止める仕組み（pre-commit の git hook など）。各自の手元に道具を入れさせない
- 形の決まらない秘密（地の文に書いたパスワードなど）の検出。CI とレビューに任せる
- 実際のリポへの取り込みと、GitHub 上での CI の実行
仮定:
- 必須にせず、単独で足せる単位にする。`units/README.md` では「単独で足せるもの」の並びに置く。Actions を使えないリポや、GitHub の設定を変えられないリポでも、手元の2層だけで入れられるようにする
- hook の拒否は、`guards` の `no-push-to-main.sh` と同じく `permissionDecision: deny` の JSON で返す。同じ単位群のフックで返し方を揃える
- `.gitignore` の行は `cp -R` で取り込み先の `.gitignore` を上書きしないよう、`.claude/secret-guard.gitignore.snippet` に置く。取り込んだあとに足りない行を `.gitignore` へ足し、snippet を消す
- hook の下敷きは、user が手元で使っている同じ役の hook である。実行者は着手のときに user から受け取る。受け取れなければ、下の「詳細」の仕様から書く
- gitleaks のバージョンは 8.30.1 にする
確認:
- `bash -n units/secret-guard/.claude/hooks/no-secret-commit.sh` が通ること
- 下の「詳細」の hook の節にある2つの試し方で、AWS のアクセスキーを含むコミットが deny の JSON で止まり、出力に値（`AKIA` に続く文字列）が含まれず、無害なファイルのコミットが何も出さずに通ること
- `gitleaks.yml` の `SHA256` が、gitleaks の v8.30.1 のリリースの `checksums.txt` にある `gitleaks_8.30.1_linux_x64.tar.gz` の値と一致すること（`gh release download v8.30.1 -R gitleaks/gitleaks -p gitleaks_8.30.1_checksums.txt -O -` で取る）
- `settings.secret-guard.snippet.json` の hook のパスが、置いたファイルを指していること
- `grep -rn "~/\|dotfiles\|install.sh\|snippets/" units/secret-guard/` が0件であること
- `units/README.md` の単位のツリーと README の Units 表が、新しく入るファイルと一致していること
- 文書・skill・材料の受け持ち（`units/README.md` の表）に沿っていること。理由は `docs/ops/secret-guard.md` が持ち、hook のコメントは非自明な WHY だけにする
- 変更した文書内の相対リンクがすべて実在するファイルを指していること
根拠: units/ と docs/ を "secret" "gitleaks" "\.env" "password" で検索し、該当なし。`units/guards/` 一式（`no-push-to-main.sh` の返し方と、jq か python3 が無いときの止め方）、`units/branch-pr/.claude/settings.branch-pr.snippet.json`（snippet の名前の付け方）、`units/README.md`「文書・skill・材料の受け持ち」「単位を直す・足すとき」、`docs/design-philosophy.md` の単位の段階の節を読んだ
待ち: PR #34（grasp 単位）。`docs/design-philosophy.md` の「どの段階でも単独で足せる」の行を同じく書き換えるので、マージの後に着手する
人が見るもの: 取り込み先のリポで hook を1回止めさせ、拒否の文面から直し方が分かるかを見る

---

### 保証
- 新たに宣言する保証:
  - Claude が `git commit` を打つとき、HEAD から変わった追跡中のファイルに秘密の形の値か秘密を置くファイル名があれば、hook が拒否する。同じコマンドに `git add` があれば、追跡していないファイル（`.gitignore` で外したものを除く）も調べる
  - Claude が `git push` を打つとき、まだリモートに無いコミットに同じものがあれば、hook が拒否する
  - 拒否の文面はファイル・行・種類を出し、値は出さない
  - 行に `gitleaks:allow` と書いた行は、hook も CI の gitleaks も通す
  - `.env.example`・`.env.sample`・`.env.template` は、ファイル名では止めない
  - heredoc の本文にある `git push` の文字列では、hook は走らない
  - python3 が無い環境では、hook は commit と push を止める
- 維持する保証:
  - `guards` の hook と deny の振る舞いは変わらない
- 確かめ方: このリポにテストは無いので、上の「確認」の hook の試し方で確かめる

### units/secret-guard/.claude/hooks/no-secret-commit.sh（新規）

PreToolUse（Bash）で、コマンドを区切り（`&&` `||` `;` `|` 改行）ごとに見て、先頭が `git commit` か `git push`（`git -C <dir>` 付きを含む）のときだけ調べる。heredoc の本文は先に外す。`git` と `python3` だけで動かす。

探すもの:
- ファイル名: `.env`・`.env.*`（`.env.example`・`.env.sample`・`.env.template` を除く）、`*.pem`・`*.key`・`*.p12`・`*.pfx`、`id_rsa`・`id_ed25519`
- 中身: 秘密鍵の見出し（`-----BEGIN ... PRIVATE KEY-----`）、AWS のアクセスキー（`AKIA` か `ASIA` に大文字英数16文字）、GitHub のトークン（`ghp_` など）、Slack のトークン（`xox[baprs]-`）、Google の API キー（`AIza`）、`sk-` で始まる API キー、Stripe のキー（`sk_live_` など）、`password = "..."` のように値を直書きした代入（値が空・変数参照・プレースホルダのものは除く）

調べる範囲:
- `git commit`: `git diff HEAD` の追加行。同じコマンドに `git add` があれば、`git ls-files --others --exclude-standard` のファイルも中身ごと見る
- `git push`: `git log --branches --not --remotes` の範囲のコミットの追加行。どのブランチを送るかは引数の形がさまざまなので、送る先を読み分けない

試し方:

```bash
d=$(mktemp -d) && git -C "$d" init -q && printf 'AKIA%s\n' ABCDEFGHIJKLMNOP > "$d/leak.txt"
printf '{"cwd":"%s","tool_input":{"command":"git add leak.txt && git commit -m x"}}' "$d" | units/secret-guard/.claude/hooks/no-secret-commit.sh
# → "permissionDecision":"deny" を含む JSON に leak.txt:1 と種類が出て、AKIA に続く値は出ない

rm "$d/leak.txt" && echo ok > "$d/ok.txt"
printf '{"cwd":"%s","tool_input":{"command":"git add ok.txt && git commit -m x"}}' "$d" | units/secret-guard/.claude/hooks/no-secret-commit.sh; echo "exit=$?"
# → 何も出さずに exit=0
```

### units/secret-guard/.claude/settings.secret-guard.snippet.json（新規）

`hooks.PreToolUse` の Bash に `$CLAUDE_PROJECT_DIR/.claude/hooks/no-secret-commit.sh` を登録する。`timeout` と `statusMessage` は `guards` の snippet に揃える。

### units/secret-guard/.claude/secret-guard.gitignore.snippet（新規）

上の「ファイル名」の並びを `.gitignore` の書式で置く。例のファイルは `!.env.example` のように否定で戻す。

### units/secret-guard/.github/workflows/gitleaks.yml（新規）

- `pull_request` と main への `push` で走る。`permissions: contents: read`
- `actions/checkout` を `fetch-depth: 0` で取る
- gitleaks の本体をリリースから取り、`sha256sum -c` で確かめてから展開する。`VERSION` と `SHA256` は env に置く
- PR では `HEAD^1..HEAD`、main への push では `github.event.before..HEAD` を `--log-opts` に渡す。`before` が全ゼロなら履歴全体を見る
- `--redact` を付け、ログに値を出さない

### units/secret-guard/docs/ops/secret-guard.md（新規）

- どこで止めるか: `.gitignore`・hook・CI・GitHub の設定の4層を、何を止めるか、人の手の push にも効くか、止まる時点の表で示す。push の時点で誰に対しても止められるのは GitHub の設定だけであること
- 手元の hook: 探すもの、調べる範囲、拒否の出し方、`gitleaks:allow` での除外
- CI の gitleaks: `gitleaks-action` を使わない理由、バージョンの上げ方（`VERSION` と `SHA256` を両方替える）、落ちたらマージの前に値を無効にすること
- GitHub の設定: push protection と push ruleset の設定画面の場所。プランによっては使えないこと
- 取り込んだあとにやること: settings の snippet のマージ、`.gitignore` の snippet のマージ、すでに追跡している秘密のファイルの確かめ方、Actions が使えないなら `gitleaks.yml` を消すこと、管理者への依頼、hook の試し方
- 前提: `python3`・`git`・GitHub Actions

### units/README.md / README.md / docs/design-philosophy.md

- `units/README.md` に `## secret-guard — 秘密情報を GitHub に上げない` の節を足す。並びは「単独で足せるもの」の中
- README の Units 表に1行足す
- `docs/design-philosophy.md` の「どの段階でも単独で足せる」の行に `secret-guard` を加える
