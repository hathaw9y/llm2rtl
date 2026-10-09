#!/usr/bin/env python3
import argparse,json,hashlib,subprocess,shutil
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
CC='/media/admin1/backup/tools/Xilinx/2025.2/gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc'
def main():
 p=argparse.ArgumentParser();p.add_argument('data',type=Path);p.add_argument('out',type=Path);p.add_argument('--sd-bsp',type=Path);a=p.parse_args();a.out.mkdir(exist_ok=False,parents=True);(a.out/'source').mkdir()
 m=json.loads((a.data/'DDR_layout.json').read_text())
 def weight(name):
  w=m['weights'][name];return '{'+','.join(f'.{key}={w.get(key,0)}u' for key in ('codes','scales','bias','n','k'))+'}'
 s='static const qwen_memory memory={.embedding='+weight('model.embed_tokens.weight')+',.layers={\n'
 for i in range(24):
  pre=f'model.layers.{i}.';f=[f'.{n}='+weight(pre+'self_attn.'+n+'_proj.weight') for n in ('q','k','v','o')]+[f'.{n}='+weight(pre+'mlp.'+n+'_proj.weight') for n in ('gate','up','down')]+[f'.norm1={m["parameters"][pre+"input_layernorm.weight"]}u',f'.norm2={m["parameters"][pre+"post_attention_layernorm.weight"]}u']
  f+=['.kv={{'+','.join(str(m['KV'][f'{i}.K.{h}'])+'u' for h in range(2))+'},{'+','.join(str(m['KV'][f'{i}.V.{h}'])+'u' for h in range(2))+'}}'];s+='{'+','.join(f)+'},\n'
 s+='},'+','.join(f'.{k}={m[k]}u' for k in ('embedding_codes','embedding_scales','rope','logits'))+f',.norm={m["parameters"]["model.norm.weight"]}u'+'};\n'
 (a.out/'source/qwen_memory.h').write_text(s)
 for f in (BASE/'software').glob('*'):shutil.copyfile(f,a.out/'source'/f.name)
 src=a.out/'source';elf=a.out/'qwen_baremetal.elf'
 cmd=[CC,'-std=c11','-O2','-Wall','-Wextra','-Werror','-ffreestanding','-fno-builtin','-fno-stack-protector','-mgeneral-regs-only','-nostdlib','-I'+str(src),str(src/'baremetal_start.S'),str(src/'qwen_isa.c'),str(src/'baremetal_main.c'),'-T'+str(src/'baremetal.ld'),'-Wl,-Map='+str(a.out/'qwen_baremetal.map'),'-o',str(elf),'-lgcc']
 if a.sd_bsp:
  bsp=a.sd_bsp.resolve();bm=json.loads((bsp/'manifest.json').read_text());proc=bsp/'bsp/psu_cortexa53_0'
  if bm['libxil_sha256']!=hashlib.sha256((proc/'lib/libxil.a').read_bytes()).hexdigest():raise ValueError('BSP identity mismatch')
  if bm['libxilffs_sha256']!=hashlib.sha256((proc/'lib/libxilffs.a').read_bytes()).hexdigest():raise ValueError('FatFs identity mismatch')
  dm=json.loads((a.data/'manifest.json').read_text());digest=dm['DDR_image_sha256'];size=(a.data/'model_ddr.bin').stat().st_size
  (src/'qwen_sd_image.h').write_text(f'#define QWEN_SD_IMAGE_BYTES {size}u\nstatic const uint8_t qwen_sd_expected_sha256[32]={{'+','.join('0x'+digest[i:i+2] for i in range(0,64,2))+'};\n')
  cmd[1:1]=['-DQWEN_SD_LOAD','-Wl,--gc-sections','-I'+str(proc/'include'),str(src/'qwen_sd_loader.c'),str(src/'qwen_sha256.c')]
  cmd[-1:]=['-Wl,--start-group','-L'+str(proc/'lib'),'-lxilffs','-lxil','-lgcc','-Wl,--end-group']
 with (a.out/'build.log').open('w') as log:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True)
 objdump=str(Path(CC).with_name('aarch64-none-elf-objdump'));dis=subprocess.check_output([objdump,'-d',str(elf)],text=True);(a.out/'disassembly.txt').write_text(dis)
 import re
 if re.search(r'\b(fadd|fmul|fmla|fdiv|fsub|fmov|fcvt)\b',dis):raise RuntimeError('Unexpected floating-point runtime instruction')
 manifest={'status':'compiled_baremetal_only','toolchain':CC,'ELF_sha256':hashlib.sha256(elf.read_bytes()).hexdigest(),'source_sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in src.glob('*')},'DDR_layout_sha256':hashlib.sha256((a.data/'DDR_layout.json').read_bytes()).hexdigest(),'requirements':['Cold system reset; generated psu_init from matching XSA before ELF launch.','Model DDR image preloaded at0x10000000; text/BSS/stack at0x00100000, output snapshots at0x08000000..0x08158fff.','UART1 must be initialized by matching ZCU104 preset.','Physical FPGA execution is user-run and not claimed.'],'runtime_scope':'ISA generation/publication/status and byte-only output copies; no numerical tensor operations.'}
 profile=BASE/'hardware_profile.json'
 manifest['hardware_profile_sha256']=hashlib.sha256(profile.read_bytes()).hexdigest()
 manifest['target_PL_clock_MHz']=json.loads(profile.read_text())['target_clock_MHz']
 if a.sd_bsp:
  manifest['model_load']='SD1 FAT read-only 0:/QWEN.BIN to DDR0x10000000, exact bytes + SHA256 before START'
  manifest['DDR_image_sha256']=digest;manifest['DDR_image_bytes']=size;manifest['BSP_manifest']=bm
  manifest['requirements'][1]='FAT SD card QWEN.BIN; no JTAG model preloading. text/BSS/stack0x00100000; snapshots0x08000000..0x08158fff.'
 (a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(manifest['status'],manifest['ELF_sha256'])
if __name__=='__main__':main()
