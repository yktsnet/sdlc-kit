#!/usr/bin/env bash
# sdlc-kit — 選んだ単位を取り込み先のリポジトリへコピーする。
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP=".sdlc-kit"
BASE=(doc-style guards)
FLOWS=(flow-issue flow-single)
EXTRAS=(phase-mvp phase-guarantee)

usage() {
  cat <<'USAGE'
usage:
  install.sh <取り込み先> [<作業フロー>] [<追加単位>...]
  install.sh --diff <取り込み先>

作業フロー（どちらか1つ。省略可）
  issue       着手前の合意を issues/ の Issue ファイルに残す。三役の分業つき
  single      着手前の合意を PR 本文に残す。担当が実質1人ならこちら

追加単位
  mvp         PLAN.md / JUDGE.md。立ち上がり期の駆動文書
  guarantee   docs/guarantees.md。リリース後の駆動文書

doc-style と guards はどれを選んでも必ず入る。

例:
  ./install.sh ~/repos/myrepo single
  ./install.sh ~/repos/myrepo issue mvp guarantee
  ./install.sh --diff ~/repos/myrepo
USAGE
}

resolve() {
  case "$1" in
    issue|flow-issue)           echo flow-issue ;;
    single|flow-single)         echo flow-single ;;
    mvp|phase-mvp)              echo phase-mvp ;;
    guarantee|phase-guarantee)  echo phase-guarantee ;;
    doc-style|guards)           echo "$1" ;;
    *)                          return 1 ;;
  esac
}

die() { echo "error: $*" >&2; exit 1; }

# --- diff モード: 取り込み先の記録と、配布元のその後の変更を突き合わせる ---
if [ "${1:-}" = "--diff" ]; then
  dest="${2:-}"
  [ -n "$dest" ] || { usage; exit 1; }
  [ -f "$dest/$STAMP" ] || die "$dest に $STAMP が無い。まだ取り込んでいない。"
  echo "--- $dest/$STAMP ---"
  cat "$dest/$STAMP"
  rev=$(grep '^commit:' "$dest/$STAMP" | cut -d' ' -f2 || true)
  units=$(grep '^units:' "$dest/$STAMP" | cut -d' ' -f2- || true)
  [ -n "$rev" ] || die "$STAMP に commit の記録が無い。"
  echo
  echo "--- 配布元の $rev 以降の変更（取り込んだ単位のみ） ---"
  paths=""
  for u in $units; do paths="$paths units/$u"; done
  git -C "$SRC" log --oneline "$rev"..HEAD -- $paths || true
  echo
  echo "取り込み済みのコピーは自動では更新しない。必要な差分だけ手で当てること。"
  exit 0
fi

[ $# -ge 1 ] || { usage; exit 1; }
case "$1" in -h|--help) usage; exit 0 ;; esac

dest="$1"; shift
[ -d "$dest" ] || die "$dest が無い。"
dest="$(cd "$dest" && pwd)"
[ "$dest" != "$SRC" ] || die "配布元に自分自身を取り込むことはできない。"

# --- 単位の決定 ---
selected=("${BASE[@]}")
flow=""
for arg in "$@"; do
  u=$(resolve "$arg") || die "不明な単位: $arg（--help を見ること）"
  for f in "${FLOWS[@]}"; do
    if [ "$u" = "$f" ]; then
      [ -z "$flow" ] || die "作業フローは1つだけ選ぶ（$flow と $u を同居させない）。"
      flow="$u"
    fi
  done
  selected+=("$u")
done
# 重複を落とす
uniq_units=()
for u in "${selected[@]}"; do
  seen=0
  for v in "${uniq_units[@]:-}"; do [ "$v" = "$u" ] && seen=1; done
  [ $seen -eq 0 ] && uniq_units+=("$u")
done

# --- git の状態を確かめる ---
if git -C "$dest" rev-parse --git-dir >/dev/null 2>&1; then
  if [ -n "$(git -C "$dest" status --porcelain)" ]; then
    echo "警告: $dest のワーキングツリーがクリーンでない。" >&2
    printf "続けるか [y/N]: " >&2; read -r ans
    case "$ans" in y|Y) ;; *) exit 1 ;; esac
  fi
else
  echo "注意: $dest は git リポジトリではない。取り消しが効かない。" >&2
fi

# --- コピー（既存ファイルは差分を見せて確認する） ---
copied=0
for u in "${uniq_units[@]}"; do
  [ -d "$SRC/units/$u" ] || die "単位が見つからない: $u"
  while IFS= read -r rel; do
    src="$SRC/units/$u/$rel"
    dst="$dest/$rel"
    if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
      echo "--- 既存と異なる: $rel"
      diff -u "$dst" "$src" || true
      printf "上書きするか [y/N]: " >&2; read -r ans
      case "$ans" in y|Y) ;; *) echo "  skip: $rel"; continue ;; esac
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    copied=$((copied + 1))
  done < <(cd "$SRC/units/$u" && find . -type f | sed 's|^\./||')
done

# --- 取り込みの記録を残す ---
rev=$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)
cat > "$dest/$STAMP" <<STAMPEOF
# sdlc-kit から取り込んだ記録。配布元の変更を見るには install.sh --diff を使う。
units: ${uniq_units[*]}
commit: $rev
date: $(date +%Y-%m-%d)
STAMPEOF

echo
echo "取り込んだ単位: ${uniq_units[*]}（$copied ファイル）"
echo
echo "次にやること:"
echo "  1. .claude/settings.snippet.json を .claude/settings.json へマージし、snippet を消す"
echo "  2. 穴を埋める: grep -rn '<[^>]*>' .claude/skills docs/ops"
echo "  3. 次の文書を読む（取り込んだあとにやること、がそれぞれに書いてある）"
for u in "${uniq_units[@]}"; do
  (cd "$SRC/units/$u" && find . -path "./docs/ops/*" -type f | sed 's|^\./|    |')
done
