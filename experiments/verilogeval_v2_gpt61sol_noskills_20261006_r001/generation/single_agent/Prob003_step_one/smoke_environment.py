#!/usr/bin/env python3
"""Exercise fixed development tooling in this exact worker environment."""
import json
import subprocess
import sys
from pathlib import Path

root = Path.cwd()
fixture = root/'environment_smoke'
fixture.mkdir(exist_ok=True)
good = '''module TopModule(input logic clk, input logic d, output logic q);
always_ff @(posedge clk) q <= d;
endmodule
'''
tb = '''`timescale 1ns/1ps
module dev_tb;
logic clk=0, d=0; wire q;
TopModule dut(.clk(clk),.d(d),.q(q));
initial begin
 #2; clk=1; #1; if(q !== 0) $fatal(1,"Expected zero");
 clk=0; d=1; #2; clk=1; #1; if(q !== 1) $fatal(1,"Expected one");
 $display("PASS: smoke checks"); $finish;
end
initial begin #100; $fatal(1,"Timeout"); end
endmodule
'''
helper = root/'dev_check.py'
outcomes = []
for name, source, expected in [('correct', good, True),
                              ('injected_fault', good.replace('q <= d', 'q <= ~d'), False)]:
    directory = fixture/name
    directory.mkdir(exist_ok=False)
    (directory/'candidate.sv').write_text(source)
    (directory/'dev_tb.sv').write_text(tb)
    p = subprocess.run([sys.executable, str(helper), '--label', 'initial'],
                       cwd=directory, capture_output=True, text=True, timeout=60)
    result = json.loads((directory/'dev_final_result.json').read_text())
    assert (result['status'] == 'passed') == expected, result
    assert result['compile']['returncode'] == 0, result
    outcomes.append({'case': name, 'expected_pass': expected, 'observed': result['status']})
    if not expected:
        (directory/'candidate.sv').write_text(good)
        subprocess.run([sys.executable, str(helper), '--label', 'revision_1'],
                       cwd=directory, capture_output=True, text=True, timeout=60)
        result = json.loads((directory/'dev_final_result.json').read_text())
        assert result['status'] == 'passed'
        outcomes.append({'case': 'repair', 'expected_pass': True, 'observed': result['status']})
report = {'status': 'passed', 'checks': outcomes}
(root/'environment_smoke.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report))
