from pathlib import Path
from isa import *
BASE=Path(__file__).resolve().parents[1]
def main():
 out=BASE/'evidence/descriptor_run001';out.mkdir(exist_ok=True);x=[]
 def load(bank,m,n,fmt,uid,btt):x.append(command('DMA_LOAD',a=bank,m=m if m<32 else 0,extent_n=m if m>=32 else 0,n=n,mode=fmt,tensor=uid,btt=btt,address=0x10000000,flags=BEGIN|FINAL))
 for bank,m,n,fmt,u,btt in [(6,1,128,1,10,256),(7,128,128,3,11,8192),(8,1,128,2,12,512)]:load(bank,m,n,fmt,u,btt)
 x.append(command('GEMM',a=6,b=7,c=11,scale=8,m=1,n=128,k=128,tensor=13,group=0,flags=INIT|LAST_A|LAST_B|LAST_SCALE))
 for bank,m,n,fmt,u,btt in [(6,1,128,1,14,256),(7,128,128,3,15,8192),(8,1,128,2,16,512)]:load(bank,m,n,fmt,u,btt)
 x.append(command('GEMM',a=6,b=7,c=11,scale=8,m=1,n=128,k=128,tensor=13,group=1,flags=ACCUM|FINAL|LAST_A|LAST_B|LAST_SCALE))
 x.append(command('GEMM',a=6,b=7,c=11,scale=8,m=1,n=128,k=128,tensor=20,group=0,flags=INIT|FINAL|LAST_A|LAST_B|LAST_SCALE))
 x.append(command('VECTOR',a=11,c=19,m=1,n=128,mode=VEC['CAST'],tensor=23,flags=LAST_A))
 for col in range(0,896,128):x.append(command('VECTOR',a=19,c=0,m=1,n=128,mode=VEC['LAYOUT'],extent_m=1,extent_n=896,col=col,tensor=24,flags=INSERT|(BEGIN if col==0 else 0)|(FINAL|LAST_A if col==768 else 0)))
 x.append(Command());(out/'commands.mem').write_text(''.join(f'{int.from_bytes(c.encode(),"little"):064x}\n' for c in x))
if __name__=='__main__':main()
