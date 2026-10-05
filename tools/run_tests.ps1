# Desk Exorcist - headless test suite runner (ROADMAP 1.4).
#
# Godot is NOT on PATH on this machine; the full path is required.
# Usage (from the repo root or anywhere):
#     powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_tests.ps1
# Exit code 0 = all checks passed.

param(
	[string]$Godot = 'C:\Program Files\Godot\Godot.exe',
	[string]$Project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

if (-not (Test-Path -LiteralPath $Godot)) {
	Write-Error "Godot not found at '$Godot'. Pass -Godot <path> to override."
	exit 2
}

$out = Join-Path $Project 'test_out.log'
$err = Join-Path $Project 'test_err.log'

$proc = Start-Process -FilePath $Godot `
	-ArgumentList '--headless','--path', $Project,'res://tests/tests.tscn' `
	-NoNewWindow -Wait -PassThru `
	-RedirectStandardOutput $out -RedirectStandardError $err

# Echo the suite summary so the result is visible on the console.
if (Test-Path -LiteralPath $out) {
	Get-Content -LiteralPath $out | Select-Object -Last 2
}
Write-Output ('EXITCODE=' + $proc.ExitCode)
exit $proc.ExitCode
