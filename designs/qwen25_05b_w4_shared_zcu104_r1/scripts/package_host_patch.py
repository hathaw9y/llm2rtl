#!/usr/bin/env python3
"""Package only changed host files, with exact source/destination hash guards."""
import argparse,hashlib,json,shutil,zipfile
from pathlib import Path
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('old',type=Path);p.add_argument('new',type=Path);p.add_argument('out',type=Path);a=p.parse_args()
 out=a.out.resolve();archive=out.with_suffix('.zip')
 if out.exists() or archive.exists():raise ValueError('Fresh patch directory/ZIP required')
 before=json.loads((a.old/'checksums.json').read_text());after=json.loads((a.new/'checksums.json').read_text())
 for root,expected in [(a.old,before),(a.new,after)]:
  for name,digest in expected.items():
   if sha(root/name)!=digest:raise ValueError('Package identity mismatch: '+name)
 changed={name:{'old':before.get(name),'new':digest} for name,digest in after.items() if before.get(name)!=digest}
 changed['checksums.json']={'old':sha(a.old/'checksums.json'),'new':sha(a.new/'checksums.json')}
 out.mkdir(parents=True)
 for name in changed:
  dst=out/'files'/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(a.new/name,dst)
 (out/'patch_manifest.json').write_text(json.dumps(changed,indent=2)+'\n')
 (out/'apply_patch.py').write_text('''#!/usr/bin/env python3
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);a=p.parse_args();target=a.package.resolve()
    if not (target/'host.py').is_file():raise ValueError('Specify the extracted original host package')
    changes=json.loads((ROOT/'patch_manifest.json').read_text())
    for name,identity in changes.items():
        src=ROOT/'files'/name;dst=target/name
        if sha(src)!=identity['new']:raise ValueError('Patch payload mismatch: '+name)
        if dst.exists():
            if sha(dst) not in [identity['old'],identity['new']]:raise ValueError('Unexpected destination contents: '+name)
        elif identity['old'] is not None:raise ValueError('Expected original file missing: '+name)
    for name in changes:
        dst=target/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/'files'/name,dst)
    subprocess.run([sys.executable,str(target/'host.py'),'verify'],check=True)
    print('HOST_PATCH_PASS; QWEN.BIN unchanged, cold power cycle before new XSCT load')
if __name__=='__main__':main()
''')
 (out/'README.txt').write_text('''Matched FPGA/firmware update. The patch_manifest guards exact old/new file hashes.
Existing SD QWEN.BIN is unchanged. Use the extracted original host package as --package.
Extract this patch ZIP separately. On Ubuntu:
python3 apply_patch.py --package /home/iamjames77/qwen/qwen_host_sd_200mhz_run002
After HOST_PATCH_PASS, exit old XSCT, power board OFF/ON (JTAG boot),
open UART1 ttyUSB2 logging and a new XSCT in the updated ORIGINAL package folder:
source load_board.tcl
Wait for PL_CONTROL_PREFLIGHT_PASS in XSCT and HANDOFF_DONE on UART before dump_board.tcl.
Then python3 host.py compare. No physical model PASS is claimed by this patch.
''')
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=1) as z:
  for f in sorted(out.rglob('*')):
   if f.is_file():z.write(f,(Path(out.name)/f.relative_to(out)).as_posix())
 digest=sha(archive);archive.with_suffix('.zip.sha256').write_text(digest+'  '+archive.name+'\n')
 print(json.dumps({'ZIP':str(archive),'bytes':archive.stat().st_size,'sha256':digest,'changed_files':len(changed)},indent=2))
if __name__=='__main__':main()
