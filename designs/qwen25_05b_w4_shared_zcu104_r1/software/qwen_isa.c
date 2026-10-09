#include "qwen_isa.h"
#include <string.h>
enum {INIT=1,ACCUM=2,LAST_A=4,LAST_B=8,LAST_S=16,FINAL=32,BEGIN=64,INSERT=128};
typedef struct {
 uint32_t opcode,a,b,c,offset,btt,address,mode,flags,scale,m,n,k,row,col,position,head,tensor,layout,src_layout,group,extent_m,extent_n;
} command;
static void bits(uint8_t out[32],uint32_t v,unsigned off,unsigned width){
 for(unsigned i=0;i<width;i++) if((v>>i)&1u)out[(off+i)/8]|=(uint8_t)(1u<<((off+i)%8));
}
static uint16_t uid(qwen_compiler *p){p->serial=(uint16_t)(p->serial==65535?1:p->serial+1);return p->serial;}
static void flush(qwen_compiler *p){
 if(p->error || !p->count)return;
 memset(p->image[p->count],0,32);
 p->error=p->submit(p->context,&p->image[0][0],p->count+1);
 p->chunks++;p->count=0;p->store_count=0;
}
static void emit(qwen_compiler *p,command c){
 if(p->error)return;
 if(c.opcode==1)for(unsigned i=0;i<p->store_count;i++){
  if(c.address<p->stores[i][1] && p->stores[i][0]<c.address+c.btt){flush(p);break;}
 }
 if(p->count==1023)flush(p);
 if(p->error)return;
 uint8_t *out=p->image[p->count++];memset(out,0,32);
 #define F(name,off,w) bits(out,c.name,off,w)
 F(opcode,252,4);F(a,247,5);F(b,242,5);F(c,237,5);F(offset,205,32);F(btt,182,23);F(address,150,32);
 F(mode,146,4);F(flags,138,8);F(scale,133,5);F(m,128,5);F(n,117,11);F(k,106,11);F(row,95,11);F(col,82,13);
 F(position,71,11);F(head,67,4);F(tensor,51,16);F(layout,47,4);F(src_layout,43,4);F(group,37,6);F(extent_m,32,5);F(extent_n,19,13);
 #undef F
 p->commands++;
 if(c.opcode==2){p->stores[p->store_count][0]=c.address;p->stores[p->store_count++][1]=c.address+c.btt;}
}
static void load(qwen_compiler *p,unsigned bank,uint32_t address,unsigned m,unsigned n,unsigned fmt,unsigned id,unsigned layout,unsigned offset,unsigned btt,unsigned flags){
 if(!btt){unsigned rowbytes=fmt==1?n*2:fmt==2?n*4:n/2;rowbytes=(rowbytes+15)&~15u;if(layout)rowbytes=1024*(fmt==1?2:4);btt=m*rowbytes;}
 if(!id)id=uid(p);
 emit(p,(command){.opcode=1,.a=bank,.address=address,.m=m<32?m:0,.n=n,.mode=fmt,.tensor=id,.layout=layout,.offset=offset,.btt=btt,.flags=flags,.extent_n=m>=32?m:0});
}
static void simple_load(qwen_compiler *p,unsigned bank,uint32_t address,unsigned m,unsigned n,unsigned fmt){load(p,bank,address,m,n,fmt,0,0,0,0,BEGIN|FINAL);}
static void extract(qwen_compiler *p,unsigned a,unsigned c,unsigned m,unsigned n,unsigned row,unsigned col,int last){emit(p,(command){.opcode=7,.a=a,.c=c,.m=m,.n=n,.row=row,.col=col,.mode=5,.flags=last?LAST_A:0,.tensor=uid(p)});}
static void cast(qwen_compiler *p,unsigned a,unsigned c,unsigned m,unsigned n){emit(p,(command){.opcode=7,.a=a,.c=c,.m=m,.n=n,.mode=4,.flags=LAST_A,.tensor=uid(p)});}
static void insert(qwen_compiler *p,unsigned a,unsigned c,unsigned m,unsigned n,unsigned total,unsigned col,unsigned id,int first,int last){emit(p,(command){.opcode=7,.a=a,.c=c,.m=m,.n=n,.col=col,.extent_m=m,.extent_n=total,.tensor=id,.mode=5,.flags=INSERT|LAST_A|(first?BEGIN:0)|(last?FINAL:0)});}
static void weight(qwen_compiler *p,const qwen_weight *w,unsigned nt,unsigned kt){unsigned slot=nt*(w->k/128)+kt;simple_load(p,7,w->codes+slot*8192,128,128,3);simple_load(p,8,w->scales+slot*512,1,128,2);}
static void linear(qwen_compiler *p,unsigned src,const qwen_weight *w,unsigned m,unsigned nt,unsigned dst,unsigned id,int release){
 unsigned groups=w->k/128;
 for(unsigned kt=0;kt<groups;kt++){
  extract(p,src,6,m,128,0,kt*128,release && kt==groups-1);weight(p,w,nt,kt);
  emit(p,(command){.opcode=3,.a=6,.b=7,.c=dst,.scale=8,.m=m,.n=128,.k=128,.tensor=id,.group=kt,.flags=(kt?ACCUM:INIT)|LAST_A|LAST_B|LAST_S|(kt==groups-1?FINAL:0)});
 }
}
static void projection(qwen_compiler *p,unsigned src,unsigned dst,const qwen_weight *w,unsigned m,int bias,int release){
 unsigned tiles=w->n/128,outid=uid(p);
 for(unsigned nt=0;nt<tiles;nt++){
  linear(p,src,w,m,nt,11,uid(p),release && nt==tiles-1);
  if(bias){simple_load(p,22,w->bias+nt*256,1,128,1);emit(p,(command){.opcode=7,.a=11,.b=22,.c=19,.m=m,.n=128,.mode=0,.flags=LAST_A|LAST_B,.tensor=uid(p)});}
  else cast(p,11,19,m,128);
  insert(p,19,dst,m,128,w->n,nt*128,outid,nt==0,nt==tiles-1);
 }
}
static void norm(qwen_compiler *p,unsigned src,unsigned dst,uint32_t address,unsigned m,int last){simple_load(p,22,address,1,896,1);emit(p,(command){.opcode=4,.a=src,.b=22,.c=dst,.m=m,.n=896,.flags=LAST_B|(last?LAST_A:0),.tensor=uid(p)});}
static void embeddings(qwen_compiler *p,const uint32_t *tokens,unsigned m){
 unsigned qid=uid(p),sid=uid(p);
 for(unsigned r=0;r<m;r++){
  unsigned flags=(r==0?BEGIN:0)|(r==m-1?FINAL:0);
  load(p,7,p->memory->embedding_codes+tokens[r]*448,m,896,3,qid,0,r*448,448,flags);
  load(p,8,p->memory->embedding_scales+tokens[r]*32,m,7,2,sid,0,r*32,32,flags);
 }
 emit(p,(command){.opcode=7,.a=7,.b=8,.c=0,.m=m,.n=896,.mode=3,.tensor=uid(p),.flags=LAST_A|LAST_B});
}
static void layer(qwen_compiler *p,const qwen_layer *l,unsigned m,unsigned pos){
 norm(p,0,1,l->norm1,m,0);projection(p,1,2,&l->q,m,1,0);projection(p,1,4,&l->k,m,1,0);projection(p,1,5,&l->v,m,1,1);
 simple_load(p,22,p->memory->rope+pos*256,m,128,1);
 emit(p,(command){.opcode=5,.a=2,.b=22,.c=3,.m=m,.n=14,.k=64,.tensor=uid(p),.flags=LAST_A});
 emit(p,(command){.opcode=5,.a=4,.b=22,.c=6,.m=m,.n=2,.k=64,.tensor=uid(p),.flags=LAST_A|LAST_B});
 extract(p,6,4,m,128,0,0,1);
 for(unsigned kind=0;kind<2;kind++)for(unsigned h=0;h<2;h++)for(unsigned r=0;r<m;r++)emit(p,(command){.opcode=2,.a=kind?5:4,.address=l->kv[kind][h]+(pos+r)*128,.offset=r*256+h*128,.btt=128,.mode=1,.m=m,.n=128,.flags=h==1 && r==m-1?LAST_A:0});
 unsigned length=pos+m,outid=uid(p);
 for(unsigned h=0;h<2;h++){
  simple_load(p,9,l->kv[0][h],length,64,1);simple_load(p,10,l->kv[1][h],length,64,1);
  for(unsigned local=0;local<7;local++){
   unsigned qh=h*7+local;extract(p,3,6,m,64,0,qh*64,qh==13);
   emit(p,(command){.opcode=3,.a=6,.b=9,.c=18,.m=m,.n=length,.k=64,.mode=1,.flags=INIT|FINAL|LAST_A|(local==6?LAST_B:0),.layout=1,.tensor=uid(p)});
   emit(p,(command){.opcode=6,.a=18,.c=21,.m=m,.n=length,.position=pos,.flags=LAST_A,.layout=1,.tensor=uid(p)});
   emit(p,(command){.opcode=3,.a=21,.b=10,.c=11,.m=m,.n=64,.k=length,.mode=2,.flags=INIT|FINAL|LAST_A|(local==6?LAST_B:0),.tensor=uid(p)});
   cast(p,11,19,m,64);insert(p,19,2,m,64,896,qh*64,outid,qh==0,qh==13);
  }
 }
 projection(p,2,1,&l->o,m,0,1);
 emit(p,(command){.opcode=7,.a=0,.b=1,.c=3,.m=m,.n=896,.mode=1,.flags=LAST_A|LAST_B,.tensor=uid(p)});
 norm(p,3,1,l->norm2,m,0);unsigned ps[7];for(unsigned i=0;i<7;i++)ps[i]=uid(p);
 for(unsigned kt=0;kt<38;kt++){
  linear(p,1,&l->gate,m,kt,18,uid(p),0);cast(p,18,19,m,128);
  linear(p,1,&l->up,m,kt,18,uid(p),kt==37);cast(p,18,20,m,128);
  emit(p,(command){.opcode=7,.a=19,.b=20,.c=6,.m=m,.n=128,.mode=2,.flags=LAST_A|LAST_B,.tensor=uid(p)});
  for(unsigned nt=0;nt<7;nt++){
   weight(p,&l->down,nt,kt);emit(p,(command){.opcode=3,.a=6,.b=7,.c=11+nt,.scale=8,.m=m,.n=128,.k=128,.group=kt,.flags=(kt?ACCUM:INIT)|LAST_B|LAST_S|(nt==6?LAST_A:0)|(kt==37?FINAL:0),.tensor=ps[nt]});
  }
 }
 outid=uid(p);for(unsigned nt=0;nt<7;nt++){cast(p,11+nt,19,m,128);insert(p,19,1,m,128,896,nt*128,outid,nt==0,nt==6);}
 emit(p,(command){.opcode=7,.a=3,.b=1,.c=0,.m=m,.n=896,.mode=1,.flags=LAST_A|LAST_B,.tensor=uid(p)});
}
static void logits(qwen_compiler *p,unsigned m){
 extract(p,0,2,1,896,m-1,0,1);norm(p,2,1,p->memory->norm,1,1);
 for(unsigned nt=0;nt<1187;nt++){
  linear(p,1,&p->memory->embedding,1,nt,11,uid(p),nt==1186);cast(p,11,19,1,128);
  emit(p,(command){.opcode=2,.a=19,.address=p->memory->logits+nt*256,.btt=256,.mode=1,.m=1,.n=128,.flags=LAST_A});
 }
}
void qwen_compiler_init(qwen_compiler *p,const qwen_memory *m,qwen_submit submit,void *ctx){memset(p,0,sizeof(*p));p->memory=m;p->submit=submit;p->context=ctx;}
int qwen_compile(qwen_compiler *p,const uint32_t *tokens,size_t count,uint16_t prefix,int decode){
 if(!p || !p->memory || !p->submit || !tokens || !count || count>512 || (decode!=0 && decode!=1) || (decode && count!=1) || (!decode && prefix) || prefix+count>1024)return -1;
 if(p->error || p->count)return -2;
 for(size_t i=0;i<count;i++)if(tokens[i]>=151936)return -1;
 for(size_t start=0;start<count && !p->error;start+=16){unsigned m=(unsigned)(count-start>16?16:count-start);embeddings(p,tokens+start,m);for(unsigned i=0;i<24 && !p->error;i++)layer(p,&p->memory->layers[i],m,prefix+(unsigned)start);if(start+m==count)logits(p,m);}
 flush(p);return p->error;
}
