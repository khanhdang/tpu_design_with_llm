#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
ollama pull 'devstral-small-2:24b'
ollama create 'tpu-devstral-small-2-24b:64k' -f Modelfile
