# max_of_5 — Test List (20 tests)

Tests are grouped by the feature they target. Each group mixes **directed** tests (exact sequences, timing, and cases random testing rarely reaches) with **constrained-random** tests, marked *(random)*.

Every test passes only with 0 scoreboard mismatches and no `UVM_ERROR` / `UVM_FATAL`. For directed tests, **Expected** lists the `max_of_5` outputs in order, one per accepted sample.

## 1. Reset

| Scenario | Stimulus | Expected |
|----------|----------|----------|
| Reset mid-stream | `200 1 2`, reset, `3 4 5 6 7` | `200 200 200`, then `3 4 5 6 7`; 200 never reappears |
| Reset while `in_valid=1` | Hold `in_valid=1` with data during reset, then `8` on the first edge after release | No outputs during reset; first output `8` |
| Async reset between clock edges | Fill window with `255`, pull `rst_n` low mid-cycle for less than one clock period, then `1` | Outputs go to 0 immediately; next output `1` |
| Random with resets *(random)* | 10,000 samples, reset every 50–500 samples | 0 mismatches; no history survives a reset |

## 2. Window fill and expiry

| Scenario | Stimulus | Expected |
|----------|----------|----------|
| Spec table | `3 10 4 7 2 12 13 1` | `3 10 10 10 10 12 13 13` |
| Partial window after reset | Reset, then `1 2 3 4 5` | `1 2 3 4 5` (5th output = 5) |
| Max leaves after exactly 5 samples | `9 8 7 6 5 4 3 2 1` | `9 9 9 9 9 8 7 6 5` |
| Max in the oldest slot | `50 1 1 1 1 1` | `50 50 50 50 50 1` |
| Repeated max extends its lifetime | `5 1 1 5 1 1 1 1 1` | `5 5 5 5 5 5 5 5 1` |

## 3. Data values

| Scenario | Stimulus | Expected |
|----------|----------|----------|
| Unsigned compare and extreme values | `127 128 255 0 0 0 0 0 0` | `127 128 255 255 255 255 255 0 0` |
| Corner values *(random)* | 10,000 samples weighted toward 0, 1, 127, 128, 254, 255 | 0 mismatches |
| Ties *(random)* | 10,000 samples in the range 0–3 | 0 mismatches |

## 4. Valid handshake and idle cycles

| Scenario | Stimulus | Expected |
|----------|----------|----------|
| Idle cycles don't age the window | `50`, 10 idle cycles, `1 1 1 1 1` | `50 50 50 50 50 1`; no outputs during idle |
| Data ignored when not valid | `1`, idle with `streaming_in=255`, `2` | `1 2`; 255 never appears |
| X data while idle | `4`, `in_valid=0` with `streaming_in='x`, `3` | `4 4`; no X on any output |
| Valid-density sweep *(random)* | 5,000 samples each at `in_valid` 10%, 50%, 90%, 100% | 0 mismatches; one output per accepted sample |

## 5. Stress and regression

| Scenario | Stimulus | Expected |
|----------|----------|----------|
| Long random stream *(random)* | 10,000 samples, uniform 0–255, `in_valid` high 75% of cycles | 0 mismatches |
| Seed regression *(random)* | All 5 random tests, 20 seeds each | All 100 runs pass |

## 6. Configuration and testbench qualification

| Scenario | Stimulus | Expected |
|----------|----------|----------|
| Data-width sweep | All tests with `W = 1, 4, 16, 32` | All pass; with `W = 1`, `max_of_5` = OR of the last 5 bits |
| Testbench catches bugs | Run all tests on RTL copies with one bug each: oldest slot ignored, signed compare, window shifts on idle, window not cleared on reset | Every bug makes at least one test fail |
