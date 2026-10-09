`timescale 1ns/1ps

module tb_memory_banks;
  localparam integer LAT = 3;
  logic aclk = 1'b0;
  logic aresetn = 1'b0;
  integer failures = 0;
  integer k;
  integer s_read_count = 0, a_read_count = 0, u_read_count = 0;

  logic s_ena=0,s_enb=0; logic [15:0] s_wea='0;
  logic [5:0] s_addra='0,s_addrb='0; logic [127:0] s_dina='0,s_doutb;
  logic a_ena=0,a_enb=0; logic [15:0] a_wea='0;
  logic [5:0] a_addra='0,a_addrb='0; logic [127:0] a_dina='0; logic [31:0] a_doutb;
  logic u_ena=0,u_enb=0; logic [15:0] u_wea='0;
  logic [5:0] u_addra='0,u_addrb='0; logic [127:0] u_dina='0,u_doutb;

  bram_bank #(.WRITE_DATA_WIDTH(128),.WRITE_DEPTH(16),.READ_DATA_WIDTH(128),
    .BYTE_WRITE_WIDTH(8),.READ_LATENCY(LAT),.ADDR_WIDTH(6)) symmetric (
    .aclk,.aresetn,.ena(s_ena),.wea(s_wea),.addra(s_addra),.dina(s_dina),
    .enb(s_enb),.addrb(s_addrb),.doutb(s_doutb));
  bram_bank #(.WRITE_DATA_WIDTH(128),.WRITE_DEPTH(4),.READ_DATA_WIDTH(32),
    .BYTE_WRITE_WIDTH(8),.READ_LATENCY(LAT),.ADDR_WIDTH(6)) asymmetric (
    .aclk,.aresetn,.ena(a_ena),.wea(a_wea),.addra(a_addra),.dina(a_dina),
    .enb(a_enb),.addrb(a_addrb),.doutb(a_doutb));
  uram_bank #(.DATA_WIDTH(128),.DEPTH(16),.READ_LATENCY(LAT),.ADDR_WIDTH(6)) ultra (
    .aclk,.aresetn,.ena(u_ena),.wea(u_wea),.addra(u_addra),.dina(u_dina),
    .enb(u_enb),.addrb(u_addrb),.doutb(u_doutb));

  always #2.5 aclk = ~aclk;

  task automatic check(input logic condition, input string description);
    if (!condition) begin
      $error("CHECK_FAILED: %s", description);
      failures = failures + 1;
    end
  endtask

  task automatic s_write(input logic [5:0] address,input logic [127:0] data,input logic [15:0] mask);
    @(negedge aclk); s_ena=1; s_addra=address; s_dina=data; s_wea=mask;
    @(posedge aclk); @(negedge aclk); s_ena=0; s_wea=0;
  endtask
  task automatic s_read(input logic [5:0] address,input logic [127:0] expected,input string description);
    logic output_already_equal;
    begin
      output_already_equal=(s_doutb===expected);
      @(negedge aclk); s_enb=1; s_addrb=address;
      for(k=1;k<=LAT;k=k+1) begin @(posedge aclk); #1;
        if(k<LAT && s_read_count==0 && !output_already_equal) check(s_doutb!==expected,{description," early latency"});
      end
      check(s_doutb===expected,description); s_read_count=s_read_count+1; @(negedge aclk); s_enb=0;
    end
  endtask
  task automatic a_write(input logic [5:0] address,input logic [127:0] data,input logic [15:0] mask);
    @(negedge aclk); a_ena=1; a_addra=address; a_dina=data; a_wea=mask;
    @(posedge aclk); @(negedge aclk); a_ena=0; a_wea=0;
  endtask
  task automatic a_read(input logic [5:0] address,input logic [31:0] expected,input string description);
    logic output_already_equal;
    begin
      output_already_equal=(a_doutb===expected);
      @(negedge aclk); a_enb=1; a_addrb=address;
      for(k=1;k<=LAT;k=k+1) begin @(posedge aclk); #1;
        if(k<LAT && a_read_count==0 && !output_already_equal) check(a_doutb!==expected,{description," early latency"});
      end
      check(a_doutb===expected,description); a_read_count=a_read_count+1; @(negedge aclk); a_enb=0;
    end
  endtask
  task automatic u_write(input logic [5:0] address,input logic [127:0] data,input logic [15:0] mask);
    @(negedge aclk); u_ena=1; u_addra=address; u_dina=data; u_wea=mask;
    @(posedge aclk); @(negedge aclk); u_ena=0; u_wea=0;
  endtask
  task automatic u_read(input logic [5:0] address,input logic [127:0] expected,input string description);
    logic output_already_equal;
    begin
      output_already_equal=(u_doutb===expected);
      @(negedge aclk); u_enb=1; u_addrb=address;
      for(k=1;k<=LAT;k=k+1) begin @(posedge aclk); #1;
        if(k<LAT && u_read_count==0 && !output_already_equal) check(u_doutb!==expected,{description," early latency"});
      end
      check(u_doutb===expected,description); u_read_count=u_read_count+1; @(negedge aclk); u_enb=0;
    end
  endtask

  initial begin
    repeat(3) @(posedge aclk); @(negedge aclk); aresetn=1;

    s_write(0,128'h00112233445566778899aabbccddeeff,16'hffff);
    s_write(15,128'hffeeddccbbaa99887766554433221100,16'hffff);
    s_read(0,128'h00112233445566778899aabbccddeeff,"BRAM symmetric first endpoint");
    s_read(15,128'hffeeddccbbaa99887766554433221100,"BRAM symmetric last endpoint");
    s_write(0,128'hffffeeee111122223333444455556666,16'h0005);
    s_read(0,128'h00112233445566778899aabbcc55ee66,"BRAM symmetric byte enables");

    a_write(0,128'h44444444333333332222222211111111,16'hffff);
    a_write(3,128'hddddddddccccccccbbbbbbbbaaaaaaaa,16'hffff);
    a_read(0,32'h11111111,"BRAM asymmetric lane 0");
    a_read(1,32'h22222222,"BRAM asymmetric lane 1");
    a_read(2,32'h33333333,"BRAM asymmetric lane 2");
    a_read(3,32'h44444444,"BRAM asymmetric lane 3");
    a_read(15,32'hdddddddd,"BRAM asymmetric last read endpoint");

    u_write(0,128'h0123456789abcdef0011223344556677,16'hffff);
    u_write(15,128'h8899aabbccddeeff7766554433221100,16'hffff);
    u_write(0,128'hffffffffffffffffffffffffffffaa55,16'h0003);
    u_read(0,128'h0123456789abcdef001122334455aa55,"URAM byte enables and first endpoint");
    u_read(15,128'h8899aabbccddeeff7766554433221100,"URAM last endpoint");

    // Disabled read holds the current output.
    repeat(5) @(posedge aclk); #1;
    check(s_doutb===128'h00112233445566778899aabbcc55ee66,"BRAM disabled hold");
    check(u_doutb===128'h8899aabbccddeeff7766554433221100,"URAM disabled hold");

    // Read-first collision: the read returns the old word, then a later read returns the new word.
    @(negedge aclk); s_ena=1; s_enb=1; s_addra=15; s_addrb=15;
    s_dina=128'hcafebabedeadbeef0123456789abcdef; s_wea='1;
    repeat(LAT) @(posedge aclk); #1;
    check(s_doutb===128'hffeeddccbbaa99887766554433221100,"BRAM read-first collision");
    @(negedge aclk); s_ena=0; s_enb=0; s_wea=0;
    s_read(15,128'hcafebabedeadbeef0123456789abcdef,"BRAM post-collision new value");

    @(negedge aclk); u_ena=1; u_enb=1; u_addra=15; u_addrb=15;
    u_dina=128'hdeaddeaddeaddeaddeaddeaddeaddead; u_wea='1;
    repeat(LAT) @(posedge aclk); #1;
    check(u_doutb===128'h8899aabbccddeeff7766554433221100,"URAM read-first collision");
    @(negedge aclk); u_ena=0; u_enb=0; u_wea=0;
    u_read(15,128'hdeaddeaddeaddeaddeaddeaddeaddead,"URAM post-collision new value");

    // Reset clears the output pipeline only; previously written memory remains readable.
    @(negedge aclk); aresetn=0; repeat(2) @(posedge aclk); #1;
    check(s_doutb==='0 && a_doutb==='0 && u_doutb==='0,"reset clears outputs");
    @(negedge aclk); aresetn=1;
    s_read(15,128'hcafebabedeadbeef0123456789abcdef,"BRAM memory retained across reset");
    u_read(15,128'hdeaddeaddeaddeaddeaddeaddeaddead,"URAM memory retained across reset");

    // Invalid accesses intentionally emit six wrapper errors and must not change memory/output.
    s_write(16,128'h0,16'hffff); a_write(4,128'h0,16'hffff); u_write(16,128'h0,16'hffff);
    @(negedge aclk); s_enb=1; s_addrb=16; a_enb=1; a_addrb=16; u_enb=1; u_addrb=16;
    @(posedge aclk); #1; @(negedge aclk); s_enb=0; a_enb=0; u_enb=0;
    repeat(LAT) @(posedge aclk); #1;
    check(s_doutb===128'hcafebabedeadbeef0123456789abcdef,"BRAM invalid read holds output");
    check(a_doutb===32'hdddddddd,"asymmetric invalid read holds output");
    check(u_doutb===128'hdeaddeaddeaddeaddeaddeaddeaddead,"URAM invalid read holds output");
    s_read(15,128'hcafebabedeadbeef0123456789abcdef,"BRAM invalid write suppressed");
    a_read(15,32'hdddddddd,"asymmetric invalid write suppressed");
    u_read(15,128'hdeaddeaddeaddeaddeaddeaddeaddead,"URAM invalid write suppressed");

    if(failures==0) begin
      $display("PASS: memory bank XPM functional verification"); $finish;
    end
    $fatal(1,"memory bank failures=%0d",failures);
  end
endmodule
