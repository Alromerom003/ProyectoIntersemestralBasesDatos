# Script de setup para DVD Rental API (Pagila)
# PostgreSQL 18 detectado en: C:\Program Files\PostgreSQL\18\bin

$ErrorActionPreference = "Stop"
$pgBin = "C:\Program Files\PostgreSQL\18\bin"

# Cambiar al directorio del script
Set-Location $PSScriptRoot

Write-Host "=== Paso 1: Crear base de datos pagila ===" -ForegroundColor Cyan
& "$pgBin\psql.exe" -U postgres -d pagila -t -c "SELECT 1" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  La BD pagila ya existe, se omite la creación" -ForegroundColor Yellow
} else {
    & "$pgBin\createdb.exe" -U postgres pagila 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "  Base de datos creada OK" -ForegroundColor Green }
    else { Write-Host "  Error al crear la BD (verifica usuario/contraseña)" -ForegroundColor Red }
}

Write-Host "`n=== Paso 2: Descargar scripts Pagila ===" -ForegroundColor Cyan
if (-not (Test-Path "pagila-schema.sql")) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-schema.sql" -OutFile "pagila-schema.sql" -UseBasicParsing
    Write-Host "  pagila-schema.sql descargado" -ForegroundColor Green
} else { Write-Host "  pagila-schema.sql ya existe" }
if (-not (Test-Path "pagila-data.sql")) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-data.sql" -OutFile "pagila-data.sql" -UseBasicParsing
    Write-Host "  pagila-data.sql descargado" -ForegroundColor Green
} else { Write-Host "  pagila-data.sql ya existe" }

Write-Host "`n=== Paso 3: Cargar schema y datos ===" -ForegroundColor Cyan
if (-not $env:PGPASSWORD) { Write-Host "  (Si pide contraseña, ejecuta antes: `$env:PGPASSWORD = 'tu_password')" -ForegroundColor Yellow }
& "$pgBin\psql.exe" -U postgres -d pagila -f pagila-schema.sql
& "$pgBin\psql.exe" -U postgres -d pagila -f pagila-data.sql
Write-Host "  Datos cargados OK" -ForegroundColor Green

Write-Host "`n=== Paso 4: Aplicar indices, triggers y particiones ===" -ForegroundColor Cyan
& "$pgBin\psql.exe" -U postgres -d pagila -f sql/indexes.sql
& "$pgBin\psql.exe" -U postgres -d pagila -f sql/triggers.sql
& "$pgBin\psql.exe" -U postgres -d pagila -f sql/partitions.sql
Write-Host "  Indices, triggers y particiones aplicados OK" -ForegroundColor Green

Write-Host "`n=== Setup completado ===" -ForegroundColor Green
Write-Host "Siguiente: Activa el venv, configura DATABASE_URL y ejecuta: uvicorn app.main:app --reload"
