# TPU build with qwen3.5:9b

This independent workspace uses Ollama and OpenCode to generate and verify a
small SystemVerilog TPU. The selected model is `qwen3.5:9b`, exposed to OpenCode
as `ollama/tpu-qwen3.5-9b:64k`. Its local Modelfile sets 65536 context tokens.
The settings target one model at a time on a Ryzen 9950X with 64 GB RAM.
CPU speed and SystemVerilog accuracy have not been benchmarked.

## 1. Install the tools once

On Ubuntu/Debian Linux, install the simulator and supporting tools:

```sh
sudo apt update
sudo apt install -y curl bash make python3 iverilog
```

Install [Ollama](https://docs.ollama.com/linux) and
[OpenCode](https://opencode.ai/docs/):

```sh
curl -fsSL https://ollama.com/install.sh | sh
curl -fsSL https://opencode.ai/install | bash
```

Open a new terminal after installation so OpenCode is on PATH. Python 3.9 or
newer is required. On Windows, use these Linux instructions inside WSL2 and
run Ollama in that same environment. On macOS, install the Ollama app from
[ollama.com/download](https://ollama.com/download), install OpenCode using the
command above, and install simulation dependencies with Homebrew:

```sh
brew install icarus-verilog make python
```

## 2. Start Ollama — terminal A

From the repository root, enter this model's folder:

```sh
cd TPU_qwen3.5-9b
```

If the Linux installer already started the Ollama service, stop it before
launching this foreground server:

```sh
sudo systemctl stop ollama
```

On macOS, quit the Ollama app instead. Then start the server:

```sh
make serve
```

Leave terminal A open. This runs `ollama serve` with 65536 context tokens,
one loaded model, and one parallel request. It listens on the default local
endpoint `http://localhost:11434`, which this project's OpenCode config uses.
Run just one Ollama server; it can serve any of the model folders.
These settings apply to the server started by this command.

## 3. Download and configure this model — terminal B

Open a second terminal. From the repository root:

```sh
cd TPU_qwen3.5-9b
make setup
make doctor-opencode
```

`make setup` executes:

```sh
ollama pull qwen3.5:9b
ollama create tpu-qwen3.5-9b:64k -f Modelfile
```

The alias reuses the downloaded weights and sets 64k context without changing
the original model's template. Repeat setup after changing the Modelfile.
Environment checks must report `ENVIRONMENT: PASS` before building.

## 4. Run the complete build — terminal B

Stay in this folder and run:

```sh
make build
```

The loop runs MAC -> PE -> systolic array -> controller -> TPU top -> full
regression. Each stage gets a fresh OpenCode session. When supported, the launcher uses
`--standalone` for a private server.
The script independently runs its verification target before moving on.
Failed verification is fed back to the model for repair, with up to three
attempts per stage. An OpenCode failure or exhausted attempts stops the build.
The unattended loop uses `--auto` for file edits and shell execution, subject
to explicitly denied permissions.

Optional commands:

```sh
BUILD_ATTEMPTS=5 make build  # Allow five attempts per stage
make opencode               # Interactive OpenCode with this configured model
make test                   # Verify generated RTL without calling the model
```

No slash commands or PROFILE variable are needed for `make build`.

## 5. Find outputs and troubleshoot

Generated RTL goes in `rtl/`, testbenches in `tb/`, and simulation output in
`sim/`. Each build stores model output and verification logs in a unique
`sim/build.*` directory. Compiler and simulation logs are also written as
`sim/<module>_compile.log` and `sim/<module>_run.log`.

- Connection refused: check that terminal A is still running `make serve`.
- Address already in use: an Ollama server/app is already running; stop it
  before starting the configured foreground server.
- Model missing: run `make setup` while Ollama is running.
- Missing executable: install the tool named by `make doctor-opencode`.
- CLI compatibility: the launcher detects `--standalone` and uses it only
  when supported. Unattended builds require `--auto`; check `opencode run --help`.
- Invalid tool name: inspect the agent log. `docs/local-tools.md` instructs
  the model to use the available tools; model tool-use reliability still needs
  actual testing.
- Slow generation: CPU inference can take time. Use `ollama ps` to inspect
  processor placement and context; check RAM use and swapping.

Rerunning `make build` starts at MAC. Stage prompts back up existing sources
under `sim/restart-backup/` before fresh implementation. `make clean` removes
named simulation artifacts; it keeps RTL and testbenches.
Stop a build with Ctrl+C in terminal B, and stop the foreground Ollama server
with Ctrl+C in terminal A. To restore the Linux service afterward:

```sh
sudo systemctl start ollama
```

## Project references

- [AGENTS.md](AGENTS.md): assistant and verification rules.
- [Architecture](docs/architecture.md): interfaces and timing.
- [Stage prompts](prompts.md): implementation requirements.
- [Ollama OpenCode integration](https://docs.ollama.com/integrations/opencode):
  the recommended context is at least 64k, with additional memory overhead.
- [Ollama model listing](https://ollama.com/library/qwen3.5).
