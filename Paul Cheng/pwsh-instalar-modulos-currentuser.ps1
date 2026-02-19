<#
.SYNOPSIS
Instala o actualiza módulos de PowerShell en una carpeta personalizada fuera de OneDrive.
Esto es útil para evitar problemas de sincronización con OneDrive.
Este script es para instalar módulos para el usuario actual sin privilegios elevados, en la estación no en los servidores.

.DESCRIPTION
Evita que los módulos se sincronicen con OneDrive usando una ruta personalizada (como C:\MyRepo\PowerShell\Modulos).
Verifica si el módulo ya existe antes de descargarlo. Guarda registro de los resultados.

.USO
1. Ejecuta este script con PowerShell (puede ser sin privilegios elevados).
2. La carpeta se creará si no existe.
3. Se revisará cada módulo y se instalará solo si no está.
4. Se guardará un log de las acciones.

.NOTES
Autor: Paul Chen Charter
Fecha: Noviembre 2025
Version: 1.0
#>

# RUTA PERSONALIZADA para evitar OneDrive
$repoLocal = "C:\MyRepo\PowerShell\Modulos"
$modulos = @(
    "AZ",
    "Microsoft.Graph",
    "ExchangeOnlineManagement"
)

# Asegura que la ruta exista
if (-not (Test-Path $repoLocal)) {
    New-Item -ItemType Directory -Path $repoLocal -Force | Out-Null
    Write-Host "Carpeta creada: $repoLocal" -ForegroundColor Yellow
}

# Agrega la ruta al PSModulePath para esta sesión
if ($env:PSModulePath -notlike "*$repoLocal*") {
    $env:PSModulePath = "$repoLocal;$env:PSModulePath"
    Write-Host "Ruta agregada al PSModulePath para esta sesión: $repoLocal" -ForegroundColor DarkGray
}

# [Opcional] Agrega la ruta al PSModulePath de forma permanente (una sola vez)
$persistente = $true
if ($persistente) {
    $regPath = "HKCU:\Environment"
    $valorActual = (Get-ItemProperty -Path $regPath -Name PSModulePath -ErrorAction SilentlyContinue).PSModulePath
    if ($valorActual -notlike "*$repoLocal*") {
        Set-ItemProperty -Path $regPath -Name PSModulePath -Value "$repoLocal;$valorActual"
        Write-Host "Ruta agregada al PSModulePath permanente del usuario (requiere reiniciar PowerShell)." -ForegroundColor DarkGreen
    }
}

# Prepara registro de acciones
$log = @()
$fecha = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

foreach ($modulo in $modulos) {
    try {
        # Verifica si el módulo ya está en la carpeta personalizada
        $instalado = Get-Module -ListAvailable -Name $modulo |
            Where-Object { $_.ModuleBase -like "$repoLocal*" }

        if ($instalado) {
            Write-Host "'$modulo' ya está instalado en $repoLocal." -ForegroundColor Green
            $log += [PSCustomObject]@{
                Modulo = $modulo
                Estado = "Ya instalado"
                Fecha  = $fecha
            }
        } else {
            Write-Host "Descargando '$modulo' en $repoLocal..." -ForegroundColor Cyan
            Save-Module -Name $modulo -Path $repoLocal -Force -ErrorAction Stop
            Write-Host "'$modulo' instalado correctamente." -ForegroundColor Green

            # (Opcional) Importar el módulo para usarlo inmediatamente
            Import-Module -Name $modulo -Force -ErrorAction SilentlyContinue

            $log += [PSCustomObject]@{
                Modulo = $modulo
                Estado = "Instalado"
                Fecha  = $fecha
            }
        }
    } catch {
        Write-Warning "Error al instalar '$modulo': $($_.Exception.Message)"
        $log += [PSCustomObject]@{
            Modulo = $modulo
            Estado = "Error: $($_.Exception.Message)"
            Fecha  = $fecha
        }
    }
}

# Exportar log
$logPath = Join-Path $PSScriptRoot "modulos-locales-log.csv"
$log | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8

Write-Host "`n Registro guardado en: $logPath" -ForegroundColor DarkYellow
Write-Host "Todo listo. Puedes comenzar a usar tus módulos desde $repoLocal" -ForegroundColor Cyan



