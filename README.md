# worai-install

Public install scripts for `worai`.

## One-liners

- macOS/Linux:
  - `curl -fsSL https://raw.githubusercontent.com/wordlift/worai-install/main/install-worai.sh | bash`
- Windows PowerShell:
  - `irm https://raw.githubusercontent.com/wordlift/worai-install/main/install-worai.ps1 | iex`

## Verify before running

- macOS/Linux:
  - `curl -fsSL -o /tmp/install-worai.sh https://raw.githubusercontent.com/wordlift/worai-install/main/install-worai.sh && less /tmp/install-worai.sh && bash /tmp/install-worai.sh`
- Windows PowerShell:
  - `irm https://raw.githubusercontent.com/wordlift/worai-install/main/install-worai.ps1 -OutFile $env:TEMP\install-worai.ps1; notepad $env:TEMP\install-worai.ps1; & $env:TEMP\install-worai.ps1`
