# Phase 5 playtest matrix: v3 (Phase 5 final) vs v4 (visual pass)

The same 27 runs (`tools/expanded/playtest_bot.gd`, seeds 1–3, `--scale=3`) on the final v4 build, same machine. One line per run: the v3 result, then whether v4 matched.

| # | v3 result | v4 |
|---|---|---|
| 1 | route=main profile=careful explore=false seed=1: completed in 1:40, captures 0, noticed 2, investigated 0, chased 0, waited 9 s, forced 0, state checks 0, violations 0 | identical |
| 2 | route=main profile=careful explore=false seed=2: completed in 1:41, captures 0, noticed 1, investigated 0, chased 0, waited 5 s, forced 0, state checks 0, violations 0 | identical |
| 3 | route=main profile=careful explore=false seed=3: completed in 1:40, captures 0, noticed 1, investigated 0, chased 0, waited 8 s, forced 0, state checks 0, violations 0 | identical |
| 4 | route=stacks profile=careful explore=false seed=1: completed in 2:56, captures 0, noticed 12, investigated 9, chased 0, waited 32 s, forced 0, state checks 0, violations 0 | **route=stacks profile=careful explore=false seed=1: completed in 2:57, captures 0, noticed 12, investigated 9, chased 0, waited 32 s, forced 0, state checks 0, violations 0** |
| 5 | route=stacks profile=careful explore=false seed=2: completed in 2:09, captures 0, noticed 8, investigated 2, chased 0, waited 9 s, forced 0, state checks 0, violations 0 | identical |
| 6 | route=stacks profile=careful explore=false seed=3: completed in 2:55, captures 0, noticed 10, investigated 7, chased 0, waited 26 s, forced 0, state checks 0, violations 0 | identical |
| 7 | route=early_gate profile=careful explore=false seed=1: completed in 1:41, captures 0, noticed 2, investigated 0, chased 0, waited 9 s, forced 0, state checks 0, violations 0 | identical |
| 8 | route=early_gate profile=careful explore=false seed=2: completed in 2:21, captures 1, noticed 3, investigated 1, chased 1, waited 6 s, forced 0, state checks 1, violations 0 | identical |
| 9 | route=early_gate profile=careful explore=false seed=3: completed in 1:41, captures 0, noticed 1, investigated 0, chased 0, waited 8 s, forced 0, state checks 0, violations 0 | identical |
| 10 | route=main profile=careful explore=true seed=1: completed in 2:24, captures 1, noticed 6, investigated 2, chased 0, waited 15 s, forced 0, state checks 1, violations 0 | identical |
| 11 | route=main profile=careful explore=true seed=2: completed in 2:29, captures 1, noticed 8, investigated 4, chased 0, waited 13 s, forced 0, state checks 1, violations 0 | identical |
| 12 | route=main profile=careful explore=true seed=3: completed in 2:24, captures 1, noticed 5, investigated 2, chased 0, waited 14 s, forced 0, state checks 1, violations 0 | identical |
| 13 | route=stacks profile=careful explore=true seed=1: completed in 2:45, captures 0, noticed 11, investigated 5, chased 0, waited 30 s, forced 0, state checks 0, violations 0 | identical |
| 14 | route=stacks profile=careful explore=true seed=2: completed in 2:45, captures 0, noticed 13, investigated 2, chased 0, waited 25 s, forced 0, state checks 0, violations 0 | identical |
| 15 | route=stacks profile=careful explore=true seed=3: completed in 2:45, captures 0, noticed 9, investigated 4, chased 0, waited 22 s, forced 0, state checks 0, violations 0 | identical |
| 16 | route=early_gate profile=careful explore=true seed=1: completed in 1:57, captures 0, noticed 6, investigated 0, chased 0, waited 15 s, forced 0, state checks 0, violations 0 | identical |
| 17 | route=early_gate profile=careful explore=true seed=2: completed in 2:02, captures 0, noticed 1, investigated 0, chased 0, waited 7 s, forced 0, state checks 0, violations 0 | identical |
| 18 | route=early_gate profile=careful explore=true seed=3: completed in 1:57, captures 0, noticed 4, investigated 1, chased 0, waited 12 s, forced 0, state checks 0, violations 0 | identical |
| 19 | route=main profile=learner explore=true seed=1: completed in 2:51, captures 2, noticed 15, investigated 6, chased 2, waited 18 s, forced 0, state checks 2, violations 0 | **route=main profile=learner explore=true seed=1: completed in 2:50, captures 2, noticed 14, investigated 6, chased 2, waited 21 s, forced 0, state checks 2, violations 0** |
| 20 | route=main profile=learner explore=true seed=2: completed in 3:10, captures 2, noticed 14, investigated 7, chased 2, waited 18 s, forced 0, state checks 2, violations 0 | identical |
| 21 | route=main profile=learner explore=true seed=3: completed in 2:56, captures 2, noticed 14, investigated 10, chased 1, waited 19 s, forced 0, state checks 2, violations 0 | identical |
| 22 | route=stacks profile=learner explore=true seed=1: completed in 3:35, captures 2, noticed 20, investigated 7, chased 2, waited 35 s, forced 0, state checks 2, violations 0 | identical |
| 23 | route=stacks profile=learner explore=true seed=2: completed in 4:13, captures 3, noticed 20, investigated 11, chased 3, waited 27 s, forced 0, state checks 3, violations 0 | identical |
| 24 | route=stacks profile=learner explore=true seed=3: completed in 3:43, captures 2, noticed 25, investigated 19, chased 1, waited 28 s, forced 0, state checks 2, violations 0 | identical |
| 25 | route=main profile=reckless explore=true seed=1: NOT completed in 8:39, captures 30, noticed 59, investigated 28, chased 30, waited 0 s, forced 0, state checks 30, violations 0, STALLED | identical |
| 26 | route=main profile=reckless explore=true seed=2: NOT completed in 9:10, captures 30, noticed 60, investigated 30, chased 30, waited 0 s, forced 0, state checks 30, violations 0, STALLED | identical |
| 27 | route=main profile=reckless explore=true seed=3: NOT completed in 8:42, captures 30, noticed 60, investigated 29, chased 29, waited 0 s, forced 0, state checks 30, violations 0, STALLED | identical |

**25 of 27 identical.** The two differences are one-off run-to-run variations of the playtester, not changes from the visual pass. Each case was re-run twice on each build:

| Case | v3, re-run 1 | v3, re-run 2 | v4, re-run 1 | v4, re-run 2 |
|---|---|---|---|---|
| 4 (stacks, careful, seed 1) | 2:56, 0 captures, noticed 12, waited 32 s | 2:56, 0 captures, noticed 12, waited 32 s | 2:56, 0 captures, noticed 12, waited 32 s | 2:56, 0 captures, noticed 12, waited 32 s |
| 19 (main, learner, explore, seed 1) | 2:50, 2 captures, noticed 14, waited 21 s | 2:50, 2 captures, noticed 14, waited 21 s | 2:50, 2 captures, noticed 14, waited 21 s | 2:50, 2 captures, noticed 14, waited 21 s |

Run 4: v4 took 1 s longer once (2:57); every re-run of both builds gives 2:56 (the v3 baseline). Run 19: the v3 baseline line (2:51, noticed 15, waited 18 s) was itself the odd one; every re-run of both builds gives 2:50, noticed 14, waited 21 s.

An earlier v4 build (before the final batching and shadow changes; same colliders) gave 26 of 27 identical, differing only in run 19 the same way.
