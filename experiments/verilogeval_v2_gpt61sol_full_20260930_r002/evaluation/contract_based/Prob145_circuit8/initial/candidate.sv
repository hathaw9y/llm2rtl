module TopModule (
    input logic clock,
    input logic a,
    output logic p,
    output logic q
);
    // Transparent during the high phase; retain the last value while low.
    always_latch begin
        if (clock) p <= a;
    end

    always_ff @(negedge clock) begin
        q <= p;
    end
endmodule
