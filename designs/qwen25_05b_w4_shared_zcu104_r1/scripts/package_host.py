#!/usr/bin/env python3
"""Make a relocatable host-PC ZIP from a verified handoff, without board access."""
import argparse
import hashlib
import json
import shutil
import zipfile
from pathlib import Path
from check_board_reset import check as check_reset


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1048576), b''):
            h.update(block)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--handoff', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--sd-firmware', type=Path)
    a = p.parse_args()
    source = a.handoff.resolve()
    out = a.out.resolve()
    archive = out.with_suffix('.zip')
    if out.exists() or archive.exists():
        raise RuntimeError('Fresh directory and ZIP required')
    original = json.loads((source / 'artifact_manifest.json').read_text())
    if original['status'] != 'routed_artifact_handoff':
        raise ValueError('Verified routed handoff required')
    hwh_path = next(Path(n) for n in original['artifact_sha256'] if n.endswith('.hwh'))
    board_reset_check = check_reset(hwh_path)
    for name, expected in original['artifact_sha256'].items():
        if sha(Path(name)) != expected:
            raise ValueError('Source identity mismatch: ' + name)
    if sha(source / 'psu_init.tcl') != original['psu_init_sha256']:
        raise ValueError('PS init identity mismatch')
    audit_paths = [Path(name) for name in original['artifact_sha256']
                   if Path(name).name == 'result.json']
    if len(audit_paths) != 1:
        raise ValueError('Unique routed audit result required for deployment notes')
    audit_result = json.loads(audit_paths[0].read_text())
    if audit_result['status'] != 'passed_routed_200MHz_clock_timing_audit':
        raise ValueError('Passed routed audit required')
    setup = min(row['worst_slack_ns'] for row in audit_result['checks']['Setup']['clocks'])
    hold = min(row['worst_slack_ns'] for row in audit_result['checks']['Hold']['clocks'])
    pulse_width = min(row['worst_slack_ns'] for row in audit_result['checks']['PW']['clocks'])
    timing_note = f'setup{setup:+.3f}ns, hold{hold:+.3f}ns, pulse width{pulse_width:+.3f}ns.'
    out.mkdir(parents=True)
    portable = dict(original)
    portable['board_reset_check'] = board_reset_check
    portable['artifact_sha256'] = {}
    sd_manifest = None
    if a.sd_firmware:
        sd_firmware = a.sd_firmware.resolve()
        sd_manifest = json.loads((sd_firmware / 'manifest.json').read_text())
        original_fw = next(Path(n) for n in original['artifact_sha256'] if n.endswith('.elf'))
        old_fw = json.loads((original_fw.parent / 'manifest.json').read_text())
        xsa = next(Path(n) for n in original['artifact_sha256'] if n.endswith('.xsa'))
        if (sd_manifest.get('model_load') is None or sd_manifest['target_PL_clock_MHz'] != 200
            or sd_manifest['hardware_profile_sha256'] != old_fw['hardware_profile_sha256']
            or sd_manifest['DDR_layout_sha256'] != old_fw['DDR_layout_sha256']
            or sd_manifest['BSP_manifest']['XSA_sha256'] != sha(xsa)
            or sd_manifest['ELF_sha256'] != sha(sd_firmware / 'qwen_baremetal.elf')):
            raise ValueError('SD firmware/hardware/data identity mismatch')
        portable['model_load'] = sd_manifest['model_load']
        portable['physical_SD_load'] = 'not_performed'
    for name, expected in original['artifact_sha256'].items():
        src = Path(name)
        if sd_manifest and src.parent == original_fw.parent:
            continue
        if src.name in ['qwen.bit', 'qwen.hwh', 'qwen.xsa'] or src.suffix == '.elf':
            rel = Path('hardware') / src.name
        elif sd_manifest and src.name == 'model_ddr.bin':
            if sha(src) != sd_manifest['DDR_image_sha256'] or src.stat().st_size != sd_manifest['DDR_image_bytes']:
                raise ValueError('SD firmware image mismatch')
            rel = Path('sd_card/QWEN.BIN')
        elif src.name == 'model_ddr.bin' or src.name == 'DDR_layout.json':
            rel = Path('data') / src.name
        elif src.name.endswith(('_logits.bin', '_KV_valid_prefix.bin')):
            rel = Path('golden') / src.name
        elif src.name == 'manifest.json' and src.parent.name.startswith('board_data_'):
            rel = Path('golden/manifest.json')
        else:
            rel = Path('evidence') / src.parent.name / src.name
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        portable['artifact_sha256'][rel.as_posix()] = expected
    if sd_manifest:
        for name, rel in [('qwen_baremetal.elf','hardware/qwen_baremetal.elf'),('manifest.json','evidence/baremetal_sd/manifest.json')]:
            dst = out / rel
            dst.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(sd_firmware / name,dst)
            portable['artifact_sha256'][rel] = sha(dst)
    shutil.copyfile(source / 'psu_init.tcl', out / 'hardware/psu_init.tcl')
    shutil.copyfile(source / 'compare_board.py', out / 'compare_board.py')
    if sd_manifest:
        shutil.copyfile(Path(__file__).resolve().parent / 'compare_board.py', out / 'compare_board.py')
    portable['source_handoff_manifest_sha256'] = sha(source / 'artifact_manifest.json')
    portable['path_basis'] = 'relative to portable package root'
    (out / 'artifact_manifest.json').write_text(json.dumps(portable, indent=2) + '\n')
    # Tcl list substitutions preserve spaces on Windows and Linux; no server paths.
    (out / 'load_board.tcl').write_text('''# USER EXECUTION ONLY: ZCU104, JTAG boot, UART logging enabled.
set qwen_host_root [file dirname [file normalize [info script]]]
foreach qwen_host_file {hardware/qwen.bit hardware/psu_init.tcl hardware/qwen_baremetal.elf data/model_ddr.bin} {
    if {![file isfile [file join $qwen_host_root $qwen_host_file]]} {error "Missing package file: $qwen_host_file"}
}
connect
targets -set -filter {name =~ "APU*"}
rst -system -stop
after 2000
fpga -file [file join $qwen_host_root hardware qwen.bit]
source [file join $qwen_host_root hardware psu_init.tcl]
psu_init
if {[llength [info commands psu_post_config]]} {psu_post_config}
if {[llength [info commands psu_ps_pl_isolation_removal]]} {psu_ps_pl_isolation_removal}
if {[llength [info commands psu_ps_pl_reset_config]]} {psu_ps_pl_reset_config}
# Verify the real control bus before allowing the CPU to issue PL transactions.
targets -set -filter {name =~ "PSU*"}
set qwen_profile_value [mrd -force -value 0xA0010018]
if {$qwen_profile_value != 0x51574E31} {error "QWEN PL profile mismatch: $qwen_profile_value"}
set qwen_status_value [mrd -force -value 0xA0010004]
if {$qwen_status_value & 0xD} {error "QWEN PL not idle after board reset: $qwen_status_value"}
puts "PL_CONTROL_PREFLIGHT_PASS profile=QWN1 reset_released"
targets -set -filter {name =~ "Cortex-A53 #0*"}
rst -processor -stop -clear-registers -isa A64
configparams force-mem-access 1
dow -data [file join $qwen_host_root data model_ddr.bin] 0x10000000
dow [file join $qwen_host_root hardware qwen_baremetal.elf]
configparams force-mem-access 0
con
puts "Wait for UART1 HANDOFF_DONE before sourcing dump_board.tcl."
''')
    (out / 'dump_board.tcl').write_text('''# Same XSCT session, AFTER UART1 HANDOFF_DONE.
set qwen_host_root [file dirname [file normalize [info script]]]
targets -set -filter {name =~ "Cortex-A53 #0*"}
stop
file mkdir [file join $qwen_host_root dumps]
'''+''.join(f'mrd -bin -size b -file [file join $qwen_host_root dumps {name}] {addr} {size}\n'
            for name, addr, size in [('prefill_logits.bin','0x08000000',303872),('prefill_KV_valid_prefix.bin','0x08050000',24576),('decode_logits.bin','0x08100000',303872),('decode_KV_valid_prefix.bin','0x08150000',36864)]))
    (out / 'host.py').write_text('''#!/usr/bin/env python3
"""Verify package integrity or compare user-produced board results."""
import argparse, hashlib, json, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''): h.update(b)
    return h.hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['verify','compare']);p.add_argument('--output',default='user_board_result_run001.json');a=p.parse_args()
    files=json.loads((ROOT/'checksums.json').read_text())
    for name, expected in files.items():
        if sha(ROOT/name)!=expected: raise ValueError('Package identity mismatch: '+name)
    print('PACKAGE_SHA256_PASS: '+str(len(files))+' files',flush=True)
    if a.action=='compare':
        subprocess.run([sys.executable,str(ROOT/'compare_board.py'),'--golden',str(ROOT/'golden'),'--dumps',str(ROOT/'dumps'),'--uart',str(ROOT/'uart.log'),'--artifact-manifest',str(ROOT/'artifact_manifest.json'),'--output',str(ROOT/a.output)],check=True)
if __name__=='__main__':main()
''')
    (out / 'README.txt').write_text('''Qwen2.5-0.5B / ZCU104 / bare-metal / 200MHz host-PC package

Windows/Linux 호스트에서 ZIP 전체를 해제하십시오. 저장소와 모델 다운로드는 필요 없습니다.
필요: Python 3 (추가 pip 패키지 없음), AMD XSCT/JTAG 드라이버와 cable server.
서버 빌드는 Vivado 2025.2입니다. 동일 버전의 XSCT 환경을 권장합니다.
Windows는 AMD command prompt에서 xsct 실행, Linux는 설치 환경 설정 후 xsct 실행.
보드 실행은 사용자만 수행합니다. 여러 보드가 연결되면 이 스크립트 대신 target 선택을 조정하십시오.

1. 패키지 폴더에서: python host.py verify
   Linux에서 python이 없으면 python3를 사용하십시오.
2. ZCU104 JTAG boot, cold power/reset. JTAG/USB UART 연결.
   UART1은 FTDI interface02이며 현재 사용자 호스트에서는 /dev/ttyUSB2입니다.
   UART1 115200 8N1, flow control 없음. 출력 전체를 패키지의 uart.log에 기록하십시오.
3. xsct 시작. XSCT에서 패키지 폴더로 이동한 뒤:
   cd {C:/fpga/qwen_host_200mhz_run001}
   source load_board.tcl
   Linux 예: cd {/home/user/qwen_host_200mhz_run001}
   349MB DDR 데이터는 JTAG로 전송되므로 시간이 걸립니다.
4. XSCT PL_CONTROL_PREFLIGHT_PASS 후 UART HANDOFF_DONE을 기다리십시오.
   Preflight가 실패하면 CPU를 실행하지 않습니다. 오류/정지 시 로그를 보존하고 dump를 PASS로 판정하지 마십시오.
   같은 XSCT 세션에서: source dump_board.tcl
5. UART 로그 저장을 종료한 뒤 패키지 폴더의 터미널에서:
   python host.py compare
   기대 status: passed_user_returned_prefill2_decode1
6. uart.log, dumps/ 네 파일, user_board_result_run001.json, artifact_manifest.json을 서버로 반환하십시오.
   비교 재실행: python host.py compare --output user_board_result_run002.json

예상 UART (cycle은 측정값, 0보다 커야 함):
prefill2 DONE commands=123194 chunks=132 PL_active_cycles=<measured> cache_length=2
decode1 DONE commands=246290 chunks=264 PL_active_cycles=<cumulative> cache_length=3
HANDOFF_DONE.

범위: full24layer prefill tokens [9707,11], decode [151643], last-token logits와 모든 유효 KV.
PS는 ISA 생성/전송/제어/결과 byte 복사만 수행합니다. Tensor 계산은 PL executor가 수행합니다.
Routed timing: __ROUTED_TIMING__
실물 FPGA 실행은 아직 미확인입니다. 원본 BF16 대비 W4 품질 실패, prefill512 KV 오차 실패,
reference-seeded prefix1023 decode 한계가 남아 있습니다. 이 실행으로 최대 context1024 전체 검증을 주장하지 않습니다.
'''.replace('__ROUTED_TIMING__', timing_note), encoding='utf-8')
    if sd_manifest:
        load = out / 'load_board.tcl'
        text = load.read_text().replace(' data/model_ddr.bin}', '}')
        text = text.replace('dow -data [file join $qwen_host_root data model_ddr.bin] 0x10000000\n', '')
        load.write_text(text)
        readme = out / 'README.txt'
        text = readme.read_text().replace('C:/fpga/qwen_host_200mhz_run001','C:/fpga/'+out.name).replace('/home/user/qwen_host_200mhz_run001','/home/user/'+out.name)
        text = text.replace('349MB DDR 데이터는 JTAG로 전송되므로 시간이 걸립니다.', '모델은 SD에서 DDR로 적재합니다. JTAG로는 BIT/ELF만 전송합니다.')
        text = text.replace('2. ZCU104 JTAG boot, cold power/reset.', '''2. 기존 FAT32 SD 카드의 루트에 sd_card/QWEN.BIN을 QWEN.BIN 이름으로 복사합니다.
   Ubuntu에서 패키지 폴더 안에서: python3 copy_sd.py --mount /media/사용자/SD카드라벨
   이 도구는 포맷하지 않고 파일 하나만 복사하며 복사 후 SHA256을 확인합니다.
   완료 후 sync 및 SD 카드 안전 제거(unmount)를 하고 ZCU104 SD 슬롯에 삽입합니다.
   exFAT/NTFS는 지원하지 않습니다. SD 부팅이 아니라 모델 저장용이므로 JTAG boot를 유지합니다.
   ZCU104 JTAG boot, cold power/reset.''')
        text = text.replace('예상 UART (cycle은 측정값, 0보다 커야 함):','예상 UART (SD_MODEL_SHA256_PASS가 먼저 나와야 함, cycle은 측정값):\nSD_LOAD_BEGIN file=0:/QWEN.BIN\nSD_MODEL_SHA256_PASS')
        text += '\nReset 수정 전 host_sd_run001/run002는 실행하지 않습니다. 기존 DAP 오류 후에는 XSCT 종료, 보드 전원 OFF/ON, 새 XSCT 세션에서 이 새 package의 load_board.tcl을 실행하십시오. SD의 QWEN.BIN은 unchanged이므로 다시 복사할 필요 없습니다.\n'
        readme.write_text(text,encoding='utf-8')
        (out / 'copy_sd.py').write_text('''#!/usr/bin/env python3
"""Copy one verified model file to an existing FAT SD mount; never format."""
import argparse,json,os,shutil,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for block in iter(lambda:f.read(1048576),b''):h.update(block)
    return h.hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('--mount',type=Path,required=True);a=p.parse_args();mount=a.mount.resolve()
    if not os.path.ismount(mount):raise ValueError('Specify the existing mounted SD partition root')
    mounted={}
    for line in Path('/proc/mounts').read_text().splitlines():
        fields=line.split();mounted[fields[1].replace(chr(92)+'040',' ').replace(chr(92)+'134',chr(92))]=fields[2]
    if mounted.get(str(mount))!='vfat':raise ValueError('Use an existing FAT32/vfat SD partition; exFAT/NTFS unsupported')
    src=ROOT/'sd_card/QWEN.BIN';dst=mount/'QWEN.BIN'
    expected=json.loads((ROOT/'checksums.json').read_text())['sd_card/QWEN.BIN']
    if sha(src)!=expected:raise ValueError('Source image SHA256 mismatch')
    if dst.exists():
        if sha(dst)!=expected:raise ValueError('Different QWEN.BIN already exists; move it aside explicitly')
    else:
        with src.open('rb') as f,dst.open('xb') as d:
            shutil.copyfileobj(f,d,1048576);d.flush();os.fsync(d.fileno())
    os.sync()
    if sha(dst)!=expected:raise ValueError('SD copy SHA256 mismatch')
    print('SD_COPY_SHA256_PASS: '+str(dst)+'; safely unmount and insert into ZCU104')
if __name__=='__main__':main()
''')
    checksums = {f.relative_to(out).as_posix(): sha(f) for f in sorted(out.rglob('*')) if f.is_file()}
    (out / 'checksums.json').write_text(json.dumps(checksums, indent=2) + '\n')
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1) as z:
        for f in sorted(out.rglob('*')):
            if f.is_file():
                z.write(f, (Path(out.name) / f.relative_to(out)).as_posix())
    checksum = sha(archive)
    archive.with_suffix('.zip.sha256').write_text(checksum+'  '+archive.name+'\n')
    print(json.dumps({'zip':str(archive),'bytes':archive.stat().st_size,'sha256':checksum,'physical_board_execution':False}, indent=2))


if __name__ == '__main__':
    main()
