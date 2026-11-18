#!/usr/bin/env sh
set -eu

REPO_RAW="${OPTMEMO_RAW_BASE:-https://raw.githubusercontent.com/Moeblack/OptMemo/main}"
OPTMEM_DIR="$HOME/.optmem"
OMP_EXT_DIR="$HOME/.omp/agent/extensions"

download() {
  url="$1"
  out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
  else
    echo "Error: curl or wget is required." >&2
    exit 1
  fi
}

mkdir -p "$OPTMEM_DIR/docs" "$OPTMEM_DIR/memory/TREE" "$OPTMEM_DIR/integrations/omp" "$OMP_EXT_DIR"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${0:-.}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/memo" ] && [ -f "$SCRIPT_DIR/integrations/omp/extension.ts" ]; then
  cp "$SCRIPT_DIR/memo" "$OPTMEM_DIR/memo"
  cp "$SCRIPT_DIR/integrations/omp/extension.ts" "$OPTMEM_DIR/integrations/omp/extension.ts"
  [ -f "$SCRIPT_DIR/integrations/omp/wake.py" ] && cp "$SCRIPT_DIR/integrations/omp/wake.py" "$OPTMEM_DIR/integrations/omp/wake.py"
else
  download "$REPO_RAW/memo" "$OPTMEM_DIR/memo"
  download "$REPO_RAW/integrations/omp/extension.ts" "$OPTMEM_DIR/integrations/omp/extension.ts"
  download "$REPO_RAW/integrations/omp/wake.py" "$OPTMEM_DIR/integrations/omp/wake.py" || true
fi

chmod +x "$OPTMEM_DIR/memo"

if [ ! -f "$OPTMEM_DIR/memory/LOG.txt" ]; then
  : > "$OPTMEM_DIR/memory/LOG.txt"
fi

cat <<'EXT_EOF' > "$OMP_EXT_DIR/optmemo.ts"
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default async function (pi: ExtensionAPI) {
  const entry = pathToFileURL(
    join(homedir(), ".optmem", "integrations", "omp", "extension.ts")
  ).href;
  const { default: optMemo } = await import(entry);
  optMemo(pi);
}
EXT_EOF

if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  echo "Warning: Python 3 not found in PATH. Please install Python 3 to run ~/.optmem/memo." >&2
fi

echo "OptMemo installed. Restart OMP and run /memo to wake memory."
