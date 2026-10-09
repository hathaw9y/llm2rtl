"""Compare bare-metal C control compiler bytes against Python ISA lowering.
No tensor dependency; streaming comparison avoids storing full maximum program.
"""
import argparse,json,hashlib,subprocess,struct,time
from pathlib import Path
from compiler import Compiler
BASE=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--run',default='ps_compiler_run002');args=parser.parse_args()
 out=BASE/'evidence'/args.run;out.mkdir(exist_ok=False)
 mem=json.loads((BASE/'evidence/isa_small_run002/DDR_layout.json').read_text())
 def w(name):
  x=mem['weights'][name];return '{'+','.join(f'.{k}={x.get(k,0)}u' for k in ('codes','scales','bias','n','k'))+'}'
 text='static const qwen_memory memory={.embedding='+w('model.embed_tokens.weight')+',.layers={\n'
 for i in range(24):
  p=f'model.layers.{i}.'
  fields=[f'.{x}='+w(p+'self_attn.'+x+'_proj.weight') for x in ('q','k','v','o')]
  fields +=[f'.{x}='+w(p+'mlp.'+x+'_proj.weight') for x in ('gate','up','down')]
  fields +=[f'.norm1={mem["parameters"][p+"input_layernorm.weight"]}u',f'.norm2={mem["parameters"][p+"post_attention_layernorm.weight"]}u']
  fields +=['.kv={{'+','.join(str(mem['KV'][f'{i}.K.{h}'])+'u' for h in range(2))+'},{'+','.join(str(mem['KV'][f'{i}.V.{h}'])+'u' for h in range(2))+'}}']
  text+='{'+','.join(fields)+'},\n'
 text+='},'+','.join(f'.{k}={mem[k]}u' for k in ('embedding_codes','embedding_scales','rope','logits'))+f',.norm={mem["parameters"]["model.norm.weight"]}u'+'};\n'
 (out/'memory.h').write_text(text)
 (out/'runner.c').write_text('''#include "qwen_isa.h"
#include <stdio.h>
#include <stdlib.h>
#include "memory.h"
static int submit(void *ctx,const uint8_t *data,size_t records){(void)ctx;uint32_t n=(uint32_t)records;return fwrite(&n,4,1,stdout)==1 && fwrite(data,32,records,stdout)==records?0:-10;}
static qwen_compiler compiler;
int main(int argc,char **argv){if(argc!=4)return 1;unsigned n=(unsigned)atoi(argv[1]),prefix=(unsigned)atoi(argv[2]);int decode=atoi(argv[3]);uint32_t t[512];if(n>512)return 2;for(unsigned i=0;i<n;i++)t[i]=(uint32_t[]){9707,11,151643}[i%3];qwen_compiler_init(&compiler,&memory,submit,0);return qwen_compile(&compiler,t,n,(uint16_t)prefix,decode)?3:0;}
''')
 exe=out/'runner';subprocess.run(['gcc','-std=c11','-O2','-Wall','-Wextra','-Werror','-I'+str(BASE/'software'),str(out/'runner.c'),str(BASE/'software/qwen_isa.c'),'-o',str(exe)],check=True)
 results=[]
 for n,p,d in [(1,0,0),(2,0,0),(17,0,0),(512,0,0),(1,2,1),(1,1023,1)]:
  started=time.monotonic();proc=subprocess.Popen([str(exe),str(n),str(p),str(d)],stdout=subprocess.PIPE);digest=hashlib.sha256();chunks=0;commands=0
  for expected in Compiler(mem).chunks(([9707,11,151643]*171)[:n],p,'decode' if d else 'prefill'):
   header=proc.stdout.read(4)
   if len(header)!=4:raise RuntimeError('C stream stopped early')
   count=struct.unpack('<I',header)[0];raw=proc.stdout.read(count*32);gold=b''.join(c.encode() for c in expected)
   if raw!=gold:raise AssertionError(f'C byte/chunk mismatch n{n} prefix{p} chunk{chunks}')
   digest.update(header);digest.update(raw);chunks+=1;commands+=count-1
  if proc.stdout.read(1) or proc.wait()!=0:raise RuntimeError('C stream extra/failed')
  results.append(dict(input_count=n,prefix=p,decode=bool(d),chunks=chunks,commands=commands,sha256=digest.hexdigest(),seconds=time.monotonic()-started,status='passed_bit_exact_command_images'))
  print(results[-1],flush=True)
 for args in [('0','0','0'),('513','0','0'),('2','0','1'),('1','1024','1'),('1','1','0')]:
  proc=subprocess.run([str(exe),*args],stdout=subprocess.PIPE)
  if not proc.returncode or proc.stdout:raise AssertionError('scope rejection')
 report={'status':'passed_control_compiler_only','results':results,'scope':'Host C executable and Python compiler produce identical complete END-ended images, including DDR barriers. No PS runtime or RTL execution claim.','source_sha256':{str(p.relative_to(BASE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [BASE/'software/qwen_isa.c',BASE/'software/qwen_isa.h',BASE/'python/compiler.py',BASE/'python/isa.py']}}
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
