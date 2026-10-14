# Staged implementation prompts

Use the prompt files below with any cloud or local LLM assistant. Include
`AGENTS.md`, `docs/architecture.md`, and `Makefile` in its context and give it
file-editing and shell access. With a chat-only model, apply its proposed files
locally, run the make target yourself, and return the real logs for correction.

| Order | Prompt | Verification | OpenCode command |
| --- | --- | --- | --- |
| 1 | [MAC](prompts/mac.md) | `make mac` | `/mac` |
| 2 | [PE](prompts/pe.md) | `make pe` | `/pe` |
| 3 | [Systolic array](prompts/array.md) | `make array` | `/array` |
| 4 | [Controller](prompts/controller.md) | `make controller` | `/controller` |
| 5 | [TPU top](prompts/tpu.md) | `make tpu`, then `make test` | `/tpu` |
| 6 | [Regression](prompts/regression.md) | `make test` | `/regression` |

Paste the complete contents of one prompt file into your client, or run its
OpenCode command. Both workflows use these same files. Restart OpenCode after
changing command templates. Start a fresh session between stages when needed.

Each implementation prompt authorizes a fresh rewrite of its own RTL and
testbench, archiving existing versions under `sim/restart-backup/`. Other
stages remain intact. The regression prompt verifies and repairs the design.

Wait for an actual simulation PASS before requesting the next stage. After a
failed lower-stage check, return to that stage. Old logs and chat claims are
not evidence for a new run. If the assistant stops before verification, use:

```text
Continue the current stage. Run its make target with the shell tool now.
Read and fix the real compiler/simulation failures, then rerun until PASS.
Do not move to the next stage or report success without executed verification.
```
