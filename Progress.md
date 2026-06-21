# Decompiler correctness fixes — Progress

Branch `fix/decompiler-correctness` (off `main` @ `2160037`). Goal: fix every
confirmed semantic-correctness bug in `CODE_REVIEW_REPORT.md` / `FINDINGS.md`
(C1–C13) plus the lifter-hardening findings (L1–L6), each verified against the
differential harness (`source → luau-compile → luau-lifter → luau.exe`, diff
stdout) and the 275-file v9 corpus (byte-diff + 100% parse).

Process per bug (per CLAUDE.md): deep research + adversarial verification via
parallel Opus subagents (a 21-agent Workflow over the remaining cluster), then I
personally re-verify every finding against the real code before implementing,
rebuild, run the per-bug repro + the full 863-program differential harness +
the corpus byte-diff, and only commit when clean. **Every subagent finding was
verified, not trusted** — two researched fixes (C6, C13) were found to regress /
be unsound and were NOT shipped as proposed.

## Fixed and shipped

| Bug | One-line | Where | Validation |
|---|---|---|---|
| C1 | `not (a<b)` no longer rewritten to NaN-unsound `a>=b` | `ast/unary.rs` | repro + corpus (faithful `not(<)` / preserved guards) |
| C2 | mixed keyed+positional table keeps explicit keys | `ast/formatter.rs` | repro `a b 2` |
| C2b | non-integral/out-of-range numeric keys not dropped (no `usize` cast) | `ast/formatter.rs` | repro `zero nil 0` |
| C3 | loop-carried parallel copy: pre-spill destination-reading RHS | `cfg/ssa/destruct.rs` | repro Fibonacci; corpus byte-identical |
| C4 | remove a by-ref upvalue cell's trivial loop phi (SCOPED to cells) | `cfg/ssa/construct.rs` | repro `state` 15; harness 28→11; AuraUI intact |
| C5 | wrap a trailing multret `Select` in `(…)` in return position | `ast/formatter.rs` | repro; faithful `return (call())` |
| C6 | materialize a loop-mutated by-value capture as a per-iteration snapshot | `ast/materialize_value_captures.rs` (NEW) | repro 1,2,3; harness 11→5; AuraUI intact |
| C7 | don't collapse a return-diamond whose arm is a multret tail | `cfg/ssa/structuring.rs` | repro tcount 3 |
| C8 | `for…do break end` no longer drops the whole function | `restructure/loop.rs`, `luau-lifter/lifter.rs` | repro O0/O1/O2 |
| C9 | inliner closes the side-effect window on a group-write skip | `cfg/ssa/inline.rs` | repro order A,B7; corpus byte-identical |
| C10 | window-aware: keep a captured snapshot only across an intervening call | `ast/inline_temps.rs`, `ast/copy_cleanup.rs` | repro `1`; +1 regression test |
| C11 | keep an effect-free condition/binding that can RAISE | `ast/side_effects.rs`, `cfg/ssa/structuring.rs`, `restructure/jump.rs`, `cfg/ssa/inline.rs` | repro `false` |
| C12 | keep a middle loop's break in deeply-nested multi-break loops | `restructure/loop.rs` | repro count 18; corpus byte-identical |
| L1 | LOADB C>1 wires the correct (unsigned I+1+C) CFG edge, no panic | `luau-lifter/lifter.rs` | corpus byte-identical |
| L2 | LOADKX lifts (was `unreachable!` aborting the proto) | `luau-lifter/lifter.rs` | corpus byte-identical |
| L3 | CMPPROTO preserves its `d` jump edge (two-way conditional when D≠0) | `luau-lifter/lifter.rs` | corpus byte-identical; 13/13 repro |
| L4 | non-JUMPX E-form op degrades to a comment, not a panic | `luau-lifter/lifter.rs` | corpus byte-identical |
| L5 | NATIVECALL decoded as ABC (was AD, scrambling A/B/C) | `luau-lifter/instruction.rs`, `lifter.rs` | corpus byte-identical |
| L6 | string constant index 0 decodes to "" instead of underflow panic | `luau-lifter/lifter.rs` | corpus byte-identical |

The whole-program differential harness went from **63 → 5 mismatches** with
**0 decompile failures**; the v9 corpus stays **275/275 parseable**. The 5
residual mismatches are gen2 adversarial stress-tests (coro upvalues, shared-upval-
two-loops, contrived nested-break, keyed/multret-in-constructor, call-as-table-key)
— NONE is one of the documented C/L findings.

## Cluster notes — C4/C6 fixed at the root, C13 verified a non-bug

C4 and C6 each took several attempts (documented below); C13 was investigated to a
bytecode-level proof that it is a misdiagnosis. Every subagent finding was verified,
not trusted.

- **C4** — NOW FIXED (see table above). The winning approach: keep the
  self-back-edge exclusion in `remove_unnecessary_params` but SCOPE it to upvalue-
  cell loop phis only (detected by an incoming arg being a grouped cell version),
  so the non-upvalue loop phis the restructurer needs are untouched and AuraUI
  stays valid. Two earlier approaches regressed first: unscoped phi removal (AuraUI
  207 gotos) and relaxing the `coalesce_copies` same-group guard (49 mismatches +
  6 crashes — same-group cell versions can interfere).

- **C6** — NOW FIXED (see table above). After FOUR SSA-level attempts all regressed
  (register conflation / AuraUI-invalid / clobbering out-of-SSA write-backs), the
  winning approach abandons SSA coalescing-avoidance entirely and fixes it at the
  AST level: `materialize_value_captures` re-introduces the lost per-iteration
  snapshot (`local snap = L; closure reads snap`) for a `Copy` capture of a
  loop-mutated local. A value capture IS a snapshot, so it is exact; loop-scoped so
  stable upvalues are untouched; and `snap` is itself captured so inline/cleanup
  leave it. Harness 11→5, DECFAIL=0, closures-upval eliminated, AuraUI intact.

- **C13** — VERIFIED A MISDIAGNOSIS at the bytecode level (not a decompiler bug).
  Lifter instrumentation correlating each `:Connect` result register with closure
  ref-captured registers shows HangingPlacement (the sole instance) has **0
  collisions** — the connection result is in a register no closure captures, so it
  is NOT `v22`. The dead `local _` proves no hidden `v22 = result` move; the
  connection is genuinely discarded in the obfuscated original (a real leak there,
  faithfully reproduced). Corpus-wide: exactly ONE `local _ = …:Connect` (this one),
  while all 138 cases where a connection IS in a captured register decompile
  correctly to `cell = …:Connect`. Both facets (a closure-capture, b self-update
  `x=x+1` / guarded default) also tested and decompile correctly. The review's
  "should be `v22 = …`" was an inference the bytecode disproves.

- **L3 (CMPPROTO), L5 (NATIVECALL)** — NOW FIXED (see table). Both are runtime-only
  JIT pseudo-ops never present in serialized v9 bytecode, so the fixes are correct
  hardening with the 275-file corpus BYTE-IDENTICAL: L5 decodes ordinal 62 as the
  ABC-form call it is (was AD, scrambling A/B/C) and lifts it as a FASTCALL-style
  no-op; L3 emits a genuine two-way conditional preserving the `d` edge when D≠0
  (D==0 keeps the exact fall-through). **set_list multret tail** (#21) is "plausible,
  NO trigger constructed" — not a confirmed finding; the common multret-tail-in-
  constructor case was tested and decompiles correctly (`{1,2,multi()}` → 5 values).
