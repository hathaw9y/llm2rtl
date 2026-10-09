#!/usr/bin/env python3
"""Index scoped immutable evidence without upgrading any claim."""
import argparse,hashlib,json
from pathlib import Path
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1];BUILD=Path('/media/admin1/backup/llm2rtl-builds')/BASE.name

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('out',type=Path);p.add_argument('--board-run',default='board_200mhz_build_run005');p.add_argument('--data-run',default='board_data_run003');p.add_argument('--ps-run',default='ps_compiler_run003');p.add_argument('--firmware-dir',type=Path);p.add_argument('--board-audit-run');a=p.parse_args()
 if a.out.exists():raise RuntimeError('Fresh evidence index path required')
 entries=[]
 def entry(name,scope,directory,files):
  records={str(directory/f):{'sha256':sha(directory/f),'bytes':(directory/f).stat().st_size} for f in files if (directory/f).is_file()}
  entries.append({'name':name,'scope':scope,'evidence':records,'complete_requested_files':len(records)==len(files)})
 for name,run in [('FP32','fp32_sim_run007'),('nonlinear','nonlinear_fp6_sim_run001'),('RMSNorm','rmsnorm_fp6_sim_run001'),('RoPE','rope_fp6_sim_run001'),('Softmax','softmax_fp6_sim_run001'),('Vector','vector_fp6_sim_run001')]:
  entry(name+' simulation','Command/arithmetic golden and protocol coverage specified by each log; module only',BASE/'evidence'/run,['manifest.json','result.json','simulation.log'])
 entry('GEMM simulation','Exact-source full module golden/protocol/error/reset coverage; Vivado XSIM only',BUILD/'gemm_fp6_xsim_run001',['manifest.json','result.json','simulation.log'])
 for name,run in [('GEMM','gemm_200mhz_ooc_run003'),('RMSNorm','rmsnorm_200mhz_ooc_run002'),('RoPE','rope_200mhz_ooc_run002'),('Softmax','softmax_200mhz_ooc_run002'),('Vector','vector_200mhz_ooc_run004'),('Bank fabric','bank_fabric_200mhz_ooc_run005'),('Descriptors','descriptors_200mhz_ooc_run002')]:
  entry(name+' OOC','200MHz module-only routed timing and resources; not board timing',BUILD/run,['manifest.json','invocation.json','result.txt','timing_summary.rpt','utilization.rpt'])
 for name,run in [('Core packets','core_packet_xsim_run004'),('DMA core packets','dma_core_packet_xsim_run002'),('Board shell packets','board_shell_200mhz_xsim_run012')]:
  entry(name,'Bounded golden payloads. Vendor DDR is modeled; actual XPM banks only in latter two.',BUILD/run,['manifest.json','result.json','simulation.log'])
 entry('Small ISA reference','Full24layer prefill2 and prefix2 decode; original BF16 quality FAILED',BASE/'evidence/isa_small_run002',['report.json'])
 entry('Extended ISA reference','prefill17 PASS, prefill512 KV tolerance FAIL, decode1024 reference-seeded prefix PASS',BASE/'evidence/isa_extended_run001',['report.json','prefill17.json','prefill512.json','decode1024.json'])
 entry('PS compiler','Control byte identity only; no physical PS execution',BASE/'evidence'/a.ps_run,['report.json'])
 entry('Offline DDR/goldens','Offline tensor computation only; not deployed PS computation',BUILD/a.data_run,['manifest.json','DDR_layout.json'])
 entry('Baremetal ELF','Compiled and floating-point instruction audit only; no physical acceptance',a.firmware_dir or BUILD/'baremetal_run003',['manifest.json','build.log'])
 entry('Full board build','Successful route required before matched artifact handoff; no physical execution',BUILD/a.board_run,['manifest.json','invocation.json','routed_result.txt','timing_summary.rpt','utilization.rpt'])
 if a.board_audit_run:
  entry('Independent routed audit','Exact DCP clock/constraint/timing/DRC and exported reset wiring; static scope only',BUILD/a.board_audit_run,['result.json','timing_summary.rpt','clocks.rpt','drc.rpt','audit_result.txt'])
  entry('Actual vendor reset simulation','Old auxiliary reset failure reproduced; corrected reset releases and control AXI profile responds; no board execution',BASE/'evidence/board_reset_xsim_run006',['result.json','run.tcl','tb_qwen_board_reset.sv','qwen_vendor_reset_test_wrapper.vhd'])
  entry('SD host loader','Real image transfer/SHA with file-backed FatFs stub; no physical SD evidence',BASE/'evidence/sd_loader_host_run003',['report.json'])
  entry('Reset patch validation','Real archives, relocation, idempotent patch, stubbed hardware commands only',BASE/'evidence',['reset_host_patch_validation_run001.json','sd_runtime_audit_run007.json','reset_only_source_identity_run007.json'])
 report={'status':'incomplete_full_model_board_acceptance','current_sources_sha256':{str(f.relative_to(ROOT)):sha(f) for sub in ['rtl','software','python','scripts'] for f in (BASE/sub).glob('*') if f.is_file()},'scoped_evidence':entries,'known_failed_or_unverified':['Original BF16 versus W4 small-probe quality failed','prefill512 KV reference tolerance failed','decode1024 uses a reference-created prefix; no ISA 1023-token chain proof','No successful physical FPGA model acceptance; prior build005 stalled and was withdrawn','No full24layer RTL simulation evidence in bounded packet runs'],'interrupted_runs_preserved':['board_build_run002','board_data_run002','ps_compiler_run002']}
 a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(report,indent=2)+'\n');print(a.out)
if __name__=='__main__':main()
