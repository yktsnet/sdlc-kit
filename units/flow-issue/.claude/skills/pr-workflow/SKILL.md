---
name: pr-workflow
description: Issueファイルに基づく実装からローカルコミットまでの標準フロー。push・PR作成はしない（user が行う）
disable-model-invocation: true
---

以下の手順で issue を実行する。`$ARGUMENTS` に issue ファイルのパスを渡す。

**前提: 実行者はコードを書いてローカルにコミットするまでが担当。push・PR 作成・マージ・実行確認は user が行う。リモート（origin / GitHub）には一切触れない。**

1. issue ファイルを読む
2. `git status` で、ブランチが `claude/{id}-{branch-slug}` かつワーキングツリーがクリーンなことを確認する（ブランチと worktree は起動時に作成済み）。違えば報告して止まる
3. 対象ファイルを読んで実装する
4. issue の「確認」項目と、リポ CLAUDE.md の「静的チェック / 検証手段」に従い提出前確認を行う。コードを読んで caller・import の整合性も確認する。実行系・デプロイ系コマンド（rebuild / deploy / 本番起動）は実行しない
5. issue の保証節が保証台帳 `docs/guarantees.md` の記載に影響する場合（新保証・変更・廃止）、テストと同じ PR 内で台帳（保証の文言と対応テストの表）を更新する。台帳の更新漏れは実装未完了として扱う
6. `git add {変更したファイル}` し、`git diff --name-only --cached` が issue の「対象」フィールドと完全に一致することを確認する（保証台帳を更新した場合はそれも対象に含まれていること）。一致しなければ実装に戻る
7. コミットする（保証台帳を更新した場合は同じコミットに含める）。メッセージ本文に報告を入れる（user はこの本文をそのまま PR 本文として使う）。一時ファイルは作らず、heredoc で標準入力から渡して1コマンドに収めること:
   ```
   git commit -F - <<'EOF'
   {type}: {タイトル}

   ## 変更内容
   {issue の内容フィールドを展開}

   ## 保証
   {issue の保証節の各項目 → それを固定したテスト（ファイル・テスト名）の対応。テストを伴わない場合は Issue と同じく `なし（理由）`}

   ## 静的確認結果
   {確認項目に対する結果。git diff --name-only --cached の出力を含める}

   ## 検証手順
   {実行者側で完結しない確認（実行・デプロイ・目視）を、リポ CLAUDE.md の検証手順の雛形に従って記載。なければ省略}
   EOF
   ```
8. push・PR 作成はせずに終了する。以下を出力する:
   ```
   ✅ Committed on {branch}: {type}: {タイトル}
   Review: git diff main...{branch}
   Next: user が push・PR 作成・マージ
   ```
