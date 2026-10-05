#!/usr/bin/env bash
set -euo pipefail
# Run after stopping an existing Ollama server/app. Settings apply to this server.
export OLLAMA_CONTEXT_LENGTH=65536
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_MAX_LOADED_MODELS=1
exec ollama serve
