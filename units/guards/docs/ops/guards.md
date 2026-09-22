# ガード

実行者が自分の変更を自分で公開に載せられない状態を作る。

## なぜ文書ではなく機構に置くか

文書に書いた禁止は守られない。読み手は疲れるし、エージェントは長い指示を読み飛ばす。
同じ内容でも、`CLAUDE.md` に書くのと `settings.json` の deny に置くのとでは、守られる
確率の桁が違う。

そのうえで、壁を立てるだけなら deny で足りる。フックの利得は、拒否と同時に正しい経路へ
寄せられる点にある。エージェントは拒否されると別の手を試すので、何を試すかを拒否文で
指定できる。**遮断は否定ではなく分岐器である。**

## 入るもの

```text
.claude/hooks/no-push-to-main.sh   main への push・force push・gh pr merge を拒否する
.claude/settings.guards.snippet.json   上記フックの登録と、前方一致で足りる deny
```

deny は文字列で判定できるものを受け持ち、フックは行為で判定するものを受け持つ。
`git push` が main を指しているかは、現在のブランチを見ないと決まらない。宣言的な deny
では届かないので、コマンドを解釈するフックが要る。

## 取り込んだあとにやること

1. `.claude/settings.*.snippet.json` をすべて `.claude/settings.json` へマージし、snippet を消す
2. `chmod +x .claude/hooks/no-push-to-main.sh`
3. 動作を確かめる

   ```bash
   printf '{"tool_input":{"command":"git push origin main"}}' | .claude/hooks/no-push-to-main.sh
   ```

   `"permissionDecision":"deny"` を含む JSON が返れば効いている。

4. `CLAUDE.md` に禁止事項を書かない。書いてあるなら消す（deny とフックに移す）

## このリポで足すもの

このリポ固有の破壊的コマンドを deny に足す。例: デプロイ、本番への接続、生成物への直接編集。

| 遮断したいもの | 置き場 |
|---|---|
| `<コマンド名>` | `<deny / フック>` |

## 依存

`no-push-to-main.sh` は jq を使い、無ければ python3 にフォールバックする。どちらも無い環境
では判定できないため、push 系を一律で止める。どちらかを入れておくこと。
