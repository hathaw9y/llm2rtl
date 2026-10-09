import os,json,queue,threading,time,subprocess
from pathlib import Path
VIVADO=Path(os.environ.get("VIVADO_BIN","/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin"))
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
