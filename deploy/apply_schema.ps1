# Опционально: применить схему на сервере через psql (без DBeaver)
#   .\deploy\apply_schema.ps1

param(
    [string]$DbHost = "localhost",
    [int]$Port = 5432,
    [string]$Database = "qr_pamyat",
    [string]$User = "postgres"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$schemaFile = Join-Path $root "db\scripts\00_full_schema.sql"

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Error "psql не найден. На dev используйте DBeaver (db/dbeaver/GUIDE.md)."
}
if (-not (Test-Path $schemaFile)) {
    Write-Error "Не найден: $schemaFile"
}

$env:PGPASSWORD = Read-Host "Пароль PostgreSQL для $User"
Write-Host "Применяю схему к $Database на ${DbHost}:${Port}..."
& psql -h $DbHost -p $Port -U $User -d $Database -f $schemaFile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Готово."
