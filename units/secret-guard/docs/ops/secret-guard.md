# 秘密情報を GitHub へ上げない

パスワード・API キー・秘密鍵がコミットに入り、GitHub へ届くのを防ぐ。

**この仕組みは `sdlc-kit` から取り込んだものである。** 取り込んだ時点でこのリポの
持ち物になった。以降はここを直す。

## 入るもの

```text
.claude/hooks/no-secret-commit.sh              Claude による、秘密を含むコミットと push を拒否する
.claude/settings.secret-guard.snippet.json     上記フックの登録
.claude/secret-guard.gitignore.snippet         .gitignore に足す、秘密を置くファイルの行
.github/workflows/gitleaks.yml                 PR と main への push を gitleaks で調べる
```

## どこで止めるか

1か所では塞げないので、手元と GitHub の両方に置く。手元の層は、各自が何もインストールせずに動く
ものだけにしてある。網羅的なスキャンは GitHub のランナーで動かす。

| 層 | 何を止めるか | 人の手の push にも効くか | 止まる時点 |
|---|---|---|---|
| `.gitignore` | `.env` や鍵ファイルを `git add` で拾うこと | 効く。`git add -f` と、名前の違うファイルは通る | コミットの前 |
| `.claude/hooks/no-secret-commit.sh` | Claude による、秘密を含むコミットと push | 効かない。Claude 経由だけ | コミット・push の前 |
| `.github/workflows/gitleaks.yml` | 秘密を含む PR のマージ | 効く | push の後 |
| GitHub の push protection と push ruleset | 秘密を含む push そのもの | 効く | push の時点 |

**push の時点で誰に対しても止められるのは、GitHub の設定だけである。** CI が落ちた時点で、
秘密はもう GitHub に載っている。手元の2層は、うっかり載せる回数を減らすためにある。

## 手元のフック

Claude が `git commit` か `git push` を打つ前に、送られうる差分を調べる。各自に gitleaks を
入れさせないため、`git` と `python3` だけで動き、形の決まったものだけを探す。

- **ファイル名**: `.env`・`.env.*`（`.env.example` などの例は除く）、`*.pem`・`*.key`・`*.p12`・
  `*.pfx`、`id_rsa` などの鍵
- **中身**: 秘密鍵の見出し、AWS のアクセスキー、GitHub・Slack のトークン、Google の API キー、
  `sk-` で始まる API キー、Stripe のキー、`password = "..."` のように値を直書きした代入

調べる範囲はコマンドで変わる。

- `git commit`: 追跡しているファイルの、HEAD からの変更すべて。同じコマンドに `git add` があれば、
  追跡していないファイル（`.gitignore` で外したものを除く）も見る
- `git push`: まだリモートに無いコミットすべて。どのブランチを送るかは引数の形がさまざまなので、
  送る先を読み分けずに広く見る

止めたときは、拒否の理由として、ファイルと行と種類を返す。値は出さない。

**誤検知なら、その行に `gitleaks:allow` と書き添える。** CI の gitleaks も同じ記述で除外するので、
両方に1つの書き方で済む。テストのための偽の値などに使う。

形の決まらない秘密（社内システムのパスワードを地の文に書いた、など）は拾えない。これは CI と
レビューに任せる。

## CI の gitleaks

PR ごとに、PR で入るコミットを gitleaks で調べる。main への push では、前回の先頭コミットより後のコミットを調べる。

**`gitleaks-action` は使わない。** 組織のアカウントでは有料のライセンスが要る。代わりに
gitleaks の本体をリリースから取得して、チェックサムを確かめてから動かす。バージョンを上げるときは
`VERSION` と `SHA256` の両方を、リリースの `gitleaks_<バージョン>_checksums.txt` に合わせて書き換える。

private リポジトリでは、Actions の実行時間が、アカウントに割り当てられた利用時間から引かれる。

**落ちたら、マージする前に値を無効にする。** push した時点で GitHub に載っているので、
コミットを消しても漏れは取り消せない。

## GitHub の設定

ファイルでは配れないので、リポジトリか組織の管理者が設定する。どちらもプランによっては使えない。
使えるかどうかは、設定画面に項目があるかで確かめる。

- **push protection**: Settings → Advanced Security（プランによっては Code security）→
  Secret Protection を有効にし、Push protection を有効にする。既知の形式のトークンを含む push を
  拒否する。private リポジトリでは有料の GitHub Secret Protection が要る
- **push ruleset**: Settings → Rules → Rulesets → New ruleset → New push ruleset。
  Restrict file paths に `.env`・`**/*.pem` などを入れる。ファイルの中身は見ず、パスで拒否する

## 取り込んだあとにやること

1. `.claude/settings.*.snippet.json` をすべて `.claude/settings.json` へマージし、snippet を消す
2. `chmod +x .claude/hooks/no-secret-commit.sh`
3. `.claude/secret-guard.gitignore.snippet` の行のうち、`.gitignore` に無いものを足し、snippet を消す
4. 既に秘密を置くファイルを追跡していないか確かめる。出たら、値を無効にしてから追跡を外す

   ```bash
   git ls-files | grep -E '(^|/)(\.env(\.[^/]+)?|id_(rsa|dsa|ecdsa|ed25519)|[^/]+\.(pem|key|p12|pfx|jks|keystore))$' | grep -vE '\.env\.(example|sample|template)$'
   # → 何も出なければ正しい
   ```

5. Actions が使えるか確かめる（Settings → Actions）。使えないなら `.github/workflows/gitleaks.yml` を消す
6. 管理者に「GitHub の設定」を頼む
7. フックの動作を確かめる

   ```bash
   d=$(mktemp -d) && git -C "$d" init -q && printf 'AKIA%s\n' ABCDEFGHIJKLMNOP > "$d/leak.txt"
   printf '{"cwd":"%s","tool_input":{"command":"git add leak.txt && git commit -m x"}}' "$d" | .claude/hooks/no-secret-commit.sh
   # → "permissionDecision":"deny" を含む JSON に leak.txt:1 AWS のアクセスキー と出れば正しい

   rm "$d/leak.txt" && echo ok > "$d/ok.txt"
   printf '{"cwd":"%s","tool_input":{"command":"git add ok.txt && git commit -m x"}}' "$d" | .claude/hooks/no-secret-commit.sh; echo "exit=$?"
   # → 何も出ずに exit=0 なら正しい
   ```

## 依存

- `python3` と `git`（フックが使う）。`python3` が無い環境では、フックはコミットと push を止める
- GitHub Actions（CI が使う）
- Claude Code の hooks が有効
