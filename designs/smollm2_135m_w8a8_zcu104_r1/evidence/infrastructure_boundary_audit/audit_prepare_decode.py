#!/usr/bin/env python3
"""Generate static RTL decode comparison, separate from dynamic integration."""
import json,pathlib,re
h=pathlib.Path(__file__).resolve().parent;d=h.parents[1]
corpus=json.loads((d/'evidence/infrastructure_wave/isa_decode_vectors.json').read_text())['cases']
(h/'audit_decode.hex').write_text(''.join(f'{(int(c["expect_issue_or_control_accept"])<<128)|int(c["hex128"],16):033x}\n' for c in corpus))
header=(d/'rtl/smollm2_isa_dispatcher.sv').read_text().split(');',1)[0]
ports=re.findall(r'(input|output)\s+logic\s*(\[[^\]]+\])?\s*(\w+)',header)
decl='\n'.join(f'logic {w or ""} {n};' for direction,w,n in ports)
init='\n'.join(f'{n}=0;' for direction,w,n in ports if direction=='input')
connections=',\n'.join(f'.{n}({n})' for direction,w,n in ports)
tb=f'''`timescale 1ns/1ps
module audit_decode_tb;
{decl}
logic [128:0] vectors[0:{len(corpus)-1}];
logic [127:0] record;
int checked=0;
smollm2_isa_dispatcher dut({connections});
initial begin
{init}
$readmemh("audit_decode.hex",vectors);
for(int i=0;i<{len(corpus)};i++)begin
 record=vectors[i][127:0];force dut.record_r=record;#1;
 if((dut.static_error_w==0)!==vectors[i][128])$fatal(1,"static mismatch index%0d record%032h expected%0b error%0h",i,record,vectors[i][128],dut.static_error_w);
 release dut.record_r;checked++;
end
$display("AUDIT_STATIC_DECODE_PASS checked=%0d",checked);$finish;
end
endmodule
'''
(h/'audit_decode_tb.sv').write_text(tb)
print(len(corpus))
