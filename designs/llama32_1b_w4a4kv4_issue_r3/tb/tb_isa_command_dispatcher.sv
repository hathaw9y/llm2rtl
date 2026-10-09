`timescale 1ns/1ps

module tb_isa_command_dispatcher;
    localparam integer BANK_NUM = 16;
    localparam logic [3:0] OP_LOAD=4'd1, OP_STORE=4'd2, OP_GEMM=4'd3;

    logic aclk=0, aresetn=0, cmd_dispatcher_start=0;
    logic cmd_dispatcher_busy,cmd_dispatcher_done,cmd_dispatcher_error;
    logic [7:0] cmd_dispatcher_error_code;
    logic [9:0] current_pc;
    logic cmd_bram_enb;
    logic [31:0] cmd_bram_addrb;
    logic [127:0] cmd_bram_doutb;

    logic m_ctrl_mm2s_cmd_valid,m_ctrl_mm2s_cmd_ready=0;
    logic [31:0] m_ctrl_mm2s_cmd_addr,m_ctrl_mm2s_cmd_offset;
    logic [22:0] m_ctrl_mm2s_cmd_btt;
    logic [3:0] m_ctrl_mm2s_cmd_bank,m_ctrl_mm2s_cmd_tag;
    logic s_ctrl_mm2s_sts_valid=0,m_ctrl_mm2s_sts_ready;
    logic [3:0] s_ctrl_mm2s_sts_tag=0;
    logic s_ctrl_mm2s_sts_error=0;

    logic m_ctrl_s2mm_cmd_valid,m_ctrl_s2mm_cmd_ready=0;
    logic [31:0] m_ctrl_s2mm_cmd_addr,m_ctrl_s2mm_cmd_offset;
    logic [22:0] m_ctrl_s2mm_cmd_btt;
    logic [3:0] m_ctrl_s2mm_cmd_bank,m_ctrl_s2mm_cmd_tag;
    logic s_ctrl_s2mm_sts_valid=0,m_ctrl_s2mm_sts_ready;
    logic [3:0] s_ctrl_s2mm_sts_tag=0;
    logic s_ctrl_s2mm_sts_error=0;

    logic m_ctrl_sa_start,m_ctrl_sa_busy=0;
    logic [5:0] m_ctrl_sa_m_size;
    logic [10:0] m_ctrl_sa_n_size;
    logic [11:0] m_ctrl_sa_k_size;
    logic [3:0] m_ctrl_sa_act_bank,m_ctrl_sa_wgt_bank,m_ctrl_sa_out_bank;
    logic [31:0] m_ctrl_sa_out_base_addr;
    logic s_ctrl_sa_done=0,m_ctrl_sa_done_ready,s_ctrl_sa_error=0;
    logic [3:0] s_ctrl_sa_act_bank=0,s_ctrl_sa_wgt_bank=0,s_ctrl_sa_out_bank=0;

    wire [3:0] bank_rd_acquire [1:15];
    wire bank_rd_release [1:15];
    wire [3:0] bank_wr_acquire [1:15];
    wire bank_wr_release [1:15];
    logic bank_rd_busy [1:15];
    logic bank_wr_busy [1:15];
    logic bank_rd_owned_r [1:15];
    logic bank_wr_owned_r [1:15];
    logic bank_rd_hold [1:15];
    logic bank_wr_hold [1:15];

    logic [127:0] command_mem [0:1023];
    logic [127:0] bram_pipe0_r,bram_pipe1_r;
    integer fetch_count=0,failures=0;
    integer i;
    integer model_idx;

    isa_command_dispatcher dut(.*);
    always #2.5 aclk=~aclk;

    genvar busy_gen;
    generate
        for(busy_gen=1;busy_gen<16;busy_gen=busy_gen+1)begin:gen_bank_busy
            assign bank_rd_busy[busy_gen]=bank_rd_owned_r[busy_gen]||bank_rd_hold[busy_gen];
            assign bank_wr_busy[busy_gen]=bank_wr_owned_r[busy_gen]||bank_wr_hold[busy_gen];
        end
    endgenerate

    always_ff @(posedge aclk) begin
        if(!aresetn)begin
            bram_pipe0_r<=0;bram_pipe1_r<=0;fetch_count<=0;
            for(model_idx=1;model_idx<16;model_idx=model_idx+1)begin
                bank_rd_owned_r[model_idx]<=0;bank_wr_owned_r[model_idx]<=0;
            end
        end else begin
            if(cmd_bram_enb)begin
                bram_pipe0_r<=command_mem[cmd_bram_addrb[9:0]];
                fetch_count<=fetch_count+1;
            end
            bram_pipe1_r<=bram_pipe0_r;
            for(model_idx=1;model_idx<16;model_idx=model_idx+1)begin
                if(bank_rd_release[model_idx])bank_rd_owned_r[model_idx]<=0;
                else if(bank_rd_acquire[model_idx]!=0)bank_rd_owned_r[model_idx]<=1;
                if(bank_wr_release[model_idx])bank_wr_owned_r[model_idx]<=0;
                else if(bank_wr_acquire[model_idx]!=0)bank_wr_owned_r[model_idx]<=1;
            end
        end
    end
    assign cmd_bram_doutb=bram_pipe1_r;

    function automatic logic [127:0] dma_cmd(
        input logic [3:0] op,input logic [3:0] bank,
        input logic [31:0] offset,input logic [22:0] btt,
        input logic [31:0] addr,input logic [24:0] reserved);
        logic [127:0] v;
        begin
            v=0;v[127:124]=op;v[115:112]=bank;v[111:80]=offset;
            v[79:57]=btt;v[56:25]=addr;v[24:0]=reserved;dma_cmd=v;
        end
    endfunction

    function automatic logic [127:0] gemm_cmd(
        input logic [3:0] act,input logic [3:0] wgt,input logic [3:0] out,
        input logic [5:0] m,input logic [10:0] n,input logic [11:0] k,
        input logic [24:0] reserved);
        logic [127:0] v;logic [31:0] shape;
        begin
            shape=0;shape[31:26]=m;shape[25:15]=n;shape[14:3]=k;
            v=0;v[127:124]=4'd3;v[123:120]=act;v[119:116]=wgt;
            v[115:112]=out;v[111:80]=shape;v[24:0]=reserved;gemm_cmd=v;
        end
    endfunction

    task automatic clear_holds;
        integer j;
        begin for(j=1;j<16;j=j+1)begin bank_rd_hold[j]=0;bank_wr_hold[j]=0;end end
    endtask
    task automatic reset_dut;
        begin
            @(negedge aclk);aresetn=0;cmd_dispatcher_start=0;
            m_ctrl_mm2s_cmd_ready=0;m_ctrl_s2mm_cmd_ready=0;m_ctrl_sa_busy=0;
            s_ctrl_mm2s_sts_valid=0;s_ctrl_s2mm_sts_valid=0;s_ctrl_sa_done=0;
            clear_holds();repeat(2)@(posedge aclk);@(negedge aclk);aresetn=1;
            @(posedge aclk);
            if(cmd_dispatcher_busy||cmd_dispatcher_done||cmd_dispatcher_error)
                begin $error("reset status");failures=failures+1;end
            if(!m_ctrl_mm2s_sts_ready||!m_ctrl_s2mm_sts_ready||!m_ctrl_sa_done_ready)
                begin $error("response ready not high out of reset");failures=failures+1;end
        end
    endtask
    task automatic launch;
        begin @(negedge aclk);cmd_dispatcher_start=1;@(negedge aclk);cmd_dispatcher_start=0;end
    endtask
    task automatic wait_state(input logic [2:0] s);
        integer t;
        begin t=0;while(dut.state_r!==s&&t<200)begin @(posedge aclk);t=t+1;end
        if(dut.state_r!==s)begin $error("state timeout %0d",s);failures=failures+1;end end
    endtask

    task automatic accept_load(input logic [127:0] c,input integer stalls);
        integer t,j;logic [3:0] b;
        begin
            b=c[115:112];m_ctrl_mm2s_cmd_ready=0;t=0;
            while(!m_ctrl_mm2s_cmd_valid&&t<200)begin @(posedge aclk);t=t+1;end
            if(!m_ctrl_mm2s_cmd_valid||m_ctrl_mm2s_cmd_addr!==c[56:25]||
               m_ctrl_mm2s_cmd_btt!==c[79:57]||m_ctrl_mm2s_cmd_offset!==c[111:80]||
               m_ctrl_mm2s_cmd_bank!==b||m_ctrl_mm2s_cmd_tag!==b)begin
                $error("MM2S typed payload mismatch");failures=failures+1;end
            for(j=0;j<stalls;j=j+1)begin @(posedge aclk);
                if(!m_ctrl_mm2s_cmd_valid||m_ctrl_mm2s_cmd_addr!==c[56:25]||
                   m_ctrl_mm2s_cmd_btt!==c[79:57]||m_ctrl_mm2s_cmd_offset!==c[111:80]||
                   m_ctrl_mm2s_cmd_bank!==b||m_ctrl_mm2s_cmd_tag!==b)
                    begin $error("MM2S changed under backpressure");failures=failures+1;end
            end
            @(negedge aclk);m_ctrl_mm2s_cmd_ready=1;@(posedge aclk);
            if(bank_wr_acquire[b]!==OP_LOAD||bank_rd_acquire[b]!==0)
                begin $error("MM2S acquire wrong b=%0d wr=%0h rd=%0h valid=%0b ready=%0b fire=%0b state=%0d",b,bank_wr_acquire[b],bank_rd_acquire[b],m_ctrl_mm2s_cmd_valid,m_ctrl_mm2s_cmd_ready,dut.request_fire_w,dut.state_r);failures=failures+1;end
            @(negedge aclk);m_ctrl_mm2s_cmd_ready=0;
        end
    endtask
    task automatic accept_store(input logic [127:0] c,input integer stalls);
        integer t,j;logic [3:0] b;
        begin
            b=c[115:112];m_ctrl_s2mm_cmd_ready=0;t=0;
            while(!m_ctrl_s2mm_cmd_valid&&t<200)begin @(posedge aclk);t=t+1;end
            if(!m_ctrl_s2mm_cmd_valid||m_ctrl_s2mm_cmd_addr!==c[56:25]||
               m_ctrl_s2mm_cmd_btt!==c[79:57]||m_ctrl_s2mm_cmd_offset!==c[111:80]||
               m_ctrl_s2mm_cmd_bank!==b||m_ctrl_s2mm_cmd_tag!==b)begin
                $error("S2MM typed payload mismatch");failures=failures+1;end
            for(j=0;j<stalls;j=j+1)begin @(posedge aclk);
                if(!m_ctrl_s2mm_cmd_valid||m_ctrl_s2mm_cmd_addr!==c[56:25]||
                   m_ctrl_s2mm_cmd_btt!==c[79:57]||m_ctrl_s2mm_cmd_offset!==c[111:80]||
                   m_ctrl_s2mm_cmd_bank!==b||m_ctrl_s2mm_cmd_tag!==b)
                    begin $error("S2MM changed under backpressure");failures=failures+1;end
            end
            @(negedge aclk);m_ctrl_s2mm_cmd_ready=1;@(posedge aclk);
            if(bank_rd_acquire[b]!==OP_STORE||bank_wr_acquire[b]!==0)
                begin $error("S2MM acquire wrong");failures=failures+1;end
            @(negedge aclk);m_ctrl_s2mm_cmd_ready=0;
        end
    endtask
    task automatic accept_gemm(input logic [127:0] c,input integer stalls);
        integer t,j;logic[3:0]a,w,o;logic[31:0]shape;
        begin
            a=c[123:120];w=c[119:116];o=c[115:112];shape=c[111:80];
            m_ctrl_sa_busy=1;t=0;
            while(!m_ctrl_sa_start&&t<200)begin @(posedge aclk);t=t+1;end
            if(!m_ctrl_sa_start||m_ctrl_sa_m_size!==shape[31:26]||
               m_ctrl_sa_n_size!==shape[25:15]||m_ctrl_sa_k_size!==shape[14:3]||
               m_ctrl_sa_act_bank!==a||m_ctrl_sa_wgt_bank!==w||
               m_ctrl_sa_out_bank!==o||m_ctrl_sa_out_base_addr!==0)begin
                $error("SA typed payload mismatch");failures=failures+1;end
            for(j=0;j<stalls;j=j+1)begin @(posedge aclk);
                if(!m_ctrl_sa_start||m_ctrl_sa_m_size!==shape[31:26]||
                   m_ctrl_sa_n_size!==shape[25:15]||m_ctrl_sa_k_size!==shape[14:3]||
                   m_ctrl_sa_act_bank!==a||m_ctrl_sa_wgt_bank!==w||m_ctrl_sa_out_bank!==o)
                    begin $error("SA changed under busy backpressure");failures=failures+1;end
            end
            @(negedge aclk);m_ctrl_sa_busy=0;@(posedge aclk);
            if(bank_rd_acquire[a]!==OP_GEMM||bank_rd_acquire[w]!==OP_GEMM||
               bank_rd_acquire[o]!==OP_GEMM||bank_wr_acquire[o]!==OP_GEMM)
                begin $error("SA acquire wrong");failures=failures+1;end
            @(negedge aclk);m_ctrl_sa_busy=1;
        end
    endtask

    task automatic complete_load(input logic[3:0]tag,input logic err,input logic expect_rel);
        integer j;logic any_rel;
        begin @(negedge aclk);s_ctrl_mm2s_sts_tag=tag;s_ctrl_mm2s_sts_error=err;
        s_ctrl_mm2s_sts_valid=1;@(posedge aclk);
        any_rel=0;for(j=1;j<16;j=j+1)any_rel=any_rel||bank_wr_release[j];
        if(!m_ctrl_mm2s_sts_ready||
           ((tag!=0)&&(bank_wr_release[tag]!==expect_rel))||
           ((tag==0)&&(any_rel!==expect_rel)))
            begin $error("MM2S response release mismatch tag=%0d",tag);failures=failures+1;end
        @(negedge aclk);s_ctrl_mm2s_sts_valid=0;s_ctrl_mm2s_sts_error=0;end
    endtask
    task automatic complete_store(input logic[3:0]tag,input logic err,input logic expect_rel);
        begin @(negedge aclk);s_ctrl_s2mm_sts_tag=tag;s_ctrl_s2mm_sts_error=err;
        s_ctrl_s2mm_sts_valid=1;@(posedge aclk);
        if(!m_ctrl_s2mm_sts_ready||bank_rd_release[tag]!==expect_rel)
            begin $error("S2MM response release mismatch tag=%0d",tag);failures=failures+1;end
        @(negedge aclk);s_ctrl_s2mm_sts_valid=0;s_ctrl_s2mm_sts_error=0;end
    endtask
    task automatic complete_gemm(input logic[3:0]a,input logic[3:0]w,input logic[3:0]o,
                                 input logic err,input logic expect_rel);
        begin @(negedge aclk);s_ctrl_sa_act_bank=a;s_ctrl_sa_wgt_bank=w;
        s_ctrl_sa_out_bank=o;s_ctrl_sa_error=err;s_ctrl_sa_done=1;@(posedge aclk);
        if(!m_ctrl_sa_done_ready||bank_wr_release[o]!==expect_rel||
           bank_rd_release[a]!==expect_rel||bank_rd_release[w]!==expect_rel||
           bank_rd_release[o]!==expect_rel)
            begin $error("SA response release mismatch");failures=failures+1;end
        @(negedge aclk);s_ctrl_sa_done=0;s_ctrl_sa_error=0;if(expect_rel)m_ctrl_sa_busy=0;end
    endtask

    task automatic expect_done;
        integer t;begin t=0;while(!cmd_dispatcher_done&&t<300)begin @(posedge aclk);t=t+1;end
        if(!cmd_dispatcher_done)begin $error("done timeout");failures=failures+1;end end
    endtask
    task automatic expect_error(input logic[7:0]code);
        integer t;begin t=0;while(!cmd_dispatcher_error&&t<300)begin @(posedge aclk);t=t+1;end
        if(!cmd_dispatcher_error||cmd_dispatcher_error_code!==code)
            begin $error("error mismatch exp=%02x got=%02x",code,cmd_dispatcher_error_code);failures=failures+1;end end
    endtask

    initial begin:tests
        logic[127:0]c0,c1,c2,c3;integer fetch_before;
        clear_holds();reset_dut();
        $display("STAGE 1 two-load concurrency");

        // Two loads issue before either completion; END drains both.
        c0=dma_cmd(1,1,32'h11112222,23'h101,32'ha0001000,25'h1);
        c1=dma_cmd(1,2,32'h33334444,23'h202,32'ha0002000,25'h2);
        command_mem[0]=c0;command_mem[1]=c1;command_mem[2]=0;launch();
        accept_load(c0,3);accept_load(c1,2);wait_state(3);
        if(!bank_wr_busy[1]||!bank_wr_busy[2])begin $error("loads not concurrent");failures++;end
        complete_load(1,0,1);complete_load(2,0,1);expect_done();

        // Same-bank command stalls, no lookahead, then completion releases during stall.
        $display("STAGE 2 same-bank stall");
        reset_dut();c0=dma_cmd(1,3,1,64,32'h1000,0);c1=dma_cmd(1,3,2,64,32'h2000,0);
        command_mem[0]=c0;command_mem[1]=c1;command_mem[2]=0;launch();accept_load(c0,0);
        wait_state(2);fetch_before=fetch_count;repeat(8)@(posedge aclk);
        if(m_ctrl_mm2s_cmd_valid||current_pc!==1||fetch_count!==fetch_before)
            begin $error("same-bank blocked PC looked ahead");failures++;end
        complete_load(3,0,1);accept_load(c1,0);wait_state(3);complete_load(3,0,1);expect_done();

        // Completion release while later command is still fetching.
        $display("STAGE 3 completion during fetch");
        reset_dut();c0=dma_cmd(1,4,3,64,32'h3000,0);c1=dma_cmd(1,5,4,64,32'h4000,0);
        command_mem[0]=c0;command_mem[1]=c1;command_mem[2]=0;launch();accept_load(c0,0);
        wait_state(1);complete_load(4,0,1);accept_load(c1,0);wait_state(3);complete_load(5,0,1);expect_done();

        // Typed/backpressure plus simultaneous independent MM2S/S2MM/SA completion.
        $display("STAGE 4 typed simultaneous completion");
        reset_dut();
        c0=dma_cmd(1,6,32'h60606060,23'h606,32'h60006000,25'h6);
        c1=dma_cmd(2,7,32'h70707070,23'h707,32'h70007000,25'h7);
        c2=gemm_cmd(8,9,10,6'd32,11'd1024,12'd2048,25'ha);
        command_mem[0]=c0;command_mem[1]=c1;command_mem[2]=c2;command_mem[3]=0;launch();
        accept_load(c0,4);accept_store(c1,4);accept_gemm(c2,4);wait_state(3);
        @(negedge aclk);s_ctrl_mm2s_sts_tag=6;s_ctrl_mm2s_sts_valid=1;
        s_ctrl_s2mm_sts_tag=7;s_ctrl_s2mm_sts_valid=1;
        s_ctrl_sa_act_bank=8;s_ctrl_sa_wgt_bank=9;s_ctrl_sa_out_bank=10;s_ctrl_sa_done=1;
        @(posedge aclk);
        if(!bank_wr_release[6]||!bank_rd_release[7]||!bank_rd_release[8]||
           !bank_rd_release[9]||!bank_rd_release[10]||!bank_wr_release[10])
            begin $error("simultaneous releases missing");failures++;end
        @(negedge aclk);s_ctrl_mm2s_sts_valid=0;s_ctrl_s2mm_sts_valid=0;s_ctrl_sa_done=0;m_ctrl_sa_busy=0;
        expect_done();

        // Zero, wrong-type and mismatched identities cause error drain and no release.
        $display("STAGE 5 invalid responses");
        reset_dut();c0=dma_cmd(1,1,1,64,32'h1000,0);command_mem[0]=c0;command_mem[1]=0;
        launch();accept_load(c0,0);wait_state(3);
        complete_load(0,0,0);
        @(negedge aclk);s_ctrl_s2mm_sts_tag=1;s_ctrl_s2mm_sts_valid=1;@(posedge aclk);
        if(bank_rd_release[1]||bank_wr_release[1])begin $error("wrong-type illegal release");failures++;end
        @(negedge aclk);s_ctrl_s2mm_sts_valid=0;
        complete_load(2,0,0);
        if(!bank_wr_busy[1])begin $error("invalid response released pending bank");failures++;end
        complete_load(1,0,1);expect_error(8'h04);

        // Executor error releases matching ownership and stops the next PC.
        $display("STAGE 6 executor error drain");
        reset_dut();c0=dma_cmd(1,1,1,64,32'h1000,0);c1=dma_cmd(1,2,2,64,32'h2000,0);c2=dma_cmd(1,3,3,64,32'h3000,0);
        command_mem[0]=c0;command_mem[1]=c1;command_mem[2]=c2;command_mem[3]=0;launch();
        accept_load(c0,0);accept_load(c1,0);complete_load(1,1,1);
        repeat(10)@(posedge aclk);if(m_ctrl_mm2s_cmd_valid||current_pc!==2)
            begin $error("issue continued after executor error");failures++;end
        complete_load(2,0,1);expect_error(8'h05);

        // Bank zero and GEMM destination alias reject.
        $display("STAGE 7 illegal banks and alias");
        reset_dut();command_mem[0]=dma_cmd(1,0,0,64,0,0);launch();expect_error(8'h02);
        reset_dut();command_mem[0]=gemm_cmd(1,2,1,1,1,1,0);launch();expect_error(8'h03);

        // END also waits for external busy vector after pending has completed.
        $display("STAGE 8 END external busy drain");
        reset_dut();c0=dma_cmd(1,4,0,64,0,0);command_mem[0]=c0;command_mem[1]=0;
        bank_wr_hold[4]=1;launch();
        // hold itself blocks issue, so clear for acceptance then reassert as external tail.
        bank_wr_hold[4]=0;accept_load(c0,0);bank_wr_hold[4]=1;wait_state(3);complete_load(4,0,1);
        repeat(5)@(posedge aclk);if(cmd_dispatcher_done)begin $error("END ignored external busy");failures++;end
        @(negedge aclk);bank_wr_hold[4]=0;expect_done();

        // Reset in fetch, issue, blocked, END drain and error drain.
        $display("STAGE 9 resets");
        reset_dut();command_mem[0]=dma_cmd(1,1,0,64,0,0);launch();wait_state(1);reset_dut();
        command_mem[0]=dma_cmd(1,1,0,64,0,0);launch();wait_state(2);reset_dut();
        c0=dma_cmd(1,1,0,64,0,0);c1=dma_cmd(1,1,0,64,0,0);command_mem[0]=c0;command_mem[1]=c1;
        launch();accept_load(c0,0);wait_state(2);reset_dut();
        c0=dma_cmd(1,1,0,64,0,0);command_mem[0]=c0;command_mem[1]=0;launch();accept_load(c0,0);wait_state(3);reset_dut();
        c0=dma_cmd(1,1,0,64,0,0);command_mem[0]=c0;command_mem[1]=0;launch();accept_load(c0,0);complete_load(0,0,0);wait_state(4);reset_dut();
        for(i=1;i<16;i=i+1)if(bank_rd_busy[i]||bank_wr_busy[i]||dut.pending_mm2s_r[i]||dut.pending_s2mm_r[i]||dut.pending_sa_r[i])
            begin $error("reset left ownership/pending");failures++;end

        // Repeated complete programs.
        $display("STAGE 10 repeated programs");
        c0=dma_cmd(1,1,0,64,0,0);command_mem[0]=c0;command_mem[1]=0;launch();accept_load(c0,0);wait_state(3);complete_load(1,0,1);expect_done();
        launch();accept_load(c0,0);wait_state(3);complete_load(1,0,1);expect_done();

        // 1024 accepted non-END commands force missing-END error drain.
        $display("STAGE 11 missing END through PC1023");
        reset_dut();for(i=0;i<1024;i=i+1)command_mem[i]=dma_cmd(1,(i%15)+1,i,64,32'h80000000+i,i);
        launch();for(i=0;i<1024;i=i+1)begin
            c0=dma_cmd(1,(i%15)+1,i,64,32'h80000000+i,i);accept_load(c0,0);complete_load((i%15)+1,0,1);
        end
        expect_error(8'h06);if(current_pc!==1023)begin $error("missing END PC wrong");failures++;end

        if(failures==0)begin $display("PASS: isa_command_dispatcher r3 multi-outstanding ownership verification");$finish;end
        else $fatal(1,"FAIL: %0d r3 checks failed",failures);
    end
    initial begin #4000000;$fatal(1,"FAIL: global timeout");end
endmodule
