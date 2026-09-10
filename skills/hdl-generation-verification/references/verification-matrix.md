# HDL verification matrix

Use the applicable rows; record N/A with a reason rather than silently omitting them.

| Area | Required evidence |
|---|---|
| Interface | Port widths, signedness, ownership, acceptance and completion cycles |
| Numeric | Reference model, zero, extrema, overflow, saturation, rounding |
| Control | Idle, start, busy, done, error, illegal request, retry, cancel |
| Reset | Idle reset, active reset, deassertion, first transaction after reset |
| Flow control | Backpressure, stalls, simultaneous events, no duplicate/lost transfer |
| Memory | All banks, endpoints, latency, hold, isolation, read/write collision policy |
| Parameters | Default, minimum, representative, maximum, illegal combinations |
| Closure | Exactly one definition for every reachable synthesizable module |
| Packaging | Repository and copied/package source sets elaborate identically |
| Synthesis | No black boxes/latches; intended RAM/DSP mapping; bounded resources |
| Evidence | Commands, versions, logs, hashes, deterministic pass markers |

## Review questions

- Is the tested top the top that downstream packaging will use?
- Does the test exercise the changed path, or merely a nearby module?
- Are handshake levels and pulses distinguished explicitly?
- Are results checked at the exact promised cycle?
- Can input changes after acceptance alter the active transaction?
- Are terminal pipeline elements intentionally observable or intentionally dead?
- Does every diagnostic bit have a reproducible trigger and clearing rule?
- Would removing any reachable source make elaboration fail before board synthesis?

