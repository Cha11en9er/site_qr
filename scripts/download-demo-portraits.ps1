# Скачивает портреты для демо-примеров в uploads/demos/
# Запуск: .\scripts\download-demo-portraits.ps1

$dest = Join-Path $PSScriptRoot "..\uploads\demos"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$files = @{
    "pushkin.jpg"    = "https://upload.wikimedia.org/wikipedia/commons/5/56/Kiprensky_Pushkin.jpg"
    "mironov.jpg"    = "https://upload.wikimedia.org/wikipedia/commons/8/8a/Andrei_Mironov_1986.jpg"
    "shulzhenko.jpg" = "https://upload.wikimedia.org/wikipedia/commons/9/9d/Klavdiya_Shulzhenko_1950.jpg"
}

foreach ($name in $files.Keys) {
    $out = Join-Path $dest $name
    if (Test-Path $out) {
        Write-Host "skip $name (already exists)"
        continue
    }
    Write-Host "download $name ..."
    Start-Sleep -Seconds 6
    try {
        Invoke-WebRequest -Uri $files[$name] -OutFile $out -UserAgent "QR-Pamyat-Setup/1.0"
        Write-Host "ok $name"
    } catch {
        Write-Warning "failed $name : $_"
        Write-Host "Save manually to: $out"
    }
}

Write-Host "`nFolder: $(Resolve-Path $dest)"
