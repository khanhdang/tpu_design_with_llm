# tpu_design_with_llm

## Objective

Implement a small systolic-array accelerator for matrix multiplication.

- Use an LLM to assist with the entire design and implementation process.
- Implement the hardware in SystemVerilog HDL.
- Develop a testbench to verify the design.
- Simulate and validate the design using Icarus Verilog.




## Folders

| LLM | Folder | Note | Prompt | Execution Time | Log |
| --- | --- | --- | --- | --- | --- |
| None | [TPU_LLM_Template](TPU_LLM_Template) | A template to run with LLMs; Date: Oct 04, 2026 | N/A | N/A | N/A |
| GPT 5.5 | [TPU_GPT_5.5](TPU_GPT_5.5) | Reasoning-effort: High; Date: Oct 04, 2026 | `check this folder and build` | 9m21s | [log](logs/TPU_GPT_5.5.md)|
| GPT 5.6 Sol | [TPU_GPT_5.6_Sol](TPU_GPT_5.6_Sol) | Reasoning-effort: High; Date: Oct 04, 2026 | `check this folder and build` |  7m57s | [log](logs/TPU_GPT_5.6_Sol.md)|
| GPT 6.1 Sol | [TPU_GPT_6.1_Sol](TPU_GPT_6.1_Sol) | Reasoning-effort: High; Date: Oct 04, 2026 | `check this folder and build` |  9m4s| [log](logs/TPU_GPT_6.1_Sol.md) |
| qwen3-coder:30b | [TPU_qwen3-coder-30b](TPU_Local_Models_CPU_only/qwen3-coder-30b) | Date: Oct 05, 2026 | make build |  | log |
 