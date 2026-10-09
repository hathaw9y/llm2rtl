`timescale 1ns/1ps
module tb_smollm2_silu_mul_board_probe;
    logic aclk=0, aresetn=0;
    always #5 aclk=~aclk;
    logic [31:0] host_data0=0, host_data1=0, host_data2=0, host_data3=0;
    logic [31:0] host_control=0, host_status;
    logic [71:0] m_axis_mm2s_cmd_tdata;
    logic m_axis_mm2s_cmd_tvalid, m_axis_mm2s_cmd_tready=0;
    logic [63:0] s_axis_mm2s_tdata=0;
    logic [7:0] s_axis_mm2s_tkeep=0;
    logic s_axis_mm2s_tvalid=0, s_axis_mm2s_tready;
    logic s_axis_mm2s_tlast=0;
    logic [7:0] s_axis_mm2s_sts_tdata=0;
    logic s_axis_mm2s_sts_tkeep=0, s_axis_mm2s_sts_tvalid=0;
    logic s_axis_mm2s_sts_tready, s_axis_mm2s_sts_tlast=0;
    logic datamover_mm2s_err=0;
    logic [127:0] prefill_gate[0:6143], prefill_up[0:6143];
    logic [127:0] decode_gate[0:191], decode_up[0:191];
    logic [127:0] prefill_expected[0:6143], decode_expected[0:191];
    logic host_seq=0;

    smollm2_dma_gemm_board_probe #(.REAL_SILU(1'b1)) dut (.*);

    task automatic host_op(input int op, bank, addr,
                           input logic [127:0] payload,
                           output logic [31:0] status);
        @(negedge aclk);
        {host_data3,host_data2,host_data1,host_data0}=payload;
        host_seq=!host_seq;
        host_control={host_seq,3'(op),4'(bank),8'd0,16'(addr)};
        do @(posedge aclk); while(host_status[31]!=host_seq || host_status[30]);
        #1; status=host_status;
        if(status[28]) $fatal(1,"host op=%0d bank=%0d error=%h",op,bank,status);
    endtask

    task automatic record(input int index, input logic [127:0] value);
        logic [31:0] status;
        host_op(1,0,index,value,status);
    endtask

    function automatic logic [127:0] dma_load(input int bank, bytes, addr);
        return (128'(1)<<124)|(128'(bank)<<120)|
               (128'(bytes)<<57)|(128'(addr)<<25);
    endfunction

    task automatic send_beat(input logic [63:0] data, input logic last);
        @(negedge aclk);
        s_axis_mm2s_tdata=data; s_axis_mm2s_tkeep=8'hff;
        s_axis_mm2s_tlast=last; s_axis_mm2s_tvalid=1;
        do @(posedge aclk); while(!s_axis_mm2s_tready);
        #1; s_axis_mm2s_tvalid=0;
    endtask

    task automatic service_load(input int address, words, source);
        logic [3:0] tag;
        logic [127:0] value;
        wait(m_axis_mm2s_cmd_tvalid);
        @(negedge aclk); m_axis_mm2s_cmd_tready=1;
        @(posedge aclk);
        if (!m_axis_mm2s_cmd_tvalid ||
            m_axis_mm2s_cmd_tdata[63:32]!=address ||
            m_axis_mm2s_cmd_tdata[22:0]!=words*16)
            $fatal(1,"bad DMA command addr=%h btt=%d",
                   m_axis_mm2s_cmd_tdata[63:32],m_axis_mm2s_cmd_tdata[22:0]);
        tag=m_axis_mm2s_cmd_tdata[67:64];
        #1; m_axis_mm2s_cmd_tready=0;
        for(int i=0;i<words;i++) begin
            case(source)
                0: value=prefill_gate[i];
                1: value=prefill_up[i];
                2: value=decode_gate[i];
                default: value=decode_up[i];
            endcase
            send_beat(value[63:0],0);
            send_beat(value[127:64],i==words-1);
        end
        repeat(4) @(posedge aclk);
        @(negedge aclk);
        s_axis_mm2s_sts_tdata={4'h8,tag};
        s_axis_mm2s_sts_tkeep=1; s_axis_mm2s_sts_tlast=1;
        s_axis_mm2s_sts_tvalid=1;
        do @(posedge aclk); while(!s_axis_mm2s_sts_tready);
        #1; s_axis_mm2s_sts_tvalid=0;
    endtask

    task automatic run_case(input int rows);
        logic [31:0] status;
        logic [127:0] expected_word;
        logic [15:0] expected_value;
        int mismatches;
        begin
            record(0,dma_load(8,rows*3072,rows==1?'h3000:'h1000));
            record(1,dma_load(9,rows*3072,rows==1?'h4000:'h2000));
            record(2,(128'(16'ha89a)<<112)|128'(rows));
            record(3,'0);
            fork
                begin
                    host_op(2,0,0,'0,status);
                    wait(host_status[27]);
                    if(host_status[28]) $fatal(1,"SILU dispatcher error %h",host_status);
                end
                begin
                    service_load(rows==1?'h3000:'h1000,rows*192,rows==1?2:0);
                    service_load(rows==1?'h4000:'h2000,rows*192,rows==1?3:1);
                end
            join
            host_op(6,14,0,'0,status);
            if(status[15:0]!=rows*192)
                $fatal(1,"SILU writes=%0d expected=%0d",status[15:0],rows*192);
            mismatches=0;
            for(int row=0;row<rows;row++)
            for(int col=0;col<16;col++) begin
                expected_word=rows==1 ? decode_expected[row*192+col/8] :
                                         prefill_expected[row*192+col/8];
                expected_value=expected_word[16*(col%8)+:16];
                host_op(5,14,row*16+col,'0,status);
                if(status[15:0]!==expected_value) begin
                    if(mismatches<8)
                        $display("SILU row=%0d col=%0d got=%h expected=%h",
                                 row,col,status[15:0],expected_value);
                    mismatches++;
                end
            end
            if(mismatches) $fatal(1,"SILU mismatches=%0d",mismatches);
            $display("PASS SILU_MUL board integration rows=%0d compare=%0d mismatches=0",
                     rows,rows*16);
        end
    endtask

    initial begin
        $readmemh("vectors/prefill32_gate_words.hex",prefill_gate);
        $readmemh("vectors/prefill32_up_words.hex",prefill_up);
        $readmemh("vectors/prefill32_expected_words.hex",prefill_expected);
        $readmemh("vectors/decode1_gate_words.hex",decode_gate);
        $readmemh("vectors/decode1_up_words.hex",decode_up);
        $readmemh("vectors/decode1_expected_words.hex",decode_expected);
        repeat(8) @(negedge aclk);
        aresetn=1;
        run_case(32);
        run_case(1);
        $display("PASS smollm2_silu_mul_board_probe");
        $finish;
    end
    initial begin #10000000; $fatal(1,"SILU board integration timeout"); end
endmodule
