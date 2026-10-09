Static review of candidate.sv against frozen contract

- Exact TopModule interface: four one-bit inputs clk/resetn/x/y and two one-bit outputs f/g.
- One positive-edge always_ff owns state_r; active-low synchronous reset has priority.
- No initial values or asynchronous reset were added to RTL.
- Nine states fit the explicit four-bit unsigned enum. There is no arithmetic datapath.
- A transitions to the one-cycle f pulse, then WAIT_X. Inputs during the pulse are ignored.
- WAIT_X, SEEN_1 and SEEN_10 recognize contiguous 101; repeated 1 preserves the latest prefix, and 100 clears the prefix.
- Recognition enters Y_FIRST, asserting g for the following interval. Only the next two rising edges sample y for a permanent decision.
- Both permanent decision states hold until reset. f is low in every state except F_PULSE.
- Next-state logic has defaults and complete case handling. Outputs are continuous state decodes. No latches, multiple drivers, delays, vendor dependencies or submodules are present.
- Development testbench uses rolling input history and a deadline monitor rather than the RTL state encoding. It checks sampled reset and between-edge output stability.

This is manual source review, not evidence of successful compilation or simulation.
