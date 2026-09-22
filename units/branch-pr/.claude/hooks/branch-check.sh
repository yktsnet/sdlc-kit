#!/usr/bin/env bash
# SessionStart hook: ブランチの状態を点検する。
# main へマージ済みのローカルブランチを消し、居残りと切り忘れを報告する。
# 消すのはローカルだけ。リモートは他の担当者の作業コピーにも効くので報告に留める。
set -u

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# ネットワークが無くても落とさない。origin/main が古いときは掃除を見送るだけ。
timeout 15 git fetch --prune --quiet origin >/dev/null 2>&1

current=$(git branch --show-current)
today=$(date +%Y-%m-%d)
lines=()

if git rev-parse --verify --quiet origin/main >/dev/null; then
  deleted=()
  while read -r b; do
    [ -n "$b" ] || continue
    [ "$b" = "main" ] && continue
    [ "$b" = "$current" ] && continue
    if git branch -d "$b" >/dev/null 2>&1; then
      deleted+=("$b")
    fi
  done < <(git branch --merged origin/main --format='%(refname:short)')
  [ ${#deleted[@]} -gt 0 ] && lines+=("マージ済みのローカルブランチを削除した: ${deleted[*]}")

  # 切ったばかりの今日のブランチは main と同一なので、居残りとは区別する。
  case "$current" in day/"$today"*) fresh=1 ;; *) fresh=0 ;; esac
  if [ "$current" != "main" ] && [ "$fresh" = 0 ] \
    && git merge-base --is-ancestor "$current" origin/main 2>/dev/null; then
    lines+=("いま居る $current は main にマージ済み。次の作業に入る前に main へ戻り、必要なら新しいブランチを切る。")
  fi

  # delete-merged-branch.yml の取りこぼし（マージ前に閉じた PR 等）だけが残る。
  if command -v gh >/dev/null 2>&1; then
    stale=()
    while read -r ref; do
      b=${ref#refs/remotes/origin/}
      case "$b" in main|HEAD|dependabot/*) continue ;; esac
      git merge-base --is-ancestor "$ref" origin/main 2>/dev/null || continue
      stale+=("$b")
    done < <(git for-each-ref --format='%(refname)' refs/remotes/origin)
    if [ ${#stale[@]} -gt 0 ]; then
      open_prs=$(timeout 15 gh pr list --state open --json headRefName --jq '.[].headRefName' 2>/dev/null)
      orphan=()
      for b in "${stale[@]}"; do
        printf '%s\n' "$open_prs" | grep -qxF "$b" || orphan+=("$b")
      done
      [ ${#orphan[@]} -gt 0 ] && lines+=("main に入ったまま残っているリモートブランチがある: ${orphan[*]}（git push origin --delete で消す。実行前に user へ確認する）")
    fi
  fi
fi

case "$current" in
  day/"$today"*) ;;
  day/*)
    lines+=("いま居る $current は今日（$today）のブランチではない。day ブランチは日をまたがない。今日の分は main から day/$today を切る。")
    ;;
  main)
    lines+=("いま居るのは main。完了条件を決めて進める変更なら作業ブランチを、その日の文書整備や細かい直しなら day/$today を切る。")
    ;;
esac

[ ${#lines[@]} -eq 0 ] && exit 0
printf 'ブランチ点検:\n'
printf -- '- %s\n' "${lines[@]}"
