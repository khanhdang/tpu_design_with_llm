# Local TPU coding model comparison: Ryzen 9950X / 64 GB DDR5

Fresh copies of `../TPU_qwen3-coder-30b`, with independent model settings and
empty rtl/, tb/, and sim/ directories. Each copy keeps the same architecture,
verification requirements, stage prompts, tool-name instructions, and build loop.

Assumption: CPU inference, with no discrete GPU specified. Qwen3 Coder and GLM
Flash are the first alternatives I would evaluate; the smaller Qwen3.5 profile
is a useful latency comparison. Devstral is a specialized code-agent comparison,
but its dense architecture can be slower on CPU. These are selection hypotheses,
not benchmarks on your machine. Model weights alone fit within 64 GB one at a
time; 64k context cache, runtime overhead, and other applications also consume
RAM. Check actual memory and swapping during a run. No TPU accuracy is assumed.

| Profile | Ollama base tag | Approximate download | Purpose |
| --- | --- | --- | --- |
| [Qwen3 Coder 30B](qwen3-coder-30b/README.md) | `qwen3-coder:30b` | 19 GB | Primary coding baseline |
| [GLM 4.7 Flash](glm-4.7-flash/README.md) | `glm-4.7-flash:latest` | 19 GB | MoE coding and reasoning alternative |
| [Devstral Small 2 24B](devstral-small-2-24b/README.md) | `devstral-small-2:24b` | 15 GB | Code editing and tool-use alternative; dense model |
| [Qwen3.5 9B](qwen3.5-9b/README.md) | `qwen3.5:9b` | about 7 GB | Smaller general model with coding and tool support |

## Run one model

Install current Ollama, OpenCode, Icarus Verilog, make, Bash, and Python 3.9+.
On Debian/Ubuntu the simulation dependencies are:

```sh
sudo apt install iverilog make python3
```

Stop any existing Ollama app/server first. In one terminal, from this directory:

```sh
bash serve_ollama.sh
```

This keeps one model loaded and one inference request active, with 64k context.
If using an existing systemd-managed Ollama service, apply the same environment
settings to that service and restart it instead of launching another server.
The Modelfile in each profile also sets 65536 context on its local alias.

In another terminal, from this directory:

```sh
make setup build PROFILE=qwen3-coder-30b
# Alternatives:
make setup build PROFILE=glm-4.7-flash
make setup build PROFILE=devstral-small-2-24b
make setup build PROFILE=qwen3.5-9b
```

`make setup` downloads the base model and creates a `tpu-<profile>:64k` alias.
It preserves the base model's template and sampling settings. No unmeasured
thread-count override is imposed; Ollama chooses its default CPU threading.
`make build` runs MAC -> PE -> array -> controller -> TPU -> regression, with
verification and up to three attempts per stage. Every profile has separate
logs in `<profile>/sim/build.*`. A rerun starts from MAC and backs up existing
stage sources according to the prompts.

## Run every profile in one loop

```sh
make setup-all build-all
```

This downloads all four models, then runs their builds sequentially, stopping
on the first failed profile. Allow roughly 60 GB of disk space for the base
model downloads, plus overhead and logs. Local aliases reuse model blobs.
Models have not been downloaded or run as part of preparing these folders.
Use `ollama ps` to inspect the active model, processor placement, and context.

## Sources

- [Qwen3 Coder](https://ollama.com/library/qwen3-coder:30b)
- [GLM 4.7 Flash](https://ollama.com/library/glm-4.7-flash)
- [Devstral Small 2](https://ollama.com/library/devstral-small-2/tags)
- [Qwen3.5 9B](https://ollama.com/library/qwen3.5:9b)
- [Ollama OpenCode integration and 64k context requirement](https://docs.ollama.com/integrations/opencode)
- [Ollama memory, concurrency, and server settings](https://docs.ollama.com/faq)
