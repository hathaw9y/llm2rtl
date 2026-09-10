# Resource accounting

Every Vivado report must attribute memory and logic by ownership hierarchy.

## Memory classes

1. `ip_internal_private`: memory instantiated inside one IP and invisible to
   the scheduler, such as a GEMM tile buffer or local skid FIFO.
2. `vendor_child_private`: memory inside an exclusively owned vendor IP, such
   as AXI DataMover command/data FIFOs.
3. `system_shared_pl`: BRAM/URAM banks owned by the shared buffer manager and
   addressed by the scheduler.
4. `external_ps_ddr`: Zynq PS DDR storage accessed through HP/HPC ports.

Reports must not call DataMover FIFO BRAM "fabric BRAM". The first board smoke
uses zero fabric-private BRAM and five DataMover FIFO blocks: four RAMB36 and
one RAMB18.

## Reporting rule

Resource evidence records both `exclusive_ip_cost` and `shared_system_cost`.
Hierarchy paths are mandatory so a parent integration report cannot double
count a child IP or silently attribute vendor FIFO memory to custom RTL.
