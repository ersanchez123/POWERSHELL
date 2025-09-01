<#
.SYNOPSIS
    Copia todo el contenido de un disco origen a un disco destino, similar a robocopy /MIR.
    Ejemplo: Copiar E:\ de vm1 a E:\ de vm2.
    Asume que la sesión ya tiene las credenciales necesarias para acceder a ambos discos.
    Copia todo el contenido de un disco origen a un disco destino de manera recursiva y precisa.

.DESCRIPTION
    Este script copia todos los archivos y carpetas desde un disco origen a un disco destino, replicando la estructura y el contenido, similar al comportamiento de 'robocopy /MIR'.
    Es útil para migraciones o respaldos completos de discos entre máquinas o ubicaciones.
    Se asume que la sesión de PowerShell ya cuenta con los permisos y credenciales necesarios para acceder tanto al disco origen como al destino.

.PARAMETER Origen
    Ruta del disco o carpeta de origen desde donde se copiarán los archivos (por ejemplo, E:\).

.PARAMETER Destino
    Ruta del disco o carpeta de destino donde se copiarán los archivos (por ejemplo, E:\ en otra máquina).

.EXAMPLE
    .\pwsh-dev-copiar-disco2disco.ps1 -Origen "E:\" -Destino "\\vm2\E$"
    Copia todo el contenido de E:\ en la máquina local al disco E:\ de la máquina vm2.

.NOTES
    Autor: Paul Chen Charter
    Fecha de creación: Diciembre 2023
    Requiere permisos de lectura en el origen y de escritura en el destino.
    Asegúrate de que no haya archivos abiertos o bloqueados durante la copia para evitar errores.
#>

param(
    [Parameter(Mandatory)]
    [string]$Origen,   # Ejemplo: "\\vm1\E$\"
    [Parameter(Mandatory)]
    [string]$Destino   # Ejemplo: "\\vm2\E$\"
)

function Sync-Directories {
    param (
        [string]$Source,
        [string]$Target
    )

    # Verificar que el origen existe
    if (-not (Test-Path $Source)) {
        throw "El directorio de origen '$Source' no existe."
    }

    # Crear el destino si no existe
    if (-not (Test-Path $Target)) {
        New-Item -Path $Target -ItemType Directory -Force | Out-Null
    }

    # Copiar archivos y carpetas nuevas o actualizadas
    Get-ChildItem -Path $Source -Recurse -Force | ForEach-Object {
        $relativePath = $_.FullName.Substring($Source.Length)
        $destPath = Join-Path $Target $relativePath

        if ($_.PSIsContainer) {
            if (-not (Test-Path $destPath)) {
                New-Item -Path $destPath -ItemType Directory -Force | Out-Null
            }
        } else {
            if ((-not (Test-Path $destPath)) -or ($_.LastWriteTime -gt (Get-Item $destPath).LastWriteTime)) {
                Copy-Item -Path $_.FullName -Destination $destPath -Force
            }
        }
    }

    # Eliminar archivos y carpetas que ya no existen en el origen (solo en el destino)
    Get-ChildItem -Path $Target -Recurse -Force | Sort-Object -Property FullName -Descending | ForEach-Object {
        $relativePath = $_.FullName.Substring($Target.Length)
        $sourcePath = Join-Path $Source $relativePath

        if (-not (Test-Path $sourcePath)) {
            Remove-Item -Path $_.FullName -Force -Recurse
        }
    }
}

try {
    Write-Host "Iniciando copia de $Origen a $Destino..." -ForegroundColor Cyan
    Sync-Directories -Source $Origen -Target $Destino
    Write-Host "Copia completada exitosamente." -ForegroundColor Green
}
catch {
    Write-Error "Error durante la copia: $_"
}
