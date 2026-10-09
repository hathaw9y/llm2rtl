"""Shared isolated native-controller verification utilities."""
import hashlib,json,os,queue,subprocess,threading,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
BASE=ROOT/'ip/infrastructure/cmd_dispatcher_template'
VIVADO=Path(os.environ.get('VIVADO_BIN','/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def logged(command,cwd,log):
    if log.exists():raise RuntimeError(f'Immutable log already exists: {log}')
    with log.open('w') as stream:
        p=subprocess.run([str(x) for x in command],cwd=cwd,stdout=stream,stderr=subprocess.STDOUT,timeout=600)
    log.with_suffix(log.suffix+'.exit').write_text(str(p.returncode)+'\n')
    if p.returncode:raise RuntimeError(f'Command exit{p.returncode}; see {log}')
def materialize_banks(work, extension=False):
    directory=ROOT/'ip/infrastructure/bank_subsystem_template/rtl'
    package=(directory/'bank_config_pkg.sv.tpl').read_text().replace('{{PACKAGE_NAME}}','controller_test_config_pkg')
    top=(directory/'bank_subsystem.sv.tpl').read_text().replace('{{PACKAGE_NAME}}','controller_test_config_pkg').replace('{{MODULE_NAME}}','controller_test_bank')
    if extension:
        package=package.replace("WR_CAPABILITIES = '{8'h02,8'h02}","WR_CAPABILITIES = '{8'h12,8'h12}").replace("RD_CAPABILITIES = '{8'h04,8'h04}","RD_CAPABILITIES = '{8'h0c,8'h0c}")
        top=top.replace('// USER_PORTS_BEGIN', '// USER_PORTS_BEGIN\n    input logic probe_read_enb,\n    input logic [31:0] probe_read_addrb,\n    output logic probe_read_ready,probe_read_valid,\n    output logic [127:0] probe_read_doutb,\n    input logic probe_write_ena,\n    input logic [31:0] probe_write_addra,\n    input logic [127:0] probe_write_dina,\n    input logic [15:0] probe_write_wea,\n    output logic probe_write_ready,')
        top=top.replace('// USER_ROUTING_BEGIN', '// USER_ROUTING_BEGIN\n    if(bank_rd_owner_port[1]==3 || probe_read_enb)begin\n      rd_req_valid[1]=probe_read_enb;rd_req_owner[1]=3;rd_req_addr[1]=probe_read_addrb;\n    end\n    if(bank_wr_owner_port[0]==4 || probe_write_ena)begin\n      wr_req_valid[0]=probe_write_ena;wr_req_owner[0]=4;wr_req_addr[0]=probe_write_addra;\n      wr_req_data[0]=probe_write_dina;wr_req_strb[0]=probe_write_wea;\n    end')
        top=top.replace('// USER_OUTPUTS_BEGIN', '// USER_OUTPUTS_BEGIN\n  assign probe_read_ready=rd_req_ready[1]&&rd_req_owner[1]==3;\n  assign probe_read_valid=rd_rsp_valid[1]&&rd_rsp_owner[1]==3;\n  assign probe_read_doutb=rd_rsp_data[1];\n  assign probe_write_ready=wr_req_ready[0]&&wr_req_owner[0]==4;\n  always_ff @(posedge aclk) if(aresetn && ((probe_read_enb&&s2mm_bank_enb[1]) || (probe_write_ena&&mm2s_bank_ena[0])))\n    $fatal(1,"probe single-source scheduler violated");')
    cfg=work/'controller_test_config_pkg.sv';rtl=work/'controller_test_bank.sv';cfg.write_text(package);rtl.write_text(top)
    children=sorted((ROOT/'ip/infrastructure/bank_subsystem/rtl').glob('bank_native_*.sv'))
    return [cfg,*children,ROOT/'ip/infrastructure/datamover_engine/rtl/bram_bank.sv',ROOT/'ip/infrastructure/datamover_engine/rtl/uram_bank.sv',rtl]
def manifest(sources,evidence,kind):
    paths=list(dict.fromkeys([*sources,*sorted((BASE/'scripts').glob('*.py')),BASE/'scripts/run_ooc_synthesis.tcl',BASE/'template_contract.json',BASE/'template_index.json',ROOT/'ip/infrastructure/bank_subsystem/contracts/native_v2.json',*sorted((ROOT/'ip/infrastructure/bank_subsystem_template/rtl').glob('*.tpl'))]))
    identity={'kind':kind,'part':'xczu7ev-ffvc1156-2-e','clock_ns':5.0,'sources':{str(p):sha(p) for p in paths}}
    logged([VIVADO/'vivado','-version'],evidence,evidence/'version.log')
    identity['vivado_version']=(evidence/'version.log').read_text()
    (evidence/'source_manifest.json').write_text(json.dumps(identity,indent=2)+'\n')
    return identity
def verify_identity(identity):
    for name,expected in identity['sources'].items():
        if sha(Path(name))!=expected:raise RuntimeError(f'Source changed during run: {name}')
def snapshot_run(snapshot,work,log,marker):
    env=os.environ.copy();env['LD_LIBRARY_PATH']=str(VIVADO.parent/'lib/lnx64.o')
    p=subprocess.Popen([str(snapshot)],cwd=work,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    lines=[];messages=queue.Queue();deadline=time.monotonic()+120
    def pump():
        for line in p.stdout:messages.put(line)
        messages.put(None)
    threading.Thread(target=pump,daemon=True).start()
    def until(marker):
        while True:
            line=messages.get(timeout=max(0.01,deadline-time.monotonic()))
            if line is None:raise RuntimeError(f'XSIM ended before {marker}')
            lines.append(line)
            if marker in line:return
    try:
        until('=elaboration-done');p.stdin.write('-exec-run\n');p.stdin.flush();until('reason="run-complete"')
        p.stdin.write('-exec-continue\n');p.stdin.flush();until('reason="finish"');p.stdin.write('-gdb-exit\n');p.stdin.flush();p.wait(timeout=20)
        while not messages.empty():
            line=messages.get_nowait()
            if line is not None:lines.append(line)
    finally:
        if p.poll() is None:p.kill();p.wait()
        log.write_text(''.join(lines));log.with_suffix(log.suffix+'.exit').write_text(str(p.returncode)+'\n')
    decoded=''.join(json.loads(line[1:].strip()) for line in lines if line.startswith('@'))
    log.with_suffix(log.suffix+'.stdout').write_text(decoded)
    if p.returncode or decoded.splitlines().count(marker)!=1:raise RuntimeError(f'XSIM failed/exact PASS absent: {log}')
