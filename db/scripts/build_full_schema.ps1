# Пересобрать 00_full_schema.sql из частей 01–13
$root = $PSScriptRoot
$out = Join-Path $root "00_full_schema.sql"
$names = @(
    "01_extensions.sql","02_lookups.sql","03_users_auth.sql","04_orders.sql",
    "05_payments.sql","06_qr_codes.sql","07_memorials.sql","08_media.sql",
    "09_reviews.sql","10_system.sql","11_functions_triggers.sql","12_seed.sql","13_grants.sql"
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
