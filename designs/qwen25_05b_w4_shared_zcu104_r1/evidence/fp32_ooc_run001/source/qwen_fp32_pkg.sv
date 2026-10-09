package qwen_fp32_pkg;
  // Finite binary32 add/multiply, RNE, input/output FTZ. No FMA.
  function automatic logic [31:0] fp_mul(input logic [31:0] a,b);
    logic sign;
    logic [23:0] ma,mb;
    logic [47:0] p;
    logic [24:0] rounded;
    logic guard_bit,sticky;
    integer exponent,shift;
    sign=a[31]^b[31]; ma={1'b1,a[22:0]};mb={1'b1,b[22:0]};
    p=ma*mb;exponent=int'({1'b0,a[30:23]})+int'({1'b0,b[30:23]})-127;
    shift=p[47]?24:23;
    if(p[47]) exponent=exponent+1;
    if(a[30:23]==255 || b[30:23]==255) return 32'h7fc00000;
    if(a[30:23]==0 || b[30:23]==0) return {sign,31'b0};
    if(exponent<0) return {sign,31'b0};
    if(exponent==0) shift=shift+1;
    rounded=25'(p>>shift);guard_bit=p[shift-1];sticky=1'b0;
    for(integer i=0;i<48;i=i+1) if(i<shift-1) sticky=sticky|p[i];
    if(guard_bit && (sticky || rounded[0])) rounded=rounded+1'b1;
    if(exponent==0) begin
      if(rounded[23]) return {sign,8'd1,23'b0};
      return {sign,31'b0};
    end
    if(rounded[24]) begin rounded=rounded>>1;exponent=exponent+1;end
    if(exponent>=255) return {sign,8'hff,23'b0};
    return {sign,8'(exponent),rounded[22:0]};
  endfunction

  function automatic logic [31:0] fp_add(input logic [31:0] a,b);
    logic [23:0] ma,mb,big_m,small_m;
    logic [26:0] big_x,small_x;
    logic [27:0] sum;
    logic [24:0] rounded;
    logic sa,sb,sign,sticky,guard_bit;
    integer ea,eb,exponent,difference;
    sa=a[31];sb=b[31];ea=int'({1'b0,a[30:23]});eb=int'({1'b0,b[30:23]});
    ma=ea==0?24'b0:{1'b1,a[22:0]};mb=eb==0?24'b0:{1'b1,b[22:0]};
    if(ea==255 || eb==255) return 32'h7fc00000;
    if(ea>eb || (ea==eb && ma>=mb)) begin
      big_m=ma;small_m=mb;sign=sa;exponent=ea;difference=ea-eb;
    end else begin
      big_m=mb;small_m=ma;sign=sb;exponent=eb;difference=eb-ea;
    end
    big_x={big_m,3'b0};small_x={small_m,3'b0};sticky=1'b0;
    for(integer i=0;i<27;i=i+1) if(i<difference) sticky=sticky|small_x[i];
    small_x=difference>=27?27'b0:small_x>>difference;
    small_x[0]=small_x[0]|sticky;
    if(sa==sb) sum={1'b0,big_x}+{1'b0,small_x};
    else sum={1'b0,big_x}-{1'b0,small_x};
    if(sum==0) return {(sa&sb),31'b0};
    if(sum[27]) begin
      sticky=sum[0];sum=sum>>1;sum[0]=sum[0]|sticky;exponent=exponent+1;
    end
    for(integer i=0;i<26;i=i+1) begin
      if(!sum[26] && exponent>0) begin sum=sum<<1;exponent=exponent-1;end
    end
    if(exponent<=0) return {sign,31'b0};
    rounded={1'b0,sum[26:3]};guard_bit=sum[2];sticky=sum[1]|sum[0];
    if(guard_bit && (sticky || rounded[0])) rounded=rounded+1'b1;
    if(rounded[24]) begin rounded=rounded>>1;exponent=exponent+1;end
    if(exponent>=255) return {sign,8'hff,23'b0};
    return {sign,8'(exponent),rounded[22:0]};
  endfunction

  function automatic logic [15:0] to_bf16(input logic [31:0] x);
    logic [31:0] rounded;
    if(x[30:23]==255) return x[31:16];
    rounded=x+32'h00007fff+32'(x[16]);
    if(rounded[30:23]==0) return {rounded[31],15'b0};
    return rounded[31:16];
  endfunction
  function automatic logic [31:0] from_bf16(input logic [15:0] x);
    if(x[14:7]==0) return {x[15],31'b0};
    return {x,16'b0};
  endfunction
endpackage
