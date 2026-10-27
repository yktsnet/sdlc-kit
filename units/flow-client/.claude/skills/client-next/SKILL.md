---
name: client-next
description: 依頼主から届いた答えを作業の Issue へ反映し、次に着手する Issue を選ぶ。依頼主に聞くことが出たときは問いの Issue を立てる。「次に何をやるか」「答えが来た」「依頼主に聞きたい」と言われたときに使う。実装はしない。
---

相談者として、依頼主の答えと作業の Issue を突き合わせる。**実装しない**。理由と決まりは `docs/ops/client.md` にある。

## 問いを立てる

依頼主に聞くことが出たら、`reference/question-template.md` に従って `gh issue create --label question` で起票する。仮に置いた案で作る Issue があれば、その `仮定` に問いの番号を書き足す。

## 答えを回収する

1. `gh issue list --label question --state closed --search "closed:>={前回}"` で、閉じた問いを並べる。前回が分からなければ user に聞く
2. 問いごとに、答えのコメントと、仮に置いた案を比べる
3. 仮に置いた案に掛かる作業の Issue（問いの本文に挙がった番号と、`仮定` で問いを指す Issue）を開く
   - 案と答えが合っていれば、その旨を作業の Issue にコメントする
   - 違っていれば、答えに合わせる新しい Issue を `issue-draft` で起票する。閉じた Issue を開き直さない。まだ着手していない Issue なら、本文を直して `draft` ラベルを付け直し、裁可を受け直す
4. 回収した問いと、それぞれの扱いを報告する

## 次に着手するものを選ぶ

1. `gh issue list --label question --state open` で、答え待ちの問いを並べる
2. `draft` が無く assignee も無い作業の Issue を並べ、開いた問いに掛かっていないものを先に、掛かっているものを後に置く
3. 掛かっているものにも着手してよい。そのときは、どの問いの答えでやり直しになりうるかを添える
4. 並べた結果を報告して止まる。着手は user が `flow-team` の手順で行う
