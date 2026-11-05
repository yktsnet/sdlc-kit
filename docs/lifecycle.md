# 2つの駆動文書

開発文書には寿命がある。単一の仕様書を永続させようとせず、フェーズごとに駆動文書を
交代させる。

**駆動文書**とは、その時期の開発を進行させ、更新され続ける文書のこと。リポが今どちらの
フェーズにあるかは user が決め、`CLAUDE.md` に書く。
フェーズは作業フロー（[task-flows.md](task-flows.md)）とは別の軸で、どのフローとも組める。
チームでも立ち上がり期はあり、1人でも保証台帳は使える。

| フェーズ | 駆動文書 | 答える問い | 配布物 |
|---|---|---|---|
| MVP 期 | `PLAN.md` / `JUDGE.md` | 何を作れば完成か。なぜその実装か | `units/phase-mvp/` |
| 保証台帳期 | `docs/guarantees.md` | 何を約束し、何を約束していないか | `units/phase-guarantee/` |

MVP 期の2文書を足場として畳む理由と、MVP 期から保証台帳期へ移る交代点は
[phase-mvp.md](../units/phase-mvp/docs/ops/phase-mvp.md)、README の代わりに台帳を置く理由は
[phase-guarantee.md](../units/phase-guarantee/docs/ops/phase-guarantee.md) にある。

## どこから入るか

既存リポに後から敷くなら、`phase-guarantee` だけを入れて構わない。立ち上げ済みのリポに
`PLAN.md` を書いても、書いた時点で足場としての役目が無い。

新規リポは `phase-mvp` から始め、リリースの段で `phase-guarantee` を足す。
