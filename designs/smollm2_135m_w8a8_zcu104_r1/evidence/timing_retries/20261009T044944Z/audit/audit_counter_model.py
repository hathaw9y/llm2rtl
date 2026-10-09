import json
from pathlib import Path
E=Path(__file__).resolve().parent;checked=0
# Independent integer recurrence vs original div/mod equations, all distinct P padded widths.
for mode,widths,heads in [(0,[576,1536],1),(1,[576],9),(2,[192],3),(3,[192],3),(4,[9*p for p in range(16,1025,16)],9)]:
 for width in widths:
  for rows in [1,16,17,32]:
   r=col=head=feature=0;groups=(rows+15)//16
   for elem in range(0,rows*width,4):
    er,ef=divmod(elem,width);hf=width//9 if mode==4 else 64
    assert r==er and col==ef
    if mode!=0:assert head==ef//hf and feature==ef%hf
    got=r//16 if mode==0 else head*groups+r//16 if mode in[1,4] else head if mode==2 else col//16
    for j in range(4):
     rr,ff=divmod(elem+j,width);expected=rr//16 if mode==0 else (ff//hf)*groups+rr//16 if mode in[1,4] else ff//64 if mode==2 else ff//16
     assert got==expected;checked+=1
    if col+4==width:r+=1;col=head=feature=0
    else:
     col+=4
     if feature+4==hf:feature=0;head=(head+1)&15
     else:feature+=4
# Independent GEMM request/response traversal equivalence, valid dense/QK/PV row and head counts.
for rows in range(1,33):
 for stride in [1,2,18,32,48]:
  for attention in[False,True]:
   row=token=head=chunk=0
   for index in range(rows*(3 if attention else 1)*stride):
    assert row==index//stride and chunk==index%stride and token==row%rows and head==row//rows;checked+=1
    if chunk+1==stride:
     chunk=0;row+=1
     if token+1==rows:token=0;head+=1
     else:token+=1
    else:chunk+=1
(E/'counter_model.json').write_text(json.dumps({'status':'PASS','integer_equivalence_points':checked,'scope':'Independent recurrence arithmetic against baseline div/mod formulas; model evidence complements actual frozen RTL simulation, not formal RTL equivalence'},indent=2)+'\n');print('COUNTER_MODEL_PASS',checked)
