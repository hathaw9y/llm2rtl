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

  typedef struct packed {
    logic invalid,sign,zero_sign,same_sign;
    logic [8:0] exponent;
    logic [26:0] big_x,small_x;
  } add_align_t;
  typedef struct packed {
    logic invalid,sign,zero_sign;
    logic [8:0] exponent;
    logic [26:0] magnitude;
  } add_sum_t;
  typedef struct packed {
    logic invalid,sign,zero_sign;
    logic [8:0] exponent;
    logic [26:0] magnitude;
  } add_norm_t;
  typedef struct packed {
    logic invalid,zero,sign;
    logic signed [9:0] exponent;
    logic [47:0] product;
  } mul_product_t;
  typedef struct packed {
    logic invalid,zero,sign,guard_bit,sticky;
    logic signed [9:0] exponent;
    logic [23:0] mantissa;
  } mul_norm_t;

  function automatic add_align_t add_align(input logic [31:0] a,b);
    add_align_t r;
    logic [23:0] ma,mb;
    logic [7:0] difference;
    logic sticky;
    logic [26:0] small_raw;
    r='0;ma=a[30:23]==0?24'b0:{1'b1,a[22:0]};mb=b[30:23]==0?24'b0:{1'b1,b[22:0]};
    r.invalid=a[30:23]==255 || b[30:23]==255;
    r.zero_sign=a[31]&b[31];r.same_sign=a[31]==b[31];
    if(a[30:23]>b[30:23] || (a[30:23]==b[30:23] && ma>=mb)) begin
      r.big_x={ma,3'b0};r.small_x={mb,3'b0};r.sign=a[31];r.exponent={1'b0,a[30:23]};difference=a[30:23]-b[30:23];
    end else begin
      r.big_x={mb,3'b0};r.small_x={ma,3'b0};r.sign=b[31];r.exponent={1'b0,b[30:23]};difference=b[30:23]-a[30:23];
    end
    sticky=0;small_raw=r.small_x;
    for(integer i=0;i<27;i=i+1) if(8'(i)<difference) sticky=sticky|small_raw[i];
    r.small_x=difference>=27?27'b0:r.small_x>>difference[4:0];r.small_x[0]=r.small_x[0]|sticky;
    return r;
  endfunction
  function automatic add_sum_t add_sum(input add_align_t a);
    add_sum_t r;logic [27:0] total;
    r.invalid=a.invalid;r.sign=a.sign;r.zero_sign=a.zero_sign;r.exponent=a.exponent;
    total=a.same_sign?{1'b0,a.big_x}+{1'b0,a.small_x}:{1'b0,a.big_x}-{1'b0,a.small_x};
    if(total[27]) begin r.magnitude=total[27:1];r.magnitude[0]=r.magnitude[0]|total[0];r.exponent=a.exponent+1'b1;end
    else r.magnitude=total[26:0];
    return r;
  endfunction
  function automatic logic [4:0] leading_zeros27(input logic [26:0] x);
    logic [31:0] v;logic [4:0] count;
    v={x,5'b0};count=0;
    if(v[31:16]==0) begin count=count+16;v=v<<16;end
    if(v[31:24]==0) begin count=count+8;v=v<<8;end
    if(v[31:28]==0) begin count=count+4;v=v<<4;end
    if(v[31:30]==0) begin count=count+2;v=v<<2;end
    if(!v[31]) count=count+1;
    return count;
  endfunction
  function automatic add_norm_t add_normalize(input add_sum_t a);
    add_norm_t r;logic [4:0] shift;
    r.invalid=a.invalid;r.sign=a.sign;r.zero_sign=a.zero_sign;
    shift=leading_zeros27(a.magnitude);
    if(a.exponent<{4'b0,shift}) shift=a.exponent[4:0];
    r.magnitude=a.magnitude<<shift;r.exponent=a.exponent-{4'b0,shift};
    return r;
  endfunction
  function automatic logic [31:0] add_round(input add_norm_t a);
    logic [24:0] rounded;logic [8:0] exponent;
    if(a.invalid) return 32'h7fc00000;
    if(a.magnitude==0) return {a.zero_sign,31'b0};
    if(a.exponent==0) return {a.sign,31'b0};
    rounded={1'b0,a.magnitude[26:3]};exponent=a.exponent;
    if(a.magnitude[2] && (a.magnitude[1] || a.magnitude[0] || rounded[0])) rounded=rounded+1'b1;
    if(rounded[24]) begin rounded=rounded>>1;exponent=exponent+1'b1;end
    if(exponent>=255) return {a.sign,8'hff,23'b0};
    return {a.sign,exponent[7:0],rounded[22:0]};
  endfunction
  function automatic mul_product_t mul_product(input logic [31:0] a,b);
    mul_product_t r;
    r.invalid=a[30:23]==255 || b[30:23]==255;r.zero=a[30:23]==0 || b[30:23]==0;r.sign=a[31]^b[31];
    r.exponent=$signed({2'b0,a[30:23]})+$signed({2'b0,b[30:23]})-10'sd127;
    r.product={1'b1,a[22:0]}*{1'b1,b[22:0]};
    return r;
  endfunction
  function automatic mul_norm_t mul_normalize(input mul_product_t a);
    mul_norm_t r;
    r.invalid=a.invalid;r.zero=a.zero;r.sign=a.sign;r.exponent=a.exponent+(a.product[47]?10'sd1:10'sd0);
    if(r.exponent==0) begin
      if(a.product[47]) begin r.mantissa={1'b0,a.product[47:25]};r.guard_bit=a.product[24];r.sticky=|a.product[23:0];end
      else begin r.mantissa=a.product[47:24];r.guard_bit=a.product[23];r.sticky=|a.product[22:0];end
    end else begin
      if(a.product[47]) begin r.mantissa=a.product[47:24];r.guard_bit=a.product[23];r.sticky=|a.product[22:0];end
      else begin r.mantissa=a.product[46:23];r.guard_bit=a.product[22];r.sticky=|a.product[21:0];end
    end
    return r;
  endfunction
  function automatic logic [31:0] mul_round(input mul_norm_t a);
    logic [24:0] rounded;logic signed [9:0] exponent;
    if(a.invalid) return 32'h7fc00000;
    if(a.zero || a.exponent<0) return {a.sign,31'b0};
    rounded={1'b0,a.mantissa};exponent=a.exponent;
    if(a.guard_bit && (a.sticky || rounded[0])) rounded=rounded+1'b1;
    if(exponent==0) begin
      if(rounded[23]) return {a.sign,8'd1,23'b0};
      return {a.sign,31'b0};
    end
    if(rounded[24]) begin rounded=rounded>>1;exponent=exponent+1'b1;end
    if(exponent>=255) return {a.sign,8'hff,23'b0};
    return {a.sign,exponent[7:0],rounded[22:0]};
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
