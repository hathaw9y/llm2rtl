# Infrastructure RTL by role

This directory is a navigation view of the reusable infrastructure RTL. It follows
the bank, DataMover, controller, and utility separation of the previous HDL tree.

| Directory | Sources | Contents |
| --- | ---: | --- |
| `bank/` | 13 | BRAM/URAM, arbitration, ownership, routers, native memories, legacy bank subsystem and package |
| `datamover/` | 10 | Engine, command queues, channels, status and both distinct adapter APIs |
| `controller/` | 2 | Sparse ISA dispatcher and command-dispatcher template implementation |
| `utils/` | 5 | FIFO, pipeline and AXIS width converters |
| `integration/` | 1 | Execution fabric |

Every `.sv` entry is a relative symlink to the existing regular source file in its
module packet. The original packet paths remain the source authority and retain
their contracts, testbenches, scripts, source hashes and historical evidence.
This view does not copy, rename, or change module definitions, interfaces, reset
semantics, or cycle behavior.

Use the infrastructure source manifest/resolver for builds: it selects dependencies
in order and emits the original regular source paths. Do not compile both this
view and the packet RTL trees or collect all sources with a recursive glob.
The parameterized native-bank adapters and the fixed-width valid/ready stream-bank
adapters remain separate implementations with different public contracts.

Templates ending in `.sv.tpl`, testbenches, simulator stubs, generated artifacts,
and historical snapshots are outside this active RTL view.
