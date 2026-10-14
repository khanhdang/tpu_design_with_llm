# CLAUDE.md

Claude Code entry point for this TPU workspace. The project rules live in
AGENTS.md and the interface/timing contract in docs/architecture.md; both are
imported below and apply in full.

@AGENTS.md
@docs/architecture.md

## Claude Code notes

- Work only inside this folder (`TPU_Haiku_5.5_med`). Sibling `TPU_*` folders
  are other models' results; do not read, copy, or compare against them.
- Stage prompts are available as slash commands: `/mac`, `/pe`, `/array`,
  `/controller`, `/tpu`, `/regression`. Each loads the matching file under
  `prompts/`, the same text used by the other clients.
- Run verification with the Makefile targets (`make mac` ... `make test`) from
  this folder. Do not invoke iverilog/vvp by hand as a substitute for the
  runner's PASS/FAIL decision.
- AGENTS.md, docs/, prompts/, Makefile, and scripts/ are the fixed benchmark
  harness; `.claude/settings.json` denies edits to them.
- This folder sits on an external macOS volume that creates `._*` AppleDouble
  files. Ignore them; never create sources with that prefix.
