module TopModule (
    input  logic clock,
    input  logic a,
    output logic p,
    output logic q
);
    // Intentional high-level transparent latch.
    always_latch begin
        if (clock)
            p <= a;
    end

    always_ff @(negedge clock) begin
        q <= p;
    end
endmodule
