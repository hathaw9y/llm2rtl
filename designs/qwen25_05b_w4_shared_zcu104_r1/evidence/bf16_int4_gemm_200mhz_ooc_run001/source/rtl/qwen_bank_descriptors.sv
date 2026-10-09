// Model-specific semantic metadata. Physical ownership stays in common table.
// Supported assembly follows compiler order: contiguous DMA byte prefix, and
// full-row layout tiles inserted in increasing column order. END preserves all.
module qwen_bank_descriptors(
 input logic clk,rst_n,input logic [22:0] bank_busy,
 input logic [255:0] command,input logic issue_valid,
 output logic command_legal,bank_eligible,validation_ready,
 input logic [6:0] commit_valid,commit_error,input logic [6:0][255:0] commit_command,
 output logic [22:0] valid,partial,assembling,
 output logic [22:0][1:0] format,
 output logic [22:0][10:0] rows,
 output logic [22:0][12:0] cols,
 output logic [22:0][15:0] tensor,
 output logic [22:0] attention_layout,
 output logic [22:0][5:0] next_group,
 output logic [22:0][17:0] covered_bytes,
 output logic [22:0][12:0] covered_columns
);
 // Stage 1 computes the bounded byte footprint. Stage 2 validates semantic
 // metadata against live descriptors. Publication is qualified by command and
 // bank-state identity; any issue or completion flushes both valid stages.
 logic [255:0] check_command,checked_command;
 logic stage1_valid,stage2_valid,checked_legal,checked_eligible;
 logic [22:0] checked_busy;
 logic [27:0] footprint_r;
 logic [10:0] footprint_rows;
 logic [17:0] footprint_columns,footprint_stride;
 logic [1:0] footprint_format;
 logic [3:0] op,mode;logic [4:0] a,b,c,s,m;
 logic [7:0] flags;logic [10:0] n,k,row,position;
 logic [12:0] col,extent_n;logic [4:0] extent_m;
 logic [15:0] uid;logic [5:0] group;
 logic [31:0] offset;logic [22:0] btt;
 logic [10:0] dma_rows;
 logic [22:0] used;logic sources_good,static_good,all_free;
 integer footprint,output_rows,output_cols,output_fmt;
 function automatic integer capacity(input integer bank);
  case(bank)
   0,1,2,3,21:return 32768;4,5,6,19,20,22:return 4096;
   7,11,12,13,14,15,16,17:return 8192;8:return 1024;9,10:return 131072;18:return 65536;
   default:return 0;
  endcase
 endfunction
 function automatic integer stride(input integer fmt,input integer n,input logic layout);
  if(layout) return fmt==1?2048:4096;
  case(fmt)
   1:return ((n+7)/8)*16;2:return ((n+3)/4)*16;3:return ((n+31)/32)*16;
   default:return 0;
  endcase
 endfunction
 always @*begin
  footprint_rows=11'(command[128+:5]);
  footprint_columns={7'b0,command[117+:11]};
  footprint_format=command[252+:4]==3?2:1;
  if(command[252+:4]==1 || command[252+:4]==2)begin
   footprint_rows=command[128+:5]!=0?11'(command[128+:5]):11'(command[19+:13]);
   footprint_format=command[146+:2];
  end else if(command[252+:4]==5)footprint_columns={1'b0,command[117+:11],6'b0};
  else if(command[252+:4]==7 && command[146+:4]==5 && command[145])begin
   footprint_rows=11'(command[32+:5]);footprint_columns={5'b0,command[19+:13]};
  end
  if(command[47])footprint_stride=footprint_format==1?18'd2048:18'd4096;
  else case(footprint_format)
   1:footprint_stride=((footprint_columns+18'd7)>>3)<<4;
   2:footprint_stride=((footprint_columns+18'd3)>>2)<<4;
   3:footprint_stride=((footprint_columns+18'd31)>>5)<<4;
   default:footprint_stride=0;
  endcase
 end
 assign op=check_command[252+:4];assign a=check_command[247+:5];assign b=check_command[242+:5];assign c=check_command[237+:5];
 assign mode=check_command[146+:4];assign flags=check_command[138+:8];assign s=check_command[133+:5];assign m=check_command[128+:5];
 assign n=check_command[117+:11];assign k=check_command[106+:11];assign row=check_command[95+:11];assign col=check_command[82+:13];
 assign position=check_command[71+:11];assign uid=check_command[51+:16];assign group=check_command[37+:6];
 assign extent_m=check_command[32+:5];assign extent_n=check_command[19+:13];assign offset=check_command[205+:32];assign btt=check_command[182+:23];
 assign dma_rows=m!=0?11'(m):11'(extent_n);
 always @* begin
  used=0;static_good=1;sources_good=1;output_rows=int'(m);output_cols=int'(n);output_fmt=1;footprint=0;
  if(op==1 || op==2)begin
   static_good=a<23 && btt>0 && check_command[150+:32]!=0 && offset[3:0]==0 && btt[3:0]==0 && mode>=1 && mode<=3 && (!check_command[47] || mode<=2) && n>0 && dma_rows>0 && extent_n<=1024;
   if(a<23)begin
    used[a]=1;footprint=int'(footprint_r);
    static_good=static_good && footprint<=capacity(int'(a)) && offset<=32'(footprint) && btt<=23'(footprint)-offset;
    if(op==1)begin
     if(!(flags&8'h40))sources_good=assembling[a] && format[a]==mode[1:0] && rows[a]==dma_rows && cols[a]==13'(n) && tensor[a]==uid && attention_layout[a]==check_command[47] && covered_bytes[a]==offset;
     else sources_good=offset==0;
     if(flags&8'h20)sources_good=sources_good && offset+btt==32'(footprint);
    end else sources_good=valid[a] && !partial[a] && format[a]==mode[1:0] && rows[a]==dma_rows && cols[a]==13'(n) && attention_layout[a]==check_command[47];
   end
  end else if(op>=3 && op<=7)begin
   static_good=a<23 && c<23 && a!=c && m>=1 && m<=16 && n>0;
   if(a<23 && c<23)begin
    used[a]=1;used[c]=1;sources_good=valid[a] && !partial[a];
    if(op==3 || op==4 || op==5 || (op==7 && mode<4))begin
     static_good=static_good && b<23 && a!=b && c!=b;
     if(b<23)begin used[b]=1;sources_good=sources_good && valid[b] && !partial[b];end
    end
    case(op)
     3:begin
      output_fmt=2;static_good=static_good && mode<=2 && k>0 && k<=1024 && n<=1024 && ((flags&3)==1 || (flags&3)==2);
      sources_good=sources_good && format[a]==1 && rows[a]==11'(m) && cols[a]==13'(k) && (mode==2?attention_layout[a]:!attention_layout[a]);
      if(mode==0)begin
       static_good=static_good && a==6 && b==7 && s==8 && (c>=11 && c<=18) && n==128 && k==128 && a!=s && b!=s && c!=s;
       used[8]=1;sources_good=sources_good && format[7]==3 && rows[7]==128 && cols[7]==128 && !attention_layout[7] && valid[8] && format[8]==2 && rows[8]==1 && cols[8]==128 && !attention_layout[8];
      end else if(mode==1)begin
       static_good=static_good && a==6 && b==9 && c==18 && k==64 && flags[0] && flags[5] && check_command[47];
       sources_good=sources_good && format[9]==1 && rows[9]==n && cols[9]==64 && !attention_layout[9];
      end else begin
       static_good=static_good && a==21 && b==10 && c>=11 && c<=17 && n==64 && flags[0] && flags[5] && !check_command[47];
       sources_good=sources_good && format[10]==1 && rows[10]==k && cols[10]==64 && !attention_layout[10];
      end
      if(flags[1])sources_good=sources_good && valid[c] && partial[c] && format[c]==2 && rows[c]==11'(m) && cols[c]==13'(n) && tensor[c]==uid && next_group[c]==group && attention_layout[c]==check_command[47];
      else static_good=static_good && group==0;
     end
     4:begin
      sources_good=sources_good && !attention_layout[a] && !attention_layout[22];
      static_good=static_good && mode==0 && a<=3 && b==22 && c<=3 && n==896;
      sources_good=sources_good && format[a]==1 && rows[a]==11'(m) && cols[a]==896 && format[22]==1 && rows[22]==1 && cols[22]==896;
     end
     5:begin
      sources_good=sources_good && !attention_layout[a] && !attention_layout[22];
      output_cols=int'(n)*64;static_good=static_good && mode==0 && b==22 && (n==2 || n==14) && k==64;
      sources_good=sources_good && format[a]==1 && rows[a]==11'(m) && cols[a]==13'(output_cols) && format[22]==1 && rows[22]==11'(m) && cols[22]==128;
     end
     6:begin
      static_good=static_good && mode==0 && a==18 && c==21 && n<=1024 && int'(position)+int'(m)==int'(n) && check_command[47];
      sources_good=sources_good && format[18]==2 && rows[18]==11'(m) && cols[18]==13'(n) && attention_layout[18];
     end
     7:begin
      sources_good=sources_good && !attention_layout[a];
      if(mode<4 && b<23)sources_good=sources_good && !attention_layout[b];
      static_good=static_good && mode<=5 && n<=1024 && n[2:0]==0;
      case(mode)
       0:sources_good=sources_good && format[a]==2 && format[b]==1 && rows[a]==11'(m) && cols[a]==13'(n) && rows[b]==1 && cols[b]==13'(n);
       1,2:sources_good=sources_good && format[a]==1 && format[b]==1 && rows[a]==11'(m) && cols[a]==13'(n) && rows[b]==11'(m) && cols[b]==13'(n);
       3:sources_good=sources_good && format[a]==3 && format[b]==2 && rows[a]==11'(m) && cols[a]==13'(n) && rows[b]==11'(m) && cols[b]==13'(n/128);
       4:sources_good=sources_good && format[a]==2 && rows[a]==11'(m) && cols[a]==13'(n);
       5:begin
        sources_good=sources_good && format[a]==1;
        if(flags[7])begin
         output_rows=int'(extent_m);output_cols=int'(extent_n);
         static_good=static_good && row==0 && extent_m==m && extent_n>0 && extent_n<=1024 && col[2:0]==0 && int'(col)+int'(n)<=int'(extent_n);
         sources_good=sources_good && rows[a]==11'(m) && cols[a]==13'(n);
         if(flags[6])sources_good=sources_good && col==0;
         else sources_good=sources_good && assembling[c] && format[c]==1 && rows[c]==11'(m) && cols[c]==extent_n && tensor[c]==uid && covered_columns[c]==col;
         if(flags[5])sources_good=sources_good && int'(col)+int'(n)==int'(extent_n);
        end else sources_good=sources_good && int'(row)+int'(m)<=int'(rows[a]) && int'(col)+int'(n)<=int'(cols[a]) && col[2:0]==0;
       end
       default:sources_good=0;
      endcase
     end
     default:static_good=0;
    endcase
    footprint=int'(footprint_r);static_good=static_good && footprint>0 && footprint<=capacity(int'(c));
   end
  end else if(op!=0)static_good=0;
  all_free=!(|(used & bank_busy));
  // Pending producers may make descriptors valid; never reject them early.
 end
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   check_command<=0;checked_command<=0;checked_busy<=0;footprint_r<=0;
   stage1_valid<=0;stage2_valid<=0;checked_legal<=0;checked_eligible<=0;
  end else begin
   check_command<=command;footprint_r<=28'(footprint_rows*footprint_stride);
   checked_command<=check_command;checked_busy<=bank_busy;
   checked_legal<=static_good && (!all_free || sources_good);
   checked_eligible<=all_free && sources_good;
   if(issue_valid || (|commit_valid))begin stage1_valid<=0;stage2_valid<=0;end
   else begin stage1_valid<=1;stage2_valid<=stage1_valid;end
  end
 end
 // While validation is pending, the dispatcher stalls instead of diagnosing
 // a malformed command. DMA forwarding is separately gated by ready.
 assign validation_ready=stage2_valid && checked_command==command && checked_busy==bank_busy;
 assign command_legal=!validation_ready || checked_legal;
 assign bank_eligible=validation_ready && checked_eligible;
 // Ownership changes on the issue edge. Delay descriptor setup by one edge
 // while that lease prevents bank reuse, separating validation from fanout.
 logic issue_pending;
 logic [255:0] issue_command;
 always_ff @(posedge clk)begin
  if(!rst_n)begin issue_pending<=0;issue_command<=0;end
  else begin issue_pending<=issue_valid;if(issue_valid)issue_command<=command;end
 end
 task automatic set_output(input logic [255:0] record);
  logic [3:0] o,v;logic [4:0] src,dst,rm;logic [12:0] cn;logic [10:0] rr;
  o=record[252+:4];v=record[146+:4];src=record[247+:5];dst=record[237+:5];rm=record[128+:5];cn=13'(record[117+:11]);rr=11'(rm);
  if(o==1)begin dst=src;rr=rm!=0?11'(rm):11'(record[19+:13]);end
  if(o==5)cn=13'(record[117+:11])*64;
  if(o==7 && v==5 && record[145])begin rr=11'(record[32+:5]);cn=record[19+:13];end
  if(dst<23)begin
   valid[dst]<=0;format[dst]<=o==1?v[1:0]:o==3?2:1;rows[dst]<=rr;cols[dst]<=cn;tensor[dst]<=record[51+:16];attention_layout[dst]<=record[47];
   if((o==1 || (o==7 && v==5 && record[145])) && record[144])begin assembling[dst]<=1;covered_bytes[dst]<=0;covered_columns[dst]<=0;end
  end
 endtask
 task automatic commit(input logic [255:0] record,input logic error);
  logic [3:0] o,v;logic [4:0] src,second,dst,sc;logic [7:0] f;logic [12:0] next_col;logic [17:0] next_byte;
  o=record[252+:4];v=record[146+:4];src=record[247+:5];second=record[242+:5];dst=o==1?src:record[237+:5];sc=record[133+:5];f=record[138+:8];
  next_col=record[82+:13]+13'(record[117+:11]);next_byte=18'(record[205+:32])+18'(record[182+:23]);
  if(error)begin if(o!=2 && dst<23)begin valid[dst]<=0;assembling[dst]<=0;partial[dst]<=0;end end
  else begin
   if(o==1)begin covered_bytes[dst]<=next_byte;if(f[5])begin valid[dst]<=1;assembling[dst]<=0;partial[dst]<=0;end end
   else if(o!=2)begin
    if(o==3)begin valid[dst]<=1;partial[dst]<=!f[5];next_group[dst]<=record[37+:6]+1'b1;assembling[dst]<=0;end
    else if(o==7 && v==5 && f[7])begin covered_columns[dst]<=next_col;if(f[5])begin valid[dst]<=1;partial[dst]<=0;assembling[dst]<=0;end end
    else begin valid[dst]<=1;partial[dst]<=0;assembling[dst]<=0;end
   end
   if(o!=1 && f[2] && src<23)valid[src]<=0;
   if((o==3 || o==4 || o==5 || (o==7 && v<4)) && f[3] && second<23)valid[second]<=0;
   if(o==3 && v==0 && f[4] && sc<23)valid[sc]<=0;
  end
 endtask
 always_ff @(posedge clk)begin
  if(!rst_n)begin valid<=0;partial<=0;assembling<=0;format<=0;rows<=0;cols<=0;tensor<=0;attention_layout<=0;next_group<=0;covered_bytes<=0;covered_columns<=0;end
  else begin
   for(integer e=0;e<7;e=e+1)if(commit_valid[e])commit(commit_command[e],commit_error[e]);
   if(issue_pending && issue_command[252+:4]!=2 && issue_command[252+:4]!=0)set_output(issue_command);
  end
 end
endmodule
