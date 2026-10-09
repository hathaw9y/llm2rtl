from pathlib import Path
import subprocess, json, re, hashlib
ROOT=Path('/home/shmin/llm2rtl/experiments/verilogeval_v2_gpt61sol_full_20260930_r002')
OUT=Path(__file__).resolve().parent
BIN=Path('/home/shmin/nl2hdl/.conda_pkgs/iverilog-12.0-ha738cfc_1/bin')
names=['Prob034_dff8','Prob053_m2014_q4d','Prob062_bugs_mux2','Prob093_ece241_2014_q3','Prob104_mt2015_muxdff','Prob149_ece241_2013_q4']
records=[]
for arm in ['single_agent','contract_based']:
 for n in names:
  src=ROOT/'evaluation'/arm/n/'final'
  original=(src/'candidate.sv').read_text()
  changes=[]
  if n in ['Prob034_dff8','Prob053_m2014_q4d','Prob104_mt2015_muxdff']:
   signal={'Prob034_dff8':'q','Prob053_m2014_q4d':'out','Prob104_mt2015_muxdff':'Q'}[n]
   changes=[('reference_initialization_only',original.replace('endmodule',f"    initial {signal} = '0;\nendmodule"))]
  elif n=='Prob062_bugs_mux2':
   wide=re.sub(r'output\s+(logic\s+)?out',r'output \1[7:0] out',original)
   changes=[('output_width_only',wide),('width_and_reference_selector',wide.replace('sel ? b : a','sel ? a : b'))]
  elif n=='Prob093_ece241_2014_q3':
   changes=[('reference_mux_in2_only',original.replace("d ? c : 1'b1","d ? 1'b0 : 1'b1"))]
  else:
   if arm=='single_agent':
    revised=original.replace('(level_w > level_r)','(level_w < level_r)')
   else:
    revised=original.replace("else if (level_n > level_r)\n                supplemental_r <= 1'b1;", "else if (level_n > level_r)\n                supplemental_r <= 1'b0;").replace("else if (level_n < level_r)\n                supplemental_r <= 1'b0;", "else if (level_n < level_r)\n                supplemental_r <= 1'b1;")
   changes=[('reference_direction_only',revised)]
  for label, candidate in changes:
   d=OUT/arm/n/label; d.mkdir(parents=True,exist_ok=True)
   (d/'candidate.sv').write_text(candidate)
   for suffix in ['_test.sv','_ref.sv']:
    (d/(n+suffix)).write_bytes((src/(n+suffix)).read_bytes())
   command=[str(BIN/'iverilog'),'-Wall','-Winfloop','-Wno-timescale','-g2012','-s','tb','-o','sim.vvp','candidate.sv',n+'_test.sv',n+'_ref.sv']
   c=subprocess.run(command,cwd=d,capture_output=True,text=True,timeout=30)
   (d/'compile.log').write_text(c.stdout+c.stderr)
   v=None
   if c.returncode==0:
    v=subprocess.run([str(BIN/'vvp'),'sim.vvp'],cwd=d,capture_output=True,text=True,timeout=30)
    (d/'simulation.log').write_text(v.stdout+v.stderr)
   rec={'arm':arm,'problem':n,'diagnostic_change':label,'compile_returncode':c.returncode,'simulation_returncode':v.returncode if v else None,'result_lines':re.findall(r'Mismatches: .*',v.stdout) if v else [],'source_original_sha256':hashlib.sha256(original.encode()).hexdigest(),'command':command}
   (d/'result.json').write_text(json.dumps(rec,indent=2)+'\n'); records.append(rec)
summary={'scope':'Post-evaluation diagnostic copies only. Original candidates, official sources and benchmark scores remain unchanged. Matching reference is not proof of prompt correctness.','results':records}
(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for x in records: print(x['arm'],x['problem'],x['diagnostic_change'],x['compile_returncode'],x['result_lines'])
