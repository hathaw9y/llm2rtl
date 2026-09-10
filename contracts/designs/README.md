# Generated design contracts

Create a fresh `<design_id>/<revision>/` directory for each approved design revision.
Start from `contracts/templates/contract_index.json`, fill its identity and exact
repository-relative paths, and reference only the applicable completed contracts.
Place module-specific contracts under that revision's `modules/<module_id>/`.
For model generation, preserve the parent-authored `model_graph.json`, required
`module_mapping.json`, and referencing `bringup.json` under `planning/`. See
[planning rules and the separate reference gate](../../docs/model_graph_bringup.md).
Author temporary planning before `init`, then relocate and rehash the references;
`init` creates a fresh revision and does not generate these planning files.
Settle final paths before presenting the mapping for user approval. Keep the
actual user request/decision in a separate `module_mapping_approval.json` bound
to the mapping hash. Parent review is not user approval. No implementation
contract freeze or implementation dispatch is allowed until that approval exists.

Parent planning, implementers and independent reviewers consume the same frozen
index. No generated design or prior approval is bundled here. Generated folders
are ignored by Git; this README is retained.
