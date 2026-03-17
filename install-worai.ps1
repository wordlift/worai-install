$ErrorActionPreference = "Stop"

$MinPythonMajor = 3
$MinPythonMinor = 10

function Write-Info([string]$Message) {
    Write-Host "[worai-install] $Message"
}

function Test-PythonVersion([string]$PythonCmd) {
    try {
        & $PythonCmd -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Get-PythonCommand() {
    if (Get-Command python -ErrorAction SilentlyContinue) { return "python" }
    if (Get-Command py -ErrorAction SilentlyContinue) { return "py -3" }
    return $null
}

function Ensure-Python() {
    $pythonCmd = Get-PythonCommand
    if ($pythonCmd -and (Test-PythonVersion $pythonCmd)) {
        Write-Info "Using $pythonCmd ($(& $pythonCmd --version 2>&1))"
        return $pythonCmd
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Installing Python 3.12 with winget..."
        winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
    }
    else {
        throw "Python >= 3.10 is required. Install Python from https://www.python.org/downloads/windows/ and re-run."
    }

    $pythonCmd = Get-PythonCommand
    if (-not $pythonCmd) {
        throw "Python command not found after installation."
    }
    if (-not (Test-PythonVersion $pythonCmd)) {
        throw "Python >= 3.10 is required."
    }

    Write-Info "Using $pythonCmd ($(& $pythonCmd --version 2>&1))"
    return $pythonCmd
}

function Ensure-Pipx([string]$PythonCmd) {
    if (Get-Command pipx -ErrorAction SilentlyContinue) {
        return "pipx"
    }

    Write-Info "Installing pipx..."
    & $PythonCmd -m pip install --user --upgrade pip pipx
    & $PythonCmd -m pipx ensurepath

    if (Get-Command pipx -ErrorAction SilentlyContinue) {
        return "pipx"
    }

    $userPipx = Join-Path $HOME ".local\bin\pipx.exe"
    if (Test-Path $userPipx) {
        return $userPipx
    }

    throw "pipx was installed but is not on PATH. Open a new PowerShell and run again."
}

function Install-OrUpgrade-Worai([string]$PipxCmd) {
    $installed = $false
    try {
        & $PipxCmd runpip worai --version | Out-Null
        $installed = $true
    }
    catch {
        $installed = $false
    }

    if ($installed) {
        Write-Info "Upgrading worai..."
        & $PipxCmd upgrade worai
    }
    else {
        Write-Info "Installing worai..."
        & $PipxCmd install worai
    }
}

Write-Info "Starting worai installer..."
$pythonCmd = Ensure-Python
$pipxCmd = Ensure-Pipx -PythonCmd $pythonCmd
Install-OrUpgrade-Worai -PipxCmd $pipxCmd
Write-Info "Done."
Write-Info "If this is your first pipx install, open a new terminal before running: worai --help"
if (Get-Command worai -ErrorAction SilentlyContinue) {
    Write-Info "Installed version: $(& worai --version 2>&1)"
}
