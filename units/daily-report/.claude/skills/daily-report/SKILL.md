---
name: daily-report
description: push 済みのコミットから、上司・ステークホルダー向けの日報を書き、docs/reports/<担当者>/ に残す。「日報を書いて」と言われたときに使う。
disable-model-invocation: true
---

# daily-report

その日に**リモートへ push した**成果を、上司とステークホルダーが読む1枚にまとめる。読み手は Issue も
PR も開かないので、この1枚で何が変わり、それで何が良くなるかが分かるようにする。実装の手順・詳細は書かない。

目的、担当者ごとに分ける理由、PR の本数の考え方は `docs/ops/daily-report.md` にある。

## 置き場

`docs/reports/<担当者>/YYYY-MM-DD.md`。`<担当者>` は書く直前に引く。この skill に名前を書き込まない。

```bash
git config user.email | cut -d@ -f1
```

空、または英数字とハイフン以外を含むなら、user に使う名前を聞く。

## 0. 未コミット・未 push を片付け、main を取り直す

```bash
git status --short
git log --branches --not --remotes=origin --format='%h %s'
```

どちらかに出たら、書き始める前に「コミット・push して日報に含めるか、今回は対象外にするか」を聞く。
勝手にコミットしない。含めるなら先に済ませる。

片付いたら main を取り直し、`day/<日付>`（slug 無し）へ切り替える。日報はここに書き、main では動かさない。

```bash
git switch main && git pull && git fetch --prune
git switch day/<日付> 2>/dev/null || git switch -c day/<日付>
```

## 1. 期間を決める

`docs/reports/<担当者>/` の最新ファイルの日付を起点にする。無ければ当日分だけ。他の担当者の
ディレクトリは見ない。

## 2. push 済みのコミットを集める

```bash
git log --remotes=origin --no-merges --since="<起点>" --author="$(git config user.email)" --format='%h %s'
git log --branches --not --remotes=origin --format='%h %s'   # 未 push
```

- main へのマージは条件にしない。ブランチのままでよい
- 未 push のものは載せず、「未 push のため対象外」として ID だけ残す
- `docs/reports/` だけを変えたコミットは除く

## 3. 成果の中身を引く

コミットを変更ファイルごと見て、成果の単位で数え上げる。Issue に紐づく作業も紐づかない作業も同じ重みで拾う。

### Issue 版（`flow-issue`）

ブランチ名 `claude/{id}-{slug}` から id を拾い、`issues/{id}_*.md` の保証節と「内容」を読む。

```bash
git log --remotes=origin --since="<起点>" --author="$(git config user.email)" \
  --format='%D' | grep -oE 'claude/[0-9]+[a-z]?' | sort -u
```

- Issue ファイルが `day/<日付>` に無ければ PR は未マージなので、その `claude/*` ブランチへ一時的に切り替えて読む
- `status: open` のまま残る Issue と裁可待ちの `status: draft` も拾い、何を待っているかを添えて「今後の対応」に並べる

### 単発版（`flow-single`）

コミットが属するブランチの PR の `## 完了条件` と `## 証拠` から中身を引く。マージ前の PR も拾う。

```bash
gh pr list --state all --search "updated:>=<起点>" --json number,title,headRefName,body,state
```

- `## 証拠` が空のままの PR は、日報を書く前に指摘し、`hand-off` で先に埋めるかを聞く
- PR が無いコミットは、着手前に宣言した完了条件から書く

## 4. PLAN.md / JUDGE.md があれば確認する

日報の本文に載るので、書く前に片付ける。扱いは `docs/ops/phase-mvp.md`。無いファイルは飛ばす。

- **PLAN.md**：完了した行があれば、行ごと消す変更を提示し、承認を得てから直す。PLAN に無い作業なら、
  行を足すか PLAN の外として扱うかを聞く
- **JUDGE.md**：期間内に、片方を捨てた判断があったかを見る。あれば候補として挙げ、何を採り何を捨てたか・
  決め手・見直す条件を user に聞き取って追記する。**理由を私が埋めない。**答えが出ないものは書かない

## 5. マージ待ちの PR を並べる

```bash
gh pr list --state open --json number,title,labels,body,mergeable,statusCheckRollup \
  --jq '.[] | "#\(.number) \(.title)\n\(.body | split("\n")[0])"'
```

依存のあるものを先に、無ければ番号順に並べる。CI が赤い PR と、引き渡しが済んでいない PR（Issue 版は
`## 検証手順` が未実施、単発版は `## 証拠` が空）は「今回は見送り」と明記する。その日にマージされた PR は
「本日の実施内容」に入るので、ここには残さない。

## 6. 書き出す

`reference/report-template.md` に従う。該当しない節は消す。

- 「本日の実施内容」は成果の単位で H3 を立て、末尾にリンクを1行置く。Issue があれば先頭に、続けて中心に
  なったファイルを並べる。PR へのリンクは置かない。変更したファイルを全件列挙しない
- 「気づき」には、その日の作業中に実際に見えたものだけを書く。対処が決まったものは「今後の対応」へ

## 7. 書いたものを確かめる

- リンク行がすべて実在するファイルを指しているか（下のコマンド）
- エンジニアでない読み手が読んで意味が取れるか。ファイル名やコマンド名が主語の項目、手段しか書いていない項目は書き直す
- 口語（「動いた」「積んだ」など）が混じっていないか
- `<そのリポで地の文に書かない値>` が入っていないか

```bash
grep -oE '\]\(\.\./\.\./\.\./[^)]+\)' docs/reports/<担当者>/YYYY-MM-DD.md \
  | sed -E 's/^\]\(\.\.\/\.\.\/\.\.\/(.*)\)$/\1/' \
  | python3 -c 'import sys,urllib.parse,os
for l in sys.stdin:
    p=urllib.parse.unquote(l.strip())
    print(("OK  " if os.path.exists(p) else "NG  ")+p)'
```

短くしすぎて何をやったか伝わらないなら、削りすぎている。削るのは詳細で、成果ではない。

## 8. コミットして止まる

```bash
git add -A docs/reports/<担当者>/
git add PLAN.md JUDGE.md 2>/dev/null
git commit -m "Write the day's report"
```

push も PR も、user の OK が出るまで行わない。変更したファイルを一覧で示して止まる（差分は貼らない）。

> `day/<日付>` にコミットしました。
>
> - `docs/reports/<担当者>/YYYY-MM-DD.md` — 日報
>
> 読んでください。OK であれば PR を出します。直したい点があればこの場で直します。

直しが返ってきたら同じブランチにコミットし直す。

## 9. OK が出たら PR を出す

```bash
git push -u origin day/<日付>
gh pr create --base main
```

既に PR があれば push だけで載る。
