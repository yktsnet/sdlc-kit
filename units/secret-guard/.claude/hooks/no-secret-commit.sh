#!/usr/bin/env bash
# PreToolUse hook (Bash): Claude が秘密情報をコミット・push するのを止める。
# 何を探し、なぜ git と python3 だけで動かすかは docs/ops/secret-guard.md にある。
set -u

input=$(cat)

if ! command -v python3 >/dev/null 2>&1; then
  # 判定できないまま素通りさせると防壁の意味が無くなるので、commit と push だけを止める
  case "$input" in
    *"git commit"*|*"git push"*|*"git -C"*)
      printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"no-secret-commit.sh: python3 が必要です。導入するまで commit と push は通しません。"}}'
      ;;
  esac
  exit 0
fi

deny() {
  python3 -c 'import json, sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": sys.argv[1]}}, ensure_ascii=False))' "$1"
  exit 0
}

verdict=$(printf '%s' "$input" | python3 -c '
import json, os, re, subprocess, sys
d = json.load(sys.stdin)
cmd = d.get("tool_input", {}).get("command", "")
cwd = d.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or "."

# heredoc の本文はコマンドではなくデータなので外す。コミットメッセージに git push と書いただけで走らせないため
lines, delim, strip = [], None, False
for line in cmd.split("\n"):
    if delim is not None:
        if (line.lstrip("\t") if strip else line) == delim:
            delim = None
        continue
    lines.append(line)
    for m in re.finditer(r"(?<!<)<<(-?)[ \t]*[\"\x27]?([A-Za-z_][A-Za-z0-9_]*)[\"\x27]?", line):
        strip, delim = m.group(1) == "-", m.group(2)

head = r"^[({\s]*(\w+=\S*\s+)*git(\s+-C\s+(\S+))?\s+"
commit, push, add = (re.compile(head + v + r"(\s|$)") for v in ("commit", "push", "add"))
segs = re.split(r"&&|\|\||[;|\n]", "\n".join(lines))
targets = []
for s in segs:
    for kind, rx in (("commit", commit), ("push", push)):
        m = rx.match(s)
        if m:
            targets.append((kind, os.path.join(cwd, m.group(3)) if m.group(3) else cwd))
if not targets:
    sys.exit(0)
# 同じコマンドの中で git add してからコミットする形では、フックの時点ではまだステージされていない。
# そのときだけ、追跡していないファイルもコミットされうるものとして見る
adds = any(add.match(s) for s in segs)

def git(where, *args):
    r = subprocess.run(["git", "-C", where, *args], capture_output=True)
    return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else None

# .env.example などは、値を入れずに鍵の名前だけを見せるためにコミットするものなので止めない
bad_name = re.compile(r"(^|/)(\.env(\.(?!example$|sample$|template$)[^/]+)?|id_(rsa|dsa|ecdsa|ed25519)|[^/]+\.(pem|key|p12|pfx|jks|keystore))$")
rules = [
    ("秘密鍵", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("AWS のアクセスキー", re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("GitHub のトークン", re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})")),
    ("Slack のトークン", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}")),
    ("Google の API キー", re.compile(r"\bAIza[0-9A-Za-z_-]{35}")),
    ("API キー（sk-）", re.compile(r"\bsk-(ant-|proj-)?[A-Za-z0-9_-]{32,}")),
    ("Stripe のキー", re.compile(r"\b[sr]k_live_[0-9A-Za-z]{24,}")),
    # 値を直書きした代入だけを拾う。${...}・<...>・環境変数からの読み出しは値ではないので外す
    ("パスワード・トークンの直書き", re.compile(r"(?i)(password|passwd|secret|api[_-]?key|access[_-]?key|auth[_-]?token)[\"\x27]?\s*[:=]\s*[\"\x27][^\"\x27\s$<{]{8,}[\"\x27]")),
]

found = []
def scan_text(path, lineno, text):
    if "gitleaks:allow" in text:
        return
    for name, rx in rules:
        if rx.search(text):
            found.append(f"{path}:{lineno} {name}")

def scan_patch(patch):
    path, n = None, 0
    for line in patch.split("\n"):
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("@@"):
            m = re.search(r"\+(\d+)", line)
            n = int(m.group(1)) if m else 0
        elif path and line.startswith("+"):
            scan_text(path, n, line[1:])
            n += 1
        elif path and not line.startswith("-"):
            n += 1

for kind, where in dict.fromkeys(targets):
    if git(where, "rev-parse", "--git-dir") is None:
        continue
    names = []
    if kind == "commit":
        has_head = git(where, "rev-parse", "--verify", "-q", "HEAD") is not None
        if has_head:
            scan_patch(git(where, "diff", "--no-color", "--no-ext-diff", "HEAD") or "")
            names += (git(where, "diff", "--name-only", "--diff-filter=AMR", "HEAD") or "").split("\n")
        else:
            scan_patch(git(where, "diff", "--no-color", "--no-ext-diff", "--cached") or "")
            names += (git(where, "diff", "--name-only", "--cached") or "").split("\n")
        if adds:
            root = git(where, "rev-parse", "--show-toplevel").strip()
            for f in (git(where, "ls-files", "--others", "--exclude-standard", "--full-name") or "").split("\n"):
                if not f:
                    continue
                names.append(f)
                p = os.path.join(root, f)
                try:
                    if os.path.getsize(p) > 1_000_000:
                        continue
                    data = open(p, "rb").read()
                except OSError:
                    continue
                if b"\0" in data:
                    continue
                for i, t in enumerate(data.decode("utf-8", "replace").split("\n"), 1):
                    scan_text(f, i, t)
    else:
        # どのブランチを送るかは引数の形がさまざまなので、まだリモートに無いコミットをすべて見る
        scan_patch(git(where, "log", "-p", "--no-color", "--no-ext-diff", "--format=", "--branches", "--not", "--remotes") or "")
        names += (git(where, "log", "--name-only", "--diff-filter=AMR", "--format=", "--branches", "--not", "--remotes") or "").split("\n")
    for f in dict.fromkeys(names):
        if f and bad_name.search(f):
            found.append(f"{f} 秘密を置くファイル名")

if found:
    print("D")
    for f in list(dict.fromkeys(found))[:20]:
        print(f"  {f}")
' 2>/dev/null)
status=$?

# 読めなかったときは通さない。判定できないまま素通りさせると防壁の意味が無くなる。
if [ $status -ne 0 ]; then
  case "$input" in
    *"git commit"*|*"git push"*|*"git -C"*) deny "フックが入力を解釈できなかった。秘密情報が含まれていないか判定できないため通さない。" ;;
    *) exit 0 ;;
  esac
fi
[ -z "$verdict" ] && exit 0

deny "秘密情報らしいものが、コミットか push の対象に含まれている。値は表示しない。
${verdict#D
}
秘密なら、ファイルを .gitignore に入れるか、値を環境変数へ移す。すでに使った値なら無効にして作り直す。
誤検知なら、その行に gitleaks:allow と書き添えるか、人が判断してコミットする（docs/ops/secret-guard.md）。"
