`timescale 1ns/1ps

module tb_smollm2_bank_memories;
    logic aclk = 0;
    always #2.5 aclk = ~aclk;
    logic aresetn = 0;
    logic [0:12] bank_ena = '0, bank_enb = '0;
    logic [0:12][15:0] bank_wea = '0, bank_addra = '0, bank_addrb = '0;
    logic [0:12][127:0] bank_dina = '0, bank_doutb;
    int capacity [0:12] = '{2304,2304,2304,36864,2304,2304,768,
                             512,24576,24576,36864,2304,6144};
    smollm2_bank_memories dut (.*);

    task automatic write_word(input int bank, input int address,
                              input logic [127:0] value,
                              input logic [15:0] mask);
        @(negedge aclk);
        bank_ena[bank] = 1;
        bank_wea[bank] = mask;
        bank_addra[bank] = 16'(address);
        bank_dina[bank] = value;
        @(posedge aclk);
        @(negedge aclk);
        bank_ena[bank] = 0;
        bank_wea[bank] = 0;
    endtask

    task automatic read_word(input int bank, input int address,
                             input logic [127:0] expected);
        @(negedge aclk);
        bank_enb[bank] = 1;
        bank_addrb[bank] = 16'(address);
        repeat (3) begin @(posedge aclk); #1; end
        if (bank_doutb[bank] !== expected)
            $fatal(1, "bank %0d addr %0d read %h expected %h",
                   bank, address, bank_doutb[bank], expected);
        @(negedge aclk);
        bank_enb[bank] = 0;
    endtask

    initial begin
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        for (int bank = 0; bank < 13; bank++) begin
            write_word(bank, 0, 128'h00112233445566778899aabbccdd0000 | 128'(bank), '1);
            write_word(bank, capacity[bank]-1,
                       128'hffeeddccbbaa99887766554433220000 | 128'(bank), '1);
            read_word(bank, 0, 128'h00112233445566778899aabbccdd0000 | 128'(bank));
            read_word(bank, capacity[bank]-1,
                      128'hffeeddccbbaa99887766554433220000 | 128'(bank));
        end

        write_word(0, 0, 128'hbeef, 16'h0003);
        read_word(0, 0, 128'h00112233445566778899aabbccddbeef);

        // SOFTMAX-style in-place use: read and write different addresses.
        @(negedge aclk);
        bank_enb[10] = 1;
        bank_addrb[10] = 0;
        bank_ena[10] = 1;
        bank_addra[10] = 1;
        bank_wea[10] = '1;
        bank_dina[10] = 128'hcafebabedeadbeef0123456789abcdef;
        @(posedge aclk);
        @(negedge aclk);
        bank_enb[10] = 0; bank_ena[10] = 0; bank_wea[10] = 0;
        repeat (2) @(posedge aclk);
        #1;
        if (bank_doutb[10] !==
            (128'h00112233445566778899aabbccdd0000 | 128'd10))
            $fatal(1, "in-place read response mismatch");
        read_word(10, 1, 128'hcafebabedeadbeef0123456789abcdef);

        // A chunk boundary and reset do not erase stored data.
        repeat (4) @(posedge aclk);
        read_word(12, capacity[12]-1,
                  128'hffeeddccbbaa9988776655443322000c);
        @(negedge aclk); aresetn = 0;
        repeat (2) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        read_word(3, capacity[3]-1,
                  128'hffeeddccbbaa99887766554433220003);
        $display("PASS smollm2_bank_memories");
        $finish;
    end
endmodule
