<#
.NOTES
============================================================================
 Created with:    Powershell
 Created on:      Noviembre 2025
 Created by:      Paul Chen
 Organization:    Autoridad del Canal de Panama
 Filename:        c:\MyRepo\mypowershell\m365\pwsh-m365-delegar-buzones.ps1
============================================================================
.SYNOPSIS
    Asigna y elimina permisos FullAccess y SendAs en un buzón de Exchange Online,
    con validaciones y reportes previos/post ejecución.

.DESCRIPTION
    Este script:
    - Valida formatos de direcciones de correo con la función Test-EmailFormat.
    - Verifica existencia del buzón objetivo y de los usuarios delegados en Exchange Online.
    - Obtiene y reporta permisos actuales (FullAccess y SendAs) usando reporte_delegados.
    - Agrega permisos FullAccess y SendAs a usuarios especificados (uso de -WhatIf en operaciones de agregado).
    - Elimina permisos FullAccess y SendAs de usuarios listados para eliminación.
    - Reconsolida y muestra el estado final de delegaciones.
    - Conecta y desconecta de Exchange Online (Connect-ExchangeOnline / Disconnect-ExchangeOnline).

    Notas importantes:
    - Requiere los módulos de Exchange Online (ExchangeOnlineManagement).
    - El script usa validaciones adicionales para evitar entradas no deseadas (NT AUTHORITY, SIDs, Everyone, Anonymous, SELF).
    - Para seguridad, las operaciones de agregación utilizan -WhatIf por defecto. Revisar y quitar -WhatIf para ejecutar cambios reales.
    - El script intenta manejar errores y salir con códigos adecuados en caso de fallas críticas.

.PARAMETER cuenta_admin
    Cuenta de administrador usada para Connect-ExchangeOnline.

.PARAMETER buzon_para_delegar
    Buzón destino al que se agregan/eliminan permisos.

.PARAMETER delegados_agregar
    Lista de usuarios a los que se les asignarán permisos.

.PARAMETER delegados_eliminar
    Lista de usuarios a los que se les removerán permisos.

.FUNCTIONS
    Test-EmailFormat    - Valida el formato de una dirección de correo.
    reporte_delegados   - Construye un reporte consolidado (FullAccess y SendAs) para un buzón.

.CHANGES
    20240315 - V1.0 - Versión inicial.
    2025???? - Actualización de documentación para reflejar cambios:
        - Se agregó validación de formato de correo (Test-EmailFormat) y validación previa de todas las cuentas involucradas.
        - Consolidación de listas únicas de cuentas a validar y de delegados.
        - Nueva función reporte_delegados para generar reportes tabulares antes y después de cambios.
        - Uso de Get-Recipient para verificar existencia de buzones/usuarios antes de operar.
        - Uso de -WhatIf en Add-MailboxPermission y Add-RecipientPermission para operaciones de agregado por seguridad.
        - Mejor manejo de eliminaciones: relectura de permisos actuales y eliminación por entradas coincidentes.
        - Salidas más claras en consola (mensajes informativos, advertencias y errores) y códigos de salida en errores críticos.

.EXAMPLE
    Ejecutar el script tal cual (modo seguro con -WhatIf en agregados):
        .\pwsh-m365-delegar-buzones.ps1

    Para aplicar cambios reales, revisar y remover las opciones -WhatIf en las llamadas a Add-* o Remove-*.

#>

#region Funciones
function Test-EmailFormat {
    param([string]$Email)
    if (-not $Email) { return $false }
    return $Email -match '^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$'
}

function reporte_delegados {
    param(
        [Parameter(Mandatory = $true)][string]$Buzon,
        [Parameter(Mandatory = $true)][array]$FullAccessEntries,
        [Parameter(Mandatory = $true)][array]$SendAsEntries,
        [Parameter(Mandatory = $true)][array]$Delegates
    )

    $report = foreach ($d in $Delegates) {
        $normalized = $d.ToString().ToLower()
        $faEntry = $FullAccessEntries | Where-Object { $_.User.ToString().ToLower() -eq $normalized }
        $saEntry = $SendAsEntries    | Where-Object { $_.Trustee.ToString().ToLower() -eq $normalized }

        [PSCustomObject]@{
            Delegate   = $d
            FullAccess = if ($faEntry) { ($faEntry.AccessRights -join ',') } else { $false }
            SendAs     = if ($saEntry) { ($saEntry.AccessRights -join ',') } else { $false }
        }
    }

    if ($report -and $report.Count -gt 0) {
        return $report | Sort-Object Delegate
    }
    else {
        Write-Host "No se encontraron delegados con permisos FullAccess o SendAs en $Buzon." -ForegroundColor Yellow
        return @()
    }
}
#endregion

Clear-Host

#region Parámetros y Variables
$dominio = "pancanal.com"
$cuenta_admin = "paulichen@$dominio"
$buzon_para_delegar = "Gestion_De_Cobros@$dominio"
$delegados_agregar = @("aracastrellon@$dominio")
$delegados_eliminar = @()
$delegados = $delegados_agregar + $delegados_eliminar

Write-Host "Validando formato de correo electrónico para todas las cuentas involucradas..." -ForegroundColor Green
# Crear lista única de direcciones a validar
$allAccounts = @($cuenta_admin, $buzon_para_delegar) + $delegados | Select-Object -Unique

foreach ($acct in $allAccounts) {
    if (-not (Test-EmailFormat -Email $acct)) {
        Write-Host "La dirección '$acct' no tiene un formato de correo electrónico válido. Terminando script..." -ForegroundColor Red
        Exit 1
    }
    else {
        Write-Host "Válido: $acct" -ForegroundColor Green
    }
}
#endregion

#region Conexión a Exchange Online
Write-Host "Conectando a Exchange Online..." -ForegroundColor Green
# Conectar a Exchange Online
Connect-ExchangeOnline -UserPrincipalName $cuenta_admin -ErrorAction Stop
if ($?) {
    Write-Host "Conexión exitosa a Exchange Online." -ForegroundColor Green
}
else {
    Write-Host "Error al conectar a Exchange Online, terminando script..." -ForegroundColor Red
    Exit
}
#endregion

#region Proceso
# Validar existencia en Exchange Online del buzón destino y de todos los delegados
Write-Host "Validando existencia en Exchange Online de buzón y delegados..." -ForegroundColor Green
$accountsToCheck = @($buzon_para_delegar) + $delegados | Select-Object -Unique
$missingAccounts = @()
foreach ($acct in $accountsToCheck) {
    $recip = Get-Recipient -Identity $acct -ErrorAction SilentlyContinue
    if ($recip) {
        Write-Host "Existe: $acct" -ForegroundColor Green
    }
    else {
        Write-Host "No encontrado en Exchange Online: $acct" -ForegroundColor Yellow
        $missingAccounts += $acct
    }
}

if ($missingAccounts.Count -gt 0) {
    Write-Host "Se encontraron cuentas faltantes. No se puede continuar." -ForegroundColor Red
    $missingAccounts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Exit 1
}

#Repasar delegados actuales
Write-Host "Lista de delegados actuales:" 
# Listar delegados actuales y sus permisos (FullAccess y SendAs)
try {
    $fullAccess = Get-MailboxPermission -Identity $buzon_para_delegar -ErrorAction Stop |
    Where-Object { $_.User -and ($_.User.ToString() -notmatch 'NT AUTHORITY|S-1-5|Everyone|Anonymous|SELF') }

}
catch {
    Write-Warning "No se pudo obtener permisos de buzón: $_"
    $fullAccess = @()
}

try {
    $sendAs = Get-RecipientPermission -Identity $buzon_para_delegar -ErrorAction Stop |
    Where-Object { $_.AccessRights -contains 'SendAs' -and ($_.Trustee -notmatch 'NT AUTHORITY|S-1-5|Everyone|Anonymous|SELF') }
}
catch {
    Write-Warning "No se pudo obtener permisos SendAs: $_"
    $sendAs = @()
}

# Consolidar lista única de delegados
$delegates = @()
$delegates += ($fullAccess | ForEach-Object { $_.User.ToString() })
$delegates += ($sendAs | ForEach-Object { $_.Trustee.ToString() })
$delegates = $delegates | Select-Object -Unique


# Reporte de todos los delegados y sus permisos antes de ejecutar las asiganciones
Write-Host "Reporte de delegados y sus permisos actuales en $buzon_para_delegar" -ForegroundColor Green
$report = reporte_delegados -Buzon $buzon_para_delegar -FullAccessEntries $fullAccess -SendAsEntries $sendAs -Delegates $delegates
if ($report.Count -gt 0) {
    $report | Format-Table -AutoSize
}
  
# Efectuar las delegaciones de permsisos FullAccess y SendAs
Write-Host "Delegando permisos FullAccess a los usuarios especificados..." -ForegroundColor Green   
foreach ($delegado in $delegados_agregar) {
    Write-Host "Agregando FullAccess para $delegado en $buzon_para_delegar..." -ForegroundColor Cyan
    try {
        Add-MailboxPermission -Identity $buzon_para_delegar -User $delegado -AccessRights FullAccess -InheritanceType All -ErrorAction Stop #-WhatIf
        Write-Host "Permiso FullAccess agregado exitosamente para $delegado." -ForegroundColor Green
    }
    catch {
        Write-Host "Error al agregar permiso FullAccess para $delegado $_" -ForegroundColor Red
    }
}
# Efectuar las delegaciones SendAs
Write-Host "Delegando permisos SendAs a los usuarios especificados..." -ForegroundColor Green
foreach ($delegado in $delegados_agregar) {
    Write-Host "Agregando SendAs para $delegado en $buzon_para_delegar..." -ForegroundColor Cyan
    try {
        $exists = $sendAs | Where-Object { $_.Trustee.ToString().ToLower() -eq $delegado.ToLower() }
        if ($exists) {
            Write-Host "SendAs ya existe para $delegado. Omitiendo." -ForegroundColor Yellow
            continue
        }
        Add-RecipientPermission -Identity $buzon_para_delegar -Trustee $delegado -AccessRights SendAs -Confirm:$false -ErrorAction Stop
        Write-Host "Permiso SendAs agregado exitosamente para $delegado." -ForegroundColor Green
    }
    catch {
        Write-Host "Error al agregar permiso SendAs para $delegado $_" -ForegroundColor Red
    }
}

# Eliminar delegados listados en $delegados_eliminar de todos los permisos del buzón
if ($delegados_eliminar -and $delegados_eliminar.Count -gt 0) {
    Write-Host "Eliminando cuentas en \$delegados_eliminar de todos los permisos del buzón..." -ForegroundColor Green

    # Obtener permisos actuales nuevamente
    try {
        $currentFullAccess = Get-MailboxPermission -Identity $buzon_para_delegar -ErrorAction Stop |
        Where-Object { $_.User -and ($_.User.ToString() -notmatch 'NT AUTHORITY|S-1-5|Everyone|Anonymous|SELF') }
    }
    catch {
        Write-Warning "No se pudo obtener permisos FullAccess actuales $_"
        $currentFullAccess = @()
    }

    try {
        $currentSendAs = Get-RecipientPermission -Identity $buzon_para_delegar -ErrorAction Stop |
        Where-Object { $_.AccessRights -contains 'SendAs' -and ($_.Trustee -notmatch 'NT AUTHORITY|S-1-5|Everyone|Anonymous|SELF') }
    }
    catch {
        Write-Warning "No se pudo obtener permisos SendAs actuales $_"
        $currentSendAs = @()
    }

    foreach ($del in $delegados_eliminar) {
        Write-Host "Procesando eliminación para: $del" -ForegroundColor Cyan
        $normalized = $del.ToLower()

        # Eliminar FullAccess (puede haber varias entradas)
        $faEntries = $currentFullAccess | Where-Object { $_.User.ToString().ToLower() -eq $normalized }
        if ($faEntries) {
            foreach ($entry in $faEntries) {
                try {
                    Remove-MailboxPermission -Identity $buzon_para_delegar -User $entry.User -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop #-WhatIf
                    Write-Host "FullAccess eliminado para $del" -ForegroundColor Green
                }
                catch {
                    Write-Host "Error al eliminar FullAccess para $del $_" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "No existe FullAccess para $del" -ForegroundColor Yellow
        }

        # Eliminar SendAs (puede haber varias entradas)
        $saEntries = $currentSendAs | Where-Object { $_.Trustee.ToString().ToLower() -eq $normalized }
        if ($saEntries) {
            foreach ($entry in $saEntries) {
                try {
                    Remove-RecipientPermission -Identity $buzon_para_delegar -Trustee $entry.Trustee -AccessRights SendAs -Confirm:$false -ErrorAction Stop
                    Write-Host "SendAs eliminado para $del" -ForegroundColor Green
                }
                catch {
                    Write-Host "Error al eliminar SendAs para $del $_" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "No existe SendAs para $del" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "No hay delegados a eliminar." -ForegroundColor Yellow
}

# Verificar y mostrar los permisos delegados actuales
Write-Host "Verificando permisos delegados actuales en $buzon_para_delegar..." -ForegroundColor Green

try {
    $currentFullAccess = Get-MailboxPermission -Identity $buzon_para_delegar -ErrorAction Stop |
        Where-Object { $_.User -and ($_.User.ToString() -notmatch 'NT AUTHORITY|S-1-5|Everyone|Anonymous|SELF') }
}
catch {
    Write-Warning "No se pudo obtener permisos FullAccess actuales: $_"
    $currentFullAccess = @()
}

try {
    $currentSendAs = Get-RecipientPermission -Identity $buzon_para_delegar -ErrorAction Stop |
        Where-Object { $_.AccessRights -contains 'SendAs' -and ($_.Trustee -notmatch 'NT AUTHORITY|S-1-5|Everyone|Anonymous|SELF') }
}
catch {
    Write-Warning "No se pudo obtener permisos SendAs actuales: $_"
    $currentSendAs = @()
}

# Reconstruir lista única de delegados basada en los permisos actuales
$currentDelegates = @()
$currentDelegates += ($currentFullAccess | ForEach-Object { $_.User.ToString() })
$currentDelegates += ($currentSendAs   | ForEach-Object { $_.Trustee.ToString() })
$currentDelegates = $currentDelegates | Where-Object { $_ } | Select-Object -Unique

if (-not $currentDelegates -or $currentDelegates.Count -eq 0) {
    Write-Host "No hay delegados con permisos FullAccess o SendAs en $buzon_para_delegar." -ForegroundColor Yellow
}
else {
    $report = reporte_delegados -Buzon $buzon_para_delegar -FullAccessEntries $currentFullAccess -SendAsEntries $currentSendAs -Delegates $currentDelegates
    if ($report -and $report.Count -gt 0) {
        $report | Format-Table -AutoSize
    }
    else {
        Write-Host "No se generó reporte de delegados." -ForegroundColor Yellow
    }
}
#endregion

#region Desconexión
# Desconectar de Exchange Online
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "Finito..." -ForegroundColor Yellow
#endregion