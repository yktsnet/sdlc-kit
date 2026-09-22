#!/usr/bin/env bash
# PreToolUse hook (Bash): 実行者が自分の変更を自分で公開に載せる経路を塞ぐ。
#   - main / master への push
#   - PR のマージ（gh pr merge）
#   - 保護ブランチへの force push
# 拒否と同時に正しい経路（レビューへ渡す・user がマージする）を返す。
set -u

input=$(cat)

json_get() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1 // \"\""
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for k in sys.argv[1].split("."):
    if not k: continue
    d = d.get(k, "") if isinstance(d, dict) else ""
print(d if isinstance(d, str) else "")
' "${1#.}"
  else
    # jq も python3 も無い環境では遮断できない。素通りさせず止める。
    printf 'NO_PARSER'
  fi
}

cmd=$(json_get '.tool_input.command')

if [ "$cmd" = "NO_PARSER" ]; then
  echo "no-push-to-main.sh: jq または python3 が必要です。導入するまで push 系コマンドは通しません。" >&2
  exit 2
fi

[ -n "$cmd" ] || exit 0

deny() {
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"$1"}}
EOF
  exit 0
}

# git push で main / master を直接指す、または現在ブランチが main のまま push する
if printf '%s' "$cmd" | grep -Eq '(^|[;&|]|&&)[[:space:]]*(sudo[[:space:]]+)?git[[:space:]]+([^;&|]*[[:space:]])?push'; then
  if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]:])(main|master)([[:space:]]|$)'; then
    deny "main / master への直接 push は行わない。変更は作業ブランチに置き、PR を通して user がマージする。すでに main 上で作業してしまった場合は、作業ブランチを切り直してからやり直すこと。"
  fi
  if printf '%s' "$cmd" | grep -Eq '(--force([^-]|$)|-f([[:space:]]|$)|--force-with-lease)'; then
    deny "force push は行わない。履歴を書き換えたい場合は理由を添えて user に依頼すること。"
  fi
  current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  case "$current" in
    main|master)
      deny "現在のブランチが ${current} である。main / master から push しない。作業ブランチを切り、PR を通して user がマージする。"
      ;;
  esac
fi

# PR のマージは user が押す
if printf '%s' "$cmd" | grep -Eq '(^|[;&|]|&&)[[:space:]]*gh[[:space:]]+pr[[:space:]]+merge'; then
  deny "PR のマージは user が行う。実装者はレビューへ渡すところまでで止まること（引き渡し手順は docs/ops/workflow.md）。"
fi

exit 0
