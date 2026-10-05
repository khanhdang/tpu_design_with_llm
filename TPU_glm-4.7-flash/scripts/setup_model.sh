#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
ollama pull 'glm-4.7-flash:latest'
ollama create 'tpu-glm-4.7-flash:64k' -f Modelfile
