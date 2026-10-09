# max_of_5 — Verification Test Plan

## 1. Scope

This plan lists everything that must be verified in `rtl/max_of_5.v` before the design is signed off. That covers normal operation, corner cases, illegal inputs, and checks that the testbench itself can find bugs.

Every test item has an ID, the stimulus, the expected result, how it is checked, a priority and a status.

| Priority | Meaning |
|----------|---------|
| **P1** | Must pass for sign-off |
| **P2** | Should pass; strong evidence of correctness |
| **P3** | Nice to have / robustness |

| Status | Meaning |
|--------|---------|
| **Done** | Covered by `max5_basic_test`, which passes on Siemens Questa 2025.2 (8 checks, 0 errors) |
| **Planned** | Needs a new test, sequence or assertion |

---

## 2. Design under test

### 2.1 Ports

| Port           | Dir | Width | Description |
|----------------|-----|-------|-------------|
| `clk`          | in  | 1     | Clock, rising edge |
| `rst_n`        | in  | 1     | Asynchronous, active-low reset |
| `in_valid`     | in  | 1     | `streaming_in` is accepted on this rising edge |
| `streaming_in` | in  | W (8) | Input sample, unsigned |
| `out_valid`    | out | 1     | `data_out` / `max_of_5` hold a new result |
| `data_out`     | out | W     | The accepted sample, passed through |
| `max_of_5`     | out | W     | Max of this sample and the previous 4 accepted samples |

### 2.2 Features

| ID  | Feature | Specification |
|-----|---------|---------------|
| F1  | Sliding-window max | `max_of_5` = max of the 5 most recently **accepted** samples |
| F2  | Partial window | Before 5 samples have arrived, `max_of_5` = max of the samples so far |
| F3  | Pass-through | `data_out` = the sample that produced this result |
| F4  | Latency | Results appear exactly 1 cycle after the sample is accepted |
| F5  | Valid handshake | `out_valid` = `in_valid` delayed by 1 cycle; only accepted samples enter the window |
| F6  | Output hold | When `out_valid=0`, `data_out` and `max_of_5` keep their last values |
| F7  | Reset | Async reset clears the window and all outputs to 0 |
| F8  | Unsigned compare | Values are compared as unsigned (255 > 127) |
| F9  | Throughput | One result per cycle, with no stalls, for any number of cycles |
| F10 | Parameter W | Correct for any data width W ≥ 1 |

### 2.3 Spec decisions to confirm

The original spec does not state these points. The RTL makes the choice below, and the tests check that choice. Confirm each one with the spec owner. If any changes, the matching tests change too.

| # | Question | Current RTL choice | Tests affected |
|---|----------|-------------------|----------------|
| Q1 | Does the window count accepted samples or clock cycles? | Accepted samples. Idle cycles do not age the window. | V3, V4, V8 |
| Q2 | What is the output before 5 samples have arrived? | Max of the samples so far, valid from the first sample | W1–W5 |
| Q3 | Latency: same cycle or registered? | 1 cycle (registered outputs) | L1–L3 |
| Q4 | Signed or unsigned data? | Unsigned | D4, D9 |
| Q5 | What do the outputs show when `out_valid=0`? | Hold the last value | O3 |
| Q6 | Sync or async reset? | Async assert, released on a clock edge | R1–R8 |
| Q7 | Is there backpressure (`out_ready`)? | No; the consumer must always accept | Out of scope |

---

## 3. Testbench and checkers

```
tb_top ── max5_if ── max_of_5 (DUT)
  └─ test
       └─ max5_env
            ├─ max5_agent
            │    ├─ max5_sequencer
            │    ├─ max5_driver    drives on negedge; RESET item pulses rst_n
            │    └─ max5_monitor   samples after posedge
            │          ├─ in_ap  ──> max5_predictor (reference model) ──> scoreboard
            │          └─ out_ap ──────────────────────────────────────> scoreboard
            └─ (planned) SVA checker bound to the DUT
```

| Checker | Catches |
|---------|---------|
| Scoreboard: value | `data_out` or `max_of_5` differs from the reference model |
| Scoreboard: cycle | Output on the wrong cycle (latency error) |
| Scoreboard: unexpected | `out_valid=1` with no accepted input behind it |
| Scoreboard: missing (`check_phase`) | An accepted input never produced an output |
| Scoreboard: empty | The test ended with 0 checks |
| SVA (planned) | Cycle-level rules the scoreboard does not see (section 5) |

---

## 4. Test items

### 4.1 Reset

| ID | Scenario | Stimulus | Expected | Check | Pri | Status |
|----|----------|----------|----------|-------|-----|--------|
| R1 | Power-on reset | `rst_n=0` from time 0 | `out_valid=0`, `data_out=0`, `max_of_5=0`, window empty | SVA A1 | P1 | Planned |
| R2 | First sample after reset | Reset, then `x` | `max_of_5 = x` | Scoreboard | P1 | **Done** |
| R3 | Reset mid-stream clears history | `200 1 2`, reset, `3 4 5 6 7` | `3 4 5 6 7`; 200 never reappears | Scoreboard | P1 | Planned |
| R4 | Reset while `in_valid=1` | Keep `in_valid=1` with data during reset | No sample is accepted during reset; no output | Scoreboard (unexpected) | P1 | Planned |
| R5 | Async assert between edges | Drop `rst_n` mid-cycle | Outputs go to 0 right away, without waiting for a clock edge | SVA A1 | P1 | Planned |
| R6 | Valid on the first edge after reset release | Release `rst_n`, `in_valid=1` on the very next edge | Sample accepted normally; `max = sample` | Scoreboard | P1 | Planned |
| R7 | Repeated resets | Reset, 1 sample, reset, 1 sample, … ×10 | Every output equals its own sample | Scoreboard | P2 | Planned |
| R8 | Short reset pulse | `rst_n` low for less than one clock period | Same as a full reset | Scoreboard + SVA | P2 | Planned |
| R9 | Reset with a full window of 255s | Fill with 255, reset, then `1` | Output 1 (no stale 255) | Scoreboard | P1 | Planned |
| R10 | Long reset | `rst_n` low for 100 cycles with random inputs | No outputs; clean start afterwards | Scoreboard | P3 | Planned |

### 4.2 Window fill (partial window)

| ID | Scenario | Stimulus | Expected | Check | Pri | Status |
|----|----------|----------|----------|-------|-----|--------|
| W1 | 1 to 5 samples after reset | `1 2 3 4 5` | `1 2 3 4 5` (5th output = 5) | Scoreboard | P1 | Partly done (S1 has 4 partial outputs) |
| W2 | Partial window, decreasing | `5 4 3 2 1` | `5 5 5 5 5` | Scoreboard | P1 | Planned |
| W3 | Partial window, max in the middle | `1 9 1 1` | `1 9 9 9` | Scoreboard | P2 | Planned |
| W4 | Partial window of zeros | `0 0 0` | `0 0 0` (reset zeros indistinguishable, still correct) | Scoreboard | P2 | Planned |
| W5 | Transition from partial to full window | `9 1 1 1 1 1` | `9 9 9 9 9 1` (9 leaves at the 6th sample) | Scoreboard | P1 | Planned |

### 4.3 Sliding window and expiry

| ID | Scenario | Stimulus | Expected | Check | Pri | Status |
|----|----------|----------|----------|-------|-----|--------|
| S1 | Spec table | `3 10 4 7 2 12 13 1` | `3 10 10 10 10 12 13 13` | Scoreboard | P1 | **Done** |
| S2 | Max expires after exactly 5 | `9 8 7 6 5 4 3 2 1` | `9 9 9 9 9 8 7 6 5` | Scoreboard | P1 | Planned |
| S3 | Second-largest takes over | `9 7 1 1 1 1 1` | `9 9 9 9 9 7 1` | Scoreboard | P1 | Planned |
| S4 | Increasing stream | `1..20` | `max = input` every cycle | Scoreboard | P1 | Planned |
| S5 | Constant stream | `42 × 10` | 42 every cycle | Scoreboard | P2 | Planned |
| S6 | Single spike | `1 1 1 200 1 1 1 1 1 1` | 200 for exactly 5 outputs | Scoreboard | P1 | Planned |
| S7 | Repeated max (tie) extends lifetime | `5 1 1 5 1 1 1 1 1` | 5 lasts until the second 5 expires | Scoreboard | P1 | Planned |
| S8 | Pattern with period 5 | `1 2 3 4 5` repeated | 5 from the 5th output onwards | Scoreboard | P2 | Planned |
| S9 | Pattern with period 6 (longer than the window) | `9 1 1 1 1 1` repeated | 9 drops to 1 once per period | Scoreboard | P1 | Planned |
| S10 | Sawtooth / alternating | `0 255 0 255 …` and `255 0 0 0 0 0 255 …` | Matches the model | Scoreboard | P2 | Planned |

### 4.4 Max at each window position (comparator tree)

The RTL compares 5 values with a tree: `m01 = max(in, win0)`, `m23 = max(win1, win2)`, `m03 = max(m01, m23)`, `mx = max(m03, win3)`. Each position must be able to win **and** lose. A bug in one branch passes the spec table. For example, ignoring the oldest sample is only caught by C5.

| ID | Scenario (big value = 50, others = 1) | Stimulus | Expected last output | Check | Pri | Status |
|----|---------------------------------------|----------|----------------------|-------|-----|--------|
| C1 | Max is the new input (`streaming_in`) | `1 1 1 1 50` | 50 | Scoreboard | P1 | **Done** |
| C2 | Max is `win0` | `1 1 1 50 1` | 50 | Scoreboard | P1 | **Done** |
| C3 | Max is `win1` | `1 1 50 1 1` | 50 | Scoreboard | P1 | **Done** |
| C4 | Max is `win2` | `1 50 1 1 1` | 50 | Scoreboard | P1 | **Done** |
| C5 | Max is `win3` (oldest) | `50 1 1 1 1` | 50 | Scoreboard | P1 | Planned — **not hit by S1** |
| C6 | Max just left the window | `50 1 1 1 1 1` | 1 | Scoreboard | P1 | Planned |
| C7 | Tie at every comparator | `7 7 7 7 7` | 7 | Scoreboard | P2 | Planned |
| C8 | All 120 orderings of 5 distinct values | Every permutation of `{10,20,30,40,50}` | 50 each time | Scoreboard | P2 | Planned |

### 4.5 Data values

| ID | Scenario | Stimulus | Expected | Check | Pri | Status |
|----|----------|----------|----------|-------|-----|--------|
| D1 | All zeros | `0 × 6` | 0 | Scoreboard | P1 | Planned |
| D2 | All max value | `255 × 6` | 255 | Scoreboard | P1 | Planned |
| D3 | Max value then zeros | `255 0 0 0 0 0` | 255 ×5, then 0 | Scoreboard | P1 | Planned |
| D4 | MSB boundary (unsigned) | `127 128 1 1 1` | 128 (a signed compare would give 127) | Scoreboard | P1 | Planned |
| D5 | Off-by-one values | `100 101 100 99 100` | 101 | Scoreboard | P2 | Planned |
| D6 | Walking one | `1 2 4 8 … 128` | `max = input` | Scoreboard | P2 | Planned |
| D7 | Walking zero | `254 253 251 … 127` | Matches the model | Scoreboard | P2 | Planned |
| D8 | Values differing in one bit, every bit | Pairs `(x, x ^ (1<<b))` for b = 0..7 | Larger of each pair wins | Scoreboard | P2 | Planned |
| D9 | `0` vs `255` in every slot | 255 placed at each position | 255 while it is in the window | Scoreboard | P2 | Planned |
| D10 | Small value range (many ties) | Random values in 0..3 | Matches the model | Scoreboard | P2 | Planned |

### 4.6 Valid handshake and idle cycles

| ID | Scenario | Stimulus | Expected | Check | Pri | Status |
|----|----------|----------|----------|-------|-----|--------|
| V1 | Back-to-back valid | `in_valid=1` every cycle | One output per cycle | Scoreboard | P1 | **Done** |
| V2 | Single idle gap | `5, idle, 6` | 2 outputs; second max = 6 | Scoreboard | P1 | Planned |
| V3 | Idle cycles don't age the window | `50`, 10 idle, `1 1 1 1` | 50 still in window for all 4 | Scoreboard | P1 | Planned |
| V4 | Very long idle | `50`, 1000 idle, `1` | 50 | Scoreboard | P2 | Planned |
| V5 | Idle data is ignored | `in_valid=0` with `streaming_in=255` | 255 never enters the window | Scoreboard | P1 | Planned |
| V6 | Valid toggling every cycle | `in_valid = 1 0 1 0 …` | Matches the model | Scoreboard | P1 | Planned |
| V7 | Idle right after reset | Reset, 5 idle, then data | No outputs while idle; first sample is clean | Scoreboard | P2 | Planned |
| V8 | Idle gap while the max is about to expire | `50 1 1 1`, idle ×3, `1 1` | 50 at the 5th accepted sample, 1 at the 6th | Scoreboard | P1 | Planned |
| V9 | Sparse valid | `in_valid` 10% of cycles, random data | Matches the model | Scoreboard | P2 | Planned |

### 4.7 Outputs and latency

| ID | Scenario | Stimulus | Expected | Check | Pri | Status |
|----|----------|----------|----------|-------|-----|--------|
| L1 | 1-cycle latency | Any | Output cycle = input cycle + 1 | Scoreboard (cycle) | P1 | **Done** |
| L2 | `out_valid` timing | Random `in_valid` | `out_valid(t) = in_valid(t-1)` | SVA A2 | P1 | Planned |
| L3 | No extra or missing outputs | Any | #outputs = #accepted inputs | Scoreboard | P1 | **Done** |
| O1 | Pass-through | Any | `data_out` = input | Scoreboard | P1 | **Done** |
| O2 | `max_of_5 ≥ data_out` | Any | Always true | SVA A4 | P2 | Planned |
| O3 | Outputs hold when idle | Data, then idle | `data_out` / `max_of_5` unchanged while `out_valid=0` | SVA A3 | P2 | Planned |
| O4 | No X on outputs after reset | Any legal stimulus | Outputs never X or Z after reset | SVA A5 | P1 | Planned |
| O5 | Max is one of the last 5 inputs | Any | `max_of_5` equals one of the last 5 accepted samples | Scoreboard (model) | P2 | **Done** (implied by model) |

### 4.8 Illegal and unknown inputs

| ID | Scenario | Stimulus | Expected | Check | Pri | Status |
|----|----------|----------|----------|-------|-----|--------|
| X1 | X data while idle | `in_valid=0`, `streaming_in='x` | No effect on outputs or the window | SVA A5 + scoreboard | P1 | Planned |
| X2 | X data while valid | `in_valid=1`, `streaming_in='x` | Illegal input; document that X propagates to outputs | Observe only | P3 | Planned |
| X3 | X on `in_valid` | `in_valid='x` | Illegal input; flagged by SVA A6 | SVA A6 | P3 | Planned |

### 4.9 Stress and random

| ID | Scenario | Stimulus | Expected | Check | Pri | Status |
|----|----------|----------|----------|-------|-----|--------|
| T1 | Long random stream | 10,000 samples, uniform data, 75% valid | 0 mismatches | Scoreboard | P1 | Planned |
| T2 | Corner-biased random | Data weighted toward 0, 1, 127, 128, 254, 255 | 0 mismatches | Scoreboard | P1 | Planned |
| T3 | Random with resets | Reset every 50–500 samples | 0 mismatches | Scoreboard | P1 | Planned |
| T4 | Random valid density sweep | `in_valid` at 10%, 50%, 90%, 100% | 0 mismatches | Scoreboard | P2 | Planned |
| T5 | Soak | 1,000,000 samples | 0 mismatches | Scoreboard | P3 | Planned |
| T6 | Seed regression | T1–T3 with 20 seeds | All pass | Regression | P1 | Planned |

### 4.10 Parameters

| ID | Scenario | Configuration | Expected | Check | Pri | Status |
|----|----------|---------------|----------|-------|-----|--------|
| P1 | Default width | `W = 8` | All tests pass | Regression | P1 | **Done** |
| P2 | 1-bit data | `W = 1` | `max_of_5` = OR of the last 5 bits | Regression | P2 | Planned |
| P3 | Narrow | `W = 2, 4` | All tests pass | Regression | P2 | Planned |
| P4 | Wide | `W = 16, 32, 64` | All tests pass (MSB checks scale with W) | Regression | P2 | Planned |

### 4.11 Testbench self-check (bug injection)

A testbench that never fails proves nothing. Each bug below is inserted into a copy of the RTL. The listed test must **fail**.

| ID | Injected bug | Must be caught by |
|----|--------------|-------------------|
| M1 | Oldest sample ignored (window of 4) | C5, S2 |
| M2 | Window of 6 (extra register) | S2, C6 |
| M3 | Signed compare | D4 |
| M4 | Window shifts on idle cycles | V3, V8 |
| M5 | Window not cleared on reset | R3, R9 |
| M6 | 2-cycle latency | Scoreboard (cycle) on any test |
| M7 | `out_valid` stuck high | Scoreboard (unexpected) |
| M8 | `>` changed to `>=` in one comparator | None (same result); confirms ties are harmless |
| M9 | Comparator returns the min in one branch | C1–C5 |

---

## 5. Planned assertions (SVA)

| ID | Property | Items |
|----|----------|-------|
| A1 | `!rst_n |-> (out_valid == 0 && data_out == 0 && max_of_5 == 0)` | R1, R5, R8 |
| A2 | `rst_n && $past(rst_n) |-> out_valid == $past(in_valid)` | L2 |
| A3 | `rst_n && $past(rst_n) && !out_valid |-> $stable(data_out) && $stable(max_of_5)` | O3 |
| A4 | `out_valid |-> max_of_5 >= data_out` | O2 |
| A5 | `rst_n |-> !$isunknown({out_valid, data_out, max_of_5})` | O4, X1 |
| A6 | `rst_n |-> !$isunknown(in_valid)`, and `in_valid |-> !$isunknown(streaming_in)` (input legality) | X2, X3 |

---

## 6. Test list

| Test | Sequence(s) | Items | Pri | Status |
|------|-------------|-------|-----|--------|
| `max5_basic_test` | `max5_basic_seq` | S1, R2, W1 (part), C1–C4, V1, L1, L3, O1, O5, P1 | P1 | **Done** |
| `max5_reset_test` | reset sequences | R1, R3–R10 | P1 | Planned |
| `max5_window_test` | directed patterns | W1–W5, S2–S10 | P1 | Planned |
| `max5_slot_test` | one big value per slot, permutations | C1–C8 | P1 | Planned |
| `max5_data_test` | value patterns | D1–D10 | P1 | Planned |
| `max5_valid_test` | idle patterns | V2–V9, X1 | P1 | Planned |
| `max5_random_test` | constrained random | T1–T6 | P1 | Planned |
| `max5_sva` (bound to DUT) | — | A1–A6 | P1 | Planned |
| Width regression | all tests at each W | P2–P4 | P2 | Planned |
| Bug-injection runs | RTL copies with bugs | M1–M9 | P2 | Planned |

---

## 7. Sign-off criteria

1. All **P1** items are Done and passing.
2. Every test in section 6 passes with 0 `UVM_ERROR` / `UVM_FATAL` and no assertion failures.
3. The scoreboard reports `N passed, 0 failed` with N > 0 in every test.
4. The random regression (T6) passes on 20 seeds.
5. Every injected bug M1–M7 and M9 is caught by at least one test (M8 is expected to pass).
6. Spec decisions Q1–Q6 are confirmed by the spec owner.
