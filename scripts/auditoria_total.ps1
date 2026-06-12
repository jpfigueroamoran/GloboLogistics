# =====================================================================
# GLOBO LOGISTICS - Auditoria total automatizada (costo $0, corre local)
#
# Uso:   .\scripts\auditoria_total.ps1          # analisis + tests
#        .\scripts\auditoria_total.ps1 -Apk     # ademas compila el APK
#
# Pipeline: flutter analyze -> flutter test -> (opcional) flutter build apk
# Sale con codigo 1 si cualquier paso falla - usable como gate pre-release.
# (Solo caracteres ASCII: PowerShell 5.1 lee .ps1 sin BOM como ANSI.)
# =====================================================================
param([switch]$Apk)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$fallos = @()

Write-Host ""
Write-Host "== 1/3 Analisis estatico (flutter analyze) ==" -ForegroundColor Cyan
flutter analyze --no-pub > "$env:TEMP\globo_analyze.txt" 2>$null
$problemas = Select-String -Path "$env:TEMP\globo_analyze.txt" -Pattern ' error - ', ' warning - '
if ($problemas) {
    $problemas | ForEach-Object { Write-Host ("  " + $_.Line.Trim()) -ForegroundColor Red }
    $fallos += "analyze: $($problemas.Count) error(es)/warning(s)"
} else {
    Write-Host "  OK - 0 errores, 0 warnings" -ForegroundColor Green
}

Write-Host ""
Write-Host "== 2/3 Suite de tests (flutter test) ==" -ForegroundColor Cyan
$testOut = flutter test 2>&1 | Select-Object -Last 1
if ("$testOut" -match 'All tests passed') {
    Write-Host "  OK - $testOut" -ForegroundColor Green
} else {
    Write-Host "  FALLO - $testOut" -ForegroundColor Red
    $fallos += "tests: hay pruebas fallando"
}

if ($Apk) {
    Write-Host ""
    Write-Host "== 3/3 Build Android (flutter build apk --release) ==" -ForegroundColor Cyan
    flutter build apk --release 2>&1 | Select-Object -Last 2 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) { $fallos += "apk: build fallo" }
} else {
    Write-Host ""
    Write-Host "== 3/3 Build APK omitido (usa -Apk para incluirlo) ==" -ForegroundColor DarkGray
}

Write-Host ""
if ($fallos.Count -eq 0) {
    Write-Host "AUDITORIA COMPLETA: todo en verde" -ForegroundColor Green
    exit 0
} else {
    Write-Host "AUDITORIA CON FALLOS:" -ForegroundColor Red
    $fallos | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
    exit 1
}
