#!/usr/bin/env python3
"""Deterministic packed-capacity and DDR overlap calculator."""
import argparse, json, math, pathlib

def aligned(n, a):
    if n < 0 or a <= 0: raise ValueError("bytes must be nonnegative and alignment positive")
    return ((n + a - 1) // a) * a

def packed(elements, bits, alignment):
    if elements < 0 or bits <= 0: raise ValueError("elements must be nonnegative and bits positive")
    return aligned((elements * bits + 7) // 8, alignment)

def calculate(c):
    cap=int(c["onchip_capacity_bytes"]); reserve=int(c.get("reserve_bytes",0)); usable=cap-reserve
    if usable < 0: raise ValueError("reserve exceeds capacity")
    resident=streamed=0; rows=[]
    for d in c["datasets"]:
        a=int(d.get("alignment_bytes",1)); copies=int(d.get("copies",1)); mode=d["mode"]
        total=packed(int(d["total_elements"]),int(d["bits"]),a)*copies
        tile=packed(int(d.get("tile_elements",d["total_elements"])),int(d["bits"]),a)*copies
        if mode=="resident": resident += total
        elif mode=="streamed": streamed += tile
        else: raise ValueError("mode must be resident or streamed")
        rows.append({"name":d["name"],"mode":mode,"total_bytes":total,"tile_bytes":tile})
    one=resident+streamed; two=resident+2*streamed; total_resident=sum(r["total_bytes"] for r in rows)
    bw=float(c["sustained_bandwidth_bytes_per_s"]); lat=float(c["transfer_latency_s"]); comp=float(c["compute_tile_s"]); dist=int(c.get("prefetch_distance",1)); tiles=int(c.get("tiles",1))
    if bw<=0 or lat<0 or comp<=0 or dist<=0 or tiles<=0: raise ValueError("invalid timing/bandwidth input")
    payload=streamed/bw; transfer=lat+payload
    latency_overlap=bool(c.get("fixed_latency_overlap_proven",False)); overlap_evidence=c.get("latency_overlap_evidence")
    if latency_overlap and not isinstance(overlap_evidence,str): raise ValueError("latency overlap requires explicit evidence")
    if latency_overlap and not overlap_evidence.strip(): raise ValueError("latency overlap evidence must be nonempty")
    service=payload if latency_overlap else transfer
    steady=service<=comp; prefetch=transfer<=dist*comp; ping_fit=two<=usable; one_fit=one<=usable; resident_fit=total_resident<=usable
    cycle=max(comp,service)
    ping_latency=transfer + comp + (tiles-1)*cycle
    baseline=c.get("measured_resident_latency_s")
    baseline=float(baseline) if baseline is not None else None
    if baseline is None:
        decision="measure"
        reason="measured resident baseline is required"
    elif resident_fit and baseline<=ping_latency:
        decision="resident"; reason="resident fits and measured baseline is no slower"
    elif ping_fit and steady and prefetch and ping_latency<baseline:
        decision="pingpong"; reason="two banks fit and measured overlap comparison wins"
    elif one_fit:
        decision="reduced"; reason="one tile fits but resident or ping-pong gates do not all pass"
    else:
        decision="measure"; reason="no capacity-safe candidate; reduce tile or architecture"
    return {"schema":"fpga-ddr-pingpong-capacity-v2","usable_onchip_bytes":usable,"resident_bytes":resident,"streamed_tile_bytes":streamed,"one_bank_bytes":one,"two_bank_bytes":two,"all_resident_bytes":total_resident,"resident_fits":resident_fit,"one_bank_fits":one_fit,"two_bank_fits":ping_fit,"payload_transfer_s":payload,"transfer_with_latency_s":transfer,"fixed_latency_overlap_proven":latency_overlap,"latency_overlap_evidence":overlap_evidence if latency_overlap else None,"steady_state_service_s":service,"pipeline_cycle_s":cycle,"compute_tile_s":comp,"prefetch_distance":dist,"steady_state_overlap_pass":steady,"prefetch_overlap_pass":prefetch,"predicted_pingpong_latency_s":ping_latency,"measured_resident_latency_s":baseline,"decision":decision,"reason":reason,"datasets":rows}

def main():
    p=argparse.ArgumentParser(); p.add_argument("--config",required=True); p.add_argument("--output")
    a=p.parse_args(); result=calculate(json.loads(pathlib.Path(a.config).read_text())); text=json.dumps(result,sort_keys=True,indent=2)+"\n"
    if a.output: pathlib.Path(a.output).write_text(text)
    else: print(text,end="")
if __name__=="__main__": main()
