#!/usr/bin/env python3
"""Audit exported reset/clock wiring; static scope, not physical FPGA proof."""
import argparse,json,xml.etree.ElementTree as ET
from pathlib import Path
def check(path):
 root=ET.parse(path);modules={m.get('INSTANCE'):m for m in root.iter('MODULE')}
 def port(module,name):
  matches=[p for p in modules[module].iter('PORT') if p.get('NAME')==name]
  if len(matches)!=1:raise ValueError('Missing/ambiguous port '+module+'/'+name)
  return matches[0]
 def param(module,name):
  matches=[p for p in modules[module].iter('PARAMETER') if p.get('NAME')==name]
  if len(matches)!=1:raise ValueError('Missing/ambiguous parameter '+module+'/'+name)
  return int(matches[0].get('VALUE'),0)
 if param('hard_reset','C_EXT_RESET_HIGH')!=0:raise ValueError('PS resetn must be active-low')
 if param('hard_reset','C_AUX_RESET_HIGH')!=1:raise ValueError('Low auxiliary input would hold reset asserted')
 if param('zero','CONST_VAL')!=0 or param('one','CONST_VAL')!=1:raise ValueError('Wrong reset constants')
 requirements=[('hard_reset','aux_reset_in',port('zero','dout').get('SIGNAME')),
  ('hard_reset','mb_debug_sys_rst',port('zero','dout').get('SIGNAME')),
  ('hard_reset','dcm_locked',port('one','dout').get('SIGNAME')),
  ('hard_reset','ext_reset_in',port('ps','pl_resetn0').get('SIGNAME'))]
 for module,name in [('control_bus','aresetn'),('command_controller','s_axi_aresetn'),('executor','rst_n')]:
  requirements.append((module,name,port('hard_reset','peripheral_aresetn').get('SIGNAME')))
 for module,name in [('hard_reset','slowest_sync_clk'),('control_bus','aclk'),('command_controller','s_axi_aclk'),('executor','clk'),('ps','maxihpm0_fpd_aclk')]:
  requirements.append((module,name,port('ps','pl_clk0').get('SIGNAME')))
  if port(module,name).get('CLKFREQUENCY')!='200000000':raise ValueError('Wrong clock frequency '+module+'/'+name)
 for module,name,net in requirements:
  if not net or port(module,name).get('SIGNAME')!=net:raise ValueError('Wrong connection '+module+'/'+name)
 if port('hard_reset','aux_reset_in').get('POLARITY')!='ACTIVE_HIGH':raise ValueError('Auxiliary pin polarity mismatch')
 return {'status':'passed_exported_board_reset_clock_wiring','scope':'Static HWH connections only; vendor dynamic reset test and routed audit required separately','connections_checked':len(requirements),'physical_board_execution':False}
def main():
 p=argparse.ArgumentParser();p.add_argument('hwh',type=Path);a=p.parse_args();print(json.dumps(check(a.hwh),indent=2))
if __name__=='__main__':main()
