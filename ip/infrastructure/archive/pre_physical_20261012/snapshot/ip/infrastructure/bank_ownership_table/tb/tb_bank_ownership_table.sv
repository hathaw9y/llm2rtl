`timescale 1ns/1ps
module tb_bank_ownership_table;
  localparam integer BANK_NUM=8, PORT_ROLE_WIDTH=3;
  logic aclk=0,aresetn=0;
  logic [0:BANK_NUM-1] acquire_valid='0,release_valid='0;
  logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] acquire_port='0,release_port='0;
  logic [0:BANK_NUM-1] bank_busy;
  logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_owner_port;
  logic ownership_error; logic [2:0] ownership_error_code;
  integer failures=0;
  bank_ownership_table #(.BANK_NUM(BANK_NUM),.PORT_ROLE_WIDTH(PORT_ROLE_WIDTH)) dut(.*);
  always #2.5 aclk=~aclk;
  task automatic check(input logic ok,input string why);
    if(!ok) begin $error("FAIL %s",why); failures=failures+1; end
  endtask
  task automatic reset;
    begin @(negedge aclk); aresetn=0; acquire_valid='0;release_valid='0;
      repeat(2) @(posedge aclk); @(negedge aclk); aresetn=1; @(posedge aclk); #1;
      check(bank_busy=='0 && bank_owner_port=='0 && !ownership_error,"reset clears all"); end
  endtask
  initial begin
    reset();
    $display("CASE bank0");
    @(negedge aclk); acquire_valid[0]=1; acquire_port[0]=1; @(posedge aclk); #1;
    check(bank_busy[0] && bank_owner_port[0]==1,"bank0 acquire");
    @(negedge aclk); acquire_valid='0; release_valid[0]=1; release_port[0]=1; @(posedge aclk); #1;
    check(!bank_busy[0] && bank_owner_port[0]==0,"bank0 matching release");

    reset(); $display("CASE gemm_three_bank_atomic");
    @(negedge aclk); acquire_valid[1]=1;acquire_port[1]=3;
    acquire_valid[2]=1;acquire_port[2]=4;acquire_valid[3]=1;acquire_port[3]=5;
    @(posedge aclk); #1; check(bank_busy[1]&&bank_busy[2]&&bank_busy[3],"three busy");
    check(bank_owner_port[1]==3&&bank_owner_port[2]==4&&bank_owner_port[3]==5,"GEMM roles");

    $display("CASE busy_operand_rejects_all");
    @(negedge aclk); acquire_valid='0;acquire_port='0;acquire_valid[3]=1;acquire_port[3]=3;
    acquire_valid[4]=1;acquire_port[4]=4;acquire_valid[5]=1;acquire_port[5]=5;
    @(posedge aclk); #1; check(!bank_busy[4]&&!bank_busy[5],"atomic acquire rejection");
    check(ownership_error&&ownership_error_code==1,"acquire conflict code");

    reset(); @(negedge aclk); acquire_valid[1]=1;acquire_port[1]=3;
    acquire_valid[2]=1;acquire_port[2]=3; @(posedge aclk); #1;
    check(bank_owner_port[1]==3&&bank_owner_port[2]==3,"same role may own different banks");
    $display("CASE mismatching_release_atomic");
    @(negedge aclk); acquire_valid='0;release_valid[1]=1;release_port[1]=4;
    release_valid[2]=1;release_port[2]=3; @(posedge aclk); #1;
    check(bank_busy[1]&&bank_busy[2],"mismatch preserves entire release");
    check(ownership_error&&ownership_error_code==3,"release mismatch code");

    reset(); @(negedge aclk); acquire_valid[1]=1;acquire_port[1]=1; @(posedge aclk);
    $display("CASE disjoint_release_acquire");
    @(negedge aclk); acquire_valid='0;release_valid='0;release_valid[1]=1;release_port[1]=1;
    acquire_valid[2]=1;acquire_port[2]=2; @(posedge aclk); #1;
    check(!bank_busy[1]&&bank_busy[2]&&bank_owner_port[2]==2,"disjoint simultaneous commit");

    $display("CASE overlap_no_state_change");
    @(negedge aclk); acquire_valid='0;release_valid='0;acquire_valid[2]=1;acquire_port[2]=4;
    release_valid[2]=1;release_port[2]=2; @(posedge aclk); #1;
    check(bank_busy[2]&&bank_owner_port[2]==2,"overlap preserves state");
    check(ownership_error&&ownership_error_code==4,"overlap code");

    reset(); $display("CASE free_release");
    @(negedge aclk); release_valid[7]=1;release_port[7]=1; @(posedge aclk); #1;
    check(!bank_busy[7]&&ownership_error&&ownership_error_code==2,"free release fault");

    if(failures==0) begin $display("PASS: bank_ownership_table verification cases=8");$finish;end
    $fatal(1,"failures=%0d",failures);
  end
endmodule
