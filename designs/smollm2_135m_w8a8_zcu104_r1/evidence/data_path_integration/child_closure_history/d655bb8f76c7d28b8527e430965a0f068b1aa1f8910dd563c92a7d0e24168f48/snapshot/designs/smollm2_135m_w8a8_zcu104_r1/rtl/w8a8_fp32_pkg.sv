package w8a8_fp32_pkg;
  function automatic logic [31:0] int32_to_fp32(input logic [31:0] x);
    logic [31:0] mag; logic [32:0] ext; logic [24:0] q;
    logic guard_bit, sticky_bit; integer p, shift_count, k; logic [7:0] exponent;
    begin
      mag = x[31] ? (~x + 32'd1) : x;
      p=0; for(k=0;k<32;k=k+1) if(mag[k]) p=k;
      q=0; guard_bit=0; sticky_bit=0; ext={1'b0,mag};
      if(p<=23) q=25'(mag << (23-p));
      else begin
        shift_count=p-23; q=25'(ext >> shift_count);
        guard_bit=mag[shift_count-1];
        for(k=0;k<32;k=k+1) if(k<shift_count-1) sticky_bit=sticky_bit|mag[k];
        q=q+{24'd0,(guard_bit & (sticky_bit|q[0]))};
      end
      if(q[24]) begin q=q>>1; p=p+1; end
      exponent=8'(p+127);
      int32_to_fp32=(mag==0)?32'd0:{x[31],exponent,q[22:0]};
    end
  endfunction
  function automatic logic [15:0] fp32_to_bf16(input logic [31:0] x);
    logic [15:0] upper;
    begin
      upper=x[31:16];
      if(x[30:23]!=8'hff) upper=upper+{15'd0,(x[15] & ((|x[14:0])|upper[0]))};
      fp32_to_bf16=upper;
    end
  endfunction
endpackage
