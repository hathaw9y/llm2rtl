# FPGA board build failure patterns

## Source and packaging

- A manifest file count passed while reachable leaf modules were omitted. Prove transitive closure and elaborate both repository and packaged copies.
- RTL changed but the prior packaged IP, XPR, DCP, BIT, or HWH was reused. Any reachable change invalidates downstream artifacts.
- Component metadata listed files that were missing or byte-different in the copied package. Compare exact sets and hashes.

## Vivado object selection

- A property was read from the target address segment while mapping properties lived on the address-space mapping object.
- Hierarchical `NAME` patterns confused address block, instance, and mapped-segment names.
- Full hierarchical pin paths passed positionally with `-hierarchical` returned empty collections.
- Logical reset-net names differed from hierarchical aliases and post-route replicas.
- Bracketed generated names were interpreted as glob syntax. Prefer properties, escaped regular expressions, and exact object sets.
- A design container name returned by `current_design` was mistaken for the RTL
  top. Validate the design object's `TOP`/`PART` and the unique root cell
  separately.
- A property value beginning with `-` was parsed as a `set_property` option.
  Use one `-dict` transaction, exact readback, and a real zero-progress project
  probe before the production launch.

Always guard collection count before property access. Preserve a current-context read-only probe and add missing, duplicate, extra, renamed, wrong-property, and malformed negatives.

## Stage-dependent reports

- A scoped `LUT as Memory` row appeared once after synthesis and twice after routing.
- Whole-design RAMD counts differed from custom scoped RAMD counts and changed during optimization.
- Check-timing categories differed between synth and routed contexts.
- Reset replica/LUT/BUFG topology varied between implementations while stable semantic endpoints remained.
- Packed LUT primitive counts did not equal utilization-table logic LUT values.
- A table-of-contents heading was counted as a report body, causing a false
  cardinality failure. Anchor numbered body sections.
- A placed congestion report lacked a Router section that exists only after
  route. Give each design stage its own required-section contract.
- An empty "above level 5" table was misreported as L5-free. Generate an
  L5-inclusive report before asserting an L5=0 policy gate.
- Constant pseudo-cells were counted as functional unplaced primitives. Record
  both classes and require functional unplaced count zero.

Maintain separate synth and route parsers. Bind stable semantic sets and observe physical topology without assuming a previous implementation's replica names or counts unless policy requires them.

## Tcl and packet infrastructure

- A literal `\nputs` sequence caused a late Tcl parse error not reached by fixtures.
- A mistyped or first-line-only Vivado version regex rejected or ambiguously accepted a tool banner.
- A safe suite worked only from repository cwd.
- A readiness log or checker was not included in the final packet manifest.
- A cloned tree manifest ignored empty directories, symlinks, FIFOs, or TOCTOU changes.
- Disk exhaustion occurred during a large project clone.
- A validation-only checker repaired a missing staged file, hiding tampering.
- Local seal validation ran before lengthy authority checks, leaving a final
  TOCTOU window before promotion.
- An assumed Tcl collection helper was unavailable in the selected Vivado
  version, so reports were missing even though routing completed.

Execute late serialization blocks, run suites from an unrelated absolute cwd, bind their final outputs, use no-follow typed inventories, recheck clones, and enforce a pre-owner free-space threshold.

Probe nontrivial Tcl commands and options with the exact supported tool version.
Prefer collection `-filter` expressions over unproven helpers. A missing helper
or report makes the metric unavailable; never infer zero. Keep validation-only
paths read-only, and perform the complete no-write seal check immediately before
the atomic rename.

## Signoff and artifacts

- Successful route/bit generation was followed by a report-parser failure; the BIT existed but was not signoff-qualified.
- L5 congestion remained despite positive timing and zero route errors.
- XSA HWH cardinality assumptions were wrong, or the archive accepted extra/missing/unsafe members.
- A file rename was mistaken for BIT/HWH compatibility.

Publication requires the full acceptance policy, not the existence of a `.bit`. Validate the XSA container, embedded BIT, all required HWH files, routed reports, classifier, and manifests from the staged copy.

## One-shot recovery

- Never retry a consumed token.
- Never mutate previous evidence to make a recovery pass.
- Freeze the actual terminal tree and classify what completed.
- Prefer postprocess-only recovery only when route, timing, congestion, DRC, methodology, BIT, and routed DCP are independently proven acceptable.
- Otherwise start from the newest uncontaminated checkpoint allowed by evidence, or rebuild from source.
- Every recovery needs a fresh namespace and a regression for the preceding failure.
