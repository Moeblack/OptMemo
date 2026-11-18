$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoRaw = if ($env:OPTMEMO_RAW_BASE) { $env:OPTMEMO_RAW_BASE } else { "https://raw.githubusercontent.com/Moeblack/OptMemo/main" }
$OptMemDir = Join-Path $HOME ".optmem"
$OmpExtDir = Join-Path $HOME ".omp\agent\extensions"

New-Item -ItemType Directory -Force -Path `
  (Join-Path $OptMemDir "docs"), `
  (Join-Path $OptMemDir "memory\TREE"), `
  (Join-Path $OptMemDir "integrations\omp"), `
  $OmpExtDir | Out-Null

$LocalDir = if ($PSScriptRoot) { $PSScriptRoot } else { "" }
if ($LocalDir -and (Test-Path (Join-Path $LocalDir "memo")) -and (Test-Path (Join-Path $LocalDir "integrations\omp\extension.ts"))) {
  Copy-Item -Force (Join-Path $LocalDir "memo") (Join-Path $OptMemDir "memo")
  Copy-Item -Force (Join-Path $LocalDir "integrations\omp\extension.ts") (Join-Path $OptMemDir "integrations\omp\extension.ts")
  $LocalWake = Join-Path $LocalDir "integrations\omp\wake.py"
  if (Test-Path $LocalWake) {
    Copy-Item -Force $LocalWake (Join-Path $OptMemDir "integrations\omp\wake.py")
  }
} else {
  Invoke-WebRequest -Uri "$RepoRaw/memo" -OutFile (Join-Path $OptMemDir "memo")
  Invoke-WebRequest -Uri "$RepoRaw/integrations/omp/extension.ts" -OutFile (Join-Path $OptMemDir "integrations\omp\extension.ts")
  try {
    Invoke-WebRequest -Uri "$RepoRaw/integrations/omp/wake.py" -OutFile (Join-Path $OptMemDir "integrations\omp\wake.py")
  } catch {}
}

$LogFile = Join-Path $OptMemDir "memory\LOG.txt"
if (-not (Test-Path $LogFile)) {
  New-Item -ItemType File -Force -Path $LogFile | Out-Null
}

$LoaderCode = @'
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
'@
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Join-Path $OmpExtDir "optmemo.ts"), "$LoaderCode`n", $Utf8NoBom)

if (-not (Get-Command python3 -ErrorAction SilentlyContinue) -and -not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
  Write-Warning "Python 3 not found in PATH. Please install Python 3 to run ~/.optmem/memo."
}

Write-Host "OptMemo installed. Restart OMP and run /memo to wake memory."
