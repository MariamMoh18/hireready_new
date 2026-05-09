# Run this in PowerShell AFTER closing all terminals and Cursor windows that use .venv
# (or close only the terminals, then run this in a NEW terminal)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Removing old .venv (ignore errors if files are in use)..." -ForegroundColor Yellow
Remove-Item -Recurse -Force .venv -ErrorAction SilentlyContinue

if (Test-Path .venv_new) {
    Write-Host "Renaming .venv_new to .venv..." -ForegroundColor Cyan
    Rename-Item -Path .venv_new -NewName .venv
}

$py = ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    Write-Host "Creating new venv with Python 3.14..." -ForegroundColor Cyan
    py -m venv .venv
}

Write-Host "Bootstrapping pip..." -ForegroundColor Cyan
& $py -m ensurepip --upgrade

Write-Host "Upgrading pip and installing requirements..." -ForegroundColor Cyan
& $py -m pip install --upgrade pip
& $py -m pip install -r requirements.txt

Write-Host "Done. Activate with: .venv\Scripts\Activate.ps1" -ForegroundColor Green
