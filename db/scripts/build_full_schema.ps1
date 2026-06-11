# Пересобрать 00_full_schema.sql из частей 01–09
$root = $PSScriptRoot
$out = Join-Path $root "00_full_schema.sql"
$names = @(
    "01_init.sql","02_lookups.sql","03_users_auth.sql","04_commerce.sql",
    "05_content.sql","06_system.sql","07_logic.sql","08_seed.sql","09_grants.sql"
)
$header = @"
-- =============================================================================
-- 00_full_schema.sql — ПОЛНАЯ СХЕМА (для DBeaver)
-- =============================================================================
-- Подключение: база qr_pamyat
-- Выполнение:  Alt+X (Execute SQL Script)
-- =============================================================================

"@
$parts = @($header)
foreach ($name in $names) {
    $f = Join-Path $root $name
    if (-not (Test-Path $f)) { Write-Error "Missing $f" }
    $parts += ""
    $parts += "-- ########## $name ##########"
    $parts += ""
    $parts += Get-Content $f -Raw -Encoding UTF8
}
Set-Content -Path $out -Value ($parts -join "`n") -Encoding UTF8 -NoNewline
Write-Host "OK: $out"
