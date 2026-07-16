# `raster_walker` — Functional Specification

## 1. Overview

`raster_walker` traces raster lines. For extents `(dx, dy)` with `dy <= dx`
it produces, one at a time over a stalling handshake, the `dx` unit steps of
the closest-lattice-point walk from `(0, 0)` to `(dx, dy)`. Single clock
domain; synchronous, active-high reset.

## 2. Interface

| Port         | Dir | Type            | Description |
|--------------|-----|-----------------|-------------|
| `clk`        | in  | `logic`         | Clock. All sequential behavior is defined at its rising edge. |
| `rst`        | in  | `logic`         | Synchronous reset, active-high. Takes priority over every other input at every rising edge. |
| `start`      | in  | `logic`         | Traversal request. A level, sampled at every rising edge; the module applies no edge detection to it. |
| `dx`         | in  | `logic [W-1:0]` | X-extent: the number of steps of the requested traversal. Sampled only at the accepting edge. |
| `dy`         | in  | `logic [W-1:0]` | Y-extent. Sampled only at the accepting edge. |
| `busy`       | out | `logic`         | 1 from the cycle after a traversal is accepted through the cycle in which its final step is accepted; 0 in the done cycle and while idle. |
| `done`       | out | `logic`         | 1 for exactly one cycle per completed traversal: the cycle after its final step is accepted (§5 defines the zero-length case). |
| `step_valid` | out | `logic`         | A step is offered. |
| `step_dir`   | out | `logic`         | Direction of the offered step: 0 = E `(x+1, y)`, 1 = NE `(x+1, y+1)`. In any cycle in which `step_valid` is 0 it holds its most recent value (0 after reset). |
| `step_ready` | in  | `logic`         | The consumer accepts the offered step. |

Parameter: `W` (`int`, ≥ 2, default 8) — width of `dx` and `dy`. The
deliverable testbench uses the default `W = 8`.

## 3. Cycles, sampling, and acceptance

A **cycle** is the interval between two consecutive rising clock edges; a
signal's value "in a cycle" is its stable value during that interval.
Inputs presented in a cycle are sampled at the rising edge that ends it.

Every output of the module is **registered**: the outputs visible in a cycle
are the outcome of the decision taken at the edge that began that cycle. No
output reacts combinationally to an input in the same cycle.

A **step is accepted** at a rising edge at which `step_valid = 1`,
`step_ready = 1`, and `rst = 0` all hold.

A **traversal is accepted** at a rising edge at which `rst = 0`, `busy = 0`,
`start = 1`, and `dy <= dx` all hold. §5 and §7 give the consequences.

## 4. The step sequence

For an accepted traversal `(dx, dy)`, define the walk's height at each
column as follows:

- `y_0 = 0`;
- for each `k` from 1 to `dx`, `y_k` is the integer closest to
  `k * dy / dx` — that is, the integer `y` minimizing `|dx*y − dy*k|`.
  If two integers are equally close, `y_k` is the **larger** of the two.

The module emits exactly `dx` steps, one per column: step `k`
(`k = 1 .. dx`) is **NE** if `y_k = y_(k−1) + 1` and **E** if
`y_k = y_(k−1)`. (No other case can arise, because `dy <= dx`.)

Consequences a conforming implementation exhibits, all derivable from the
definition: the walk ends at `(dx, dy)`; exactly `dy` of the `dx` steps are
NE; a traversal with `dy = 0` is all-E; a traversal with `dy = dx` is
all-NE.

## 5. Traversal control

- **Acceptance.** The acceptance condition of §3 is evaluated at every
  rising edge — including the edge that ends a done cycle, since `busy` is
  0 there. `dx` and `dy` are latched at the accepting edge and are not
  re-examined during the traversal.
- **Start while busy.** A `start` presented while `busy = 1` has no effect
  of any kind: nothing is latched, queued, or disturbed.
- **Illegal extents.** A request with `dy > dx` is not accepted: the module
  stays idle, produces no steps and no `done`, and a subsequent legal
  request behaves normally.
- **Zero-length traversal.** A request with `dx = 0` (hence `dy = 0`) **is**
  accepted. It produces no steps — `step_valid` does not rise at any point —
  and `done` is 1 in the cycle after the accepting edge. `busy` never rises
  for it.
- **Abutting completions.** Because acceptance is re-evaluated at the edge
  that ends a done cycle, back-to-back completions — for example repeated
  `dx = 0` requests with `start` held at 1 — make `done` 1 in consecutive
  cycles: one cycle per completed traversal, not necessarily an isolated
  pulse.

## 6. Stepping

For an accepted traversal with `dx >= 1`, with acceptance at edge `t0`:

- In cycle `t0+1`, `step_valid = 1` and `step_dir` carries step 1's
  direction. (In the acceptance cycle itself — the cycle ending at `t0` —
  `busy` and `step_valid` are still 0, per §3.)
- While an offered step is not yet accepted, the offer persists:
  `step_valid` stays 1 and `step_dir` is unchanged in every cycle up to and
  including the cycle ending at the accepting edge.
- When step `k < dx` is accepted, the very next cycle offers step `k+1`
  (`step_valid` remains 1; there is no gap cycle).
- The walk's position advances **only** when a step is accepted. Cycles in
  which `step_ready = 0` do not advance it.
- When step `dx` — the final step — is accepted, the next cycle is the
  **done cycle**: `done` is 1 in that cycle, and `step_valid` is 0 in that
  cycle (staying 0 until a subsequently accepted traversal offers its
  first step).

## 7. Reset

At any rising edge at which `rst = 1`, every other input is ignored: a
coincident `start` is not accepted, and a coincident
`step_valid && step_ready` does not count as an acceptance. From the next
cycle, `busy = 0`, `step_valid = 0`, `done = 0`, `step_dir = 0`, and all
internal state is cleared.

A traversal in flight when reset arrives is **abandoned**: no further steps
are offered and no `done` pulse is ever produced for it — including when
reset arrives at the edge at which its final step would have been accepted,
and including while an offered step is stalled (`step_valid = 1`,
`step_ready = 0`).

`start` is a level (§2): if it is held at 1 across a reset pulse, it is
evaluated afresh at the first edge with `rst = 0`, and is accepted then if
the §3 condition holds.

Before the first rising edge at which `rst = 1`, the outputs and internal
state are undefined: a verification environment must apply reset before
checking any output.

## 8. Timing example (control only)

Traversal `dx = 2, dy = 0`, starting from idle after reset, with a one-cycle
stall on the first step. The traversal is accepted at the edge ending
cycle 0; step 1 is accepted at the edge ending cycle 2; step 2 at the edge
ending cycle 3.

| cycle        | 0 | 1 | 2 | 3 | 4 | 5 |
|--------------|---|---|---|---|---|---|
| `start`      | 1 | 0 | 0 | 0 | 0 | 0 |
| `step_ready` | – | 0 | 1 | 1 | 1 | 1 |
| `busy`       | 0 | 1 | 1 | 1 | 0 | 0 |
| `step_valid` | 0 | 1 | 1 | 1 | 0 | 0 |
| `step_dir`   | 0 | E | E | E | E | E |
| `done`       | 0 | 0 | 0 | 0 | 1 | 0 |

(`step_dir` shows E in cycles 4–5 as the held value defined in §2.)

## 9. Conforming implementations

Implementations are synthesizable SystemVerilog, single clock domain, no
latches, compatible with Icarus Verilog (`-g2012`). A verification
environment may assume these properties.
