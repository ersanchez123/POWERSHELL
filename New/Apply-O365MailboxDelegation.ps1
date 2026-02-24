
<#!
.SYNOPSIS
    Lee un archivo JSON con parámetros de delegación y aplica permisos en Exchange Online.

.DESCRIPTION
    Estructura JSON esperada (campos por registro):
    {
      "cuenta_admin": "admin@contoso.com",
      "Buzon_para_delegar": "shared@contoso.com",
      "Delegados_agregar": "user1@contoso.com;user2@contoso.com",   # separados por coma o punto y coma
      "Delegados_eliminar": "user3@contoso.com"
    }

    El script aplica permisos de FullAccess y SendAs al agregar, y los revoca al eliminar.
    Es idempotente: valida el estado antes de agregar/quitar.

.PARAMETER JsonPath
    Ruta del archivo JSON. Puede contener un único objeto o un arreglo de objetos.

.PARAMETER GrantSendOnBehalf
    Si se especifica, también gestiona SendOnBehalf (Add/Remove-RecipientPermission no aplica; se usa Set-Mailbox Delegates).

.PARAMETER WhatIf
    Simula sin realizar cambios.

.EXAMPLE
    .\Apply-O365MailboxDelegation.ps1 -JsonPath .\StructIvanti.json -Verbose

#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$JsonPath,

    [switch]$GrantSendOnBehalf
)

function Connect-ExchangeIfNeeded {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Verbose "Instalando módulo ExchangeOnlineManagement para el usuario actual..."
        try { Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -ErrorAction Stop }
        catch { throw "No se pudo instalar ExchangeOnlineManagement: $($_.Exception.Message)" }
    }
    if (-not (Get-Module ExchangeOnlineManagement)) { Import-Module ExchangeOnlineManagement }
    if (-not (Get-ExoMailbox -ResultSize 1 -ErrorAction SilentlyContinue)) {
        Write-Verbose "Conectando a Exchange Online..."
        try { Connect-ExchangeOnline -ShowProgress:$false -ErrorAction Stop }
        catch { throw "No se pudo conectar a Exchange Online: $($_.Exception.Message)" }
    }
}

function Normalize-List([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return @() }
    return ($s -split '[,;\n]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Ensure-FullAccess {
    param(
        [string]$Mailbox,
        [string]$User,
        [switch]$Remove
    )
    $existing = Get-MailboxPermission -Identity $Mailbox -User $User -ErrorAction SilentlyContinue |
                Where-Object { $_.AccessRights -contains 'FullAccess' -and -not $_.IsInherited }

    if ($Remove) {
        if ($existing) {
            if ($PSCmdlet.ShouldProcess("$User", "Remove FullAccess on $Mailbox")) {
                Remove-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -Confirm:$false -ErrorAction Stop
            }
        } else {
            Write-Verbose "FullAccess ya ausente: $Mailbox <- $User"
        }
    } else {
        if (-not $existing) {
            if ($PSCmdlet.ShouldProcess("$User", "Add FullAccess on $Mailbox")) {
                Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -AutoMapping:$true -InheritanceType All -ErrorAction Stop
            }
        } else {
            Write-Verbose "FullAccess ya presente: $Mailbox <- $User"
        }
    }
}

function Ensure-SendAs {
    param(
        [string]$Mailbox,
        [string]$User,
        [switch]$Remove
    )
    $existing = Get-RecipientPermission -Identity $Mailbox -Trustee $User -ErrorAction SilentlyContinue |
                Where-Object { $_.AccessRights -contains 'SendAs' }
    if ($Remove) {
        if ($existing) {
            if ($PSCmdlet.ShouldProcess("$User", "Remove SendAs on $Mailbox")) {
                Remove-RecipientPermission -Identity $Mailbox -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            }
        } else {
            Write-Verbose "SendAs ya ausente: $Mailbox <- $User"
        }
    } else {
        if (-not $existing) {
            if ($PSCmdlet.ShouldProcess("$User", "Add SendAs on $Mailbox")) {
                Add-RecipientPermission -Identity $Mailbox -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            }
        } else {
            Write-Verbose "SendAs ya presente: $Mailbox <- $User"
        }
    }
}

function Ensure-SendOnBehalf {
    param(
        [string]$Mailbox,
        [string]$User,
        [switch]$Remove
    )
    # SendOnBehalf se maneja en el objeto del buzón (GrantSendOnBehalfTo)
    $mbx = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
    $current = @($mbx.GrantSendOnBehalfTo | ForEach-Object { $_.PrimarySmtpAddress.ToString().ToLower() })
    $userLower = $User.ToLower()

    if ($Remove) {
        if ($current -contains $userLower) {
            $newList = $current | Where-Object { $_ -ne $userLower }
            if ($PSCmdlet.ShouldProcess("$User", "Remove SendOnBehalf on $Mailbox")) {
                Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo $newList -ErrorAction Stop
            }
        } else {
            Write-Verbose "SendOnBehalf ya ausente: $Mailbox <- $User"
        }
    } else {
        if ($current -notcontains $userLower) {
            $newList = @($current + $userLower)
            if ($PSCmdlet.ShouldProcess("$User", "Add SendOnBehalf on $Mailbox")) {
                Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo $newList -ErrorAction Stop
            }
        } else {
            Write-Verbose "SendOnBehalf ya presente: $Mailbox <- $User"
        }
    }
}

function Process-Record {
    param($rec)

    $admin    = $rec.cuenta_admin
    $mailbox  = $rec.Buzon_para_delegar
    $toAdd    = Normalize-List $rec.Delegados_agregar
    $toRemove = Normalize-List $rec.Delegados_eliminar

    if (-not $mailbox) { throw "Falta 'Buzon_para_delegar' en el JSON." }

    Write-Verbose "Procesando buzón: $mailbox"

    foreach ($u in $toAdd) {
        try {
            Ensure-FullAccess -Mailbox $mailbox -User $u
            Ensure-SendAs    -Mailbox $mailbox -User $u
            if ($GrantSendOnBehalf) { Ensure-SendOnBehalf -Mailbox $mailbox -User $u }
            [pscustomobject]@{ Mailbox=$mailbox; User=$u; Action='Add'; FullAccess='OK'; SendAs='OK'; SendOnBehalf=[bool]$GrantSendOnBehalf }
        } catch {
            Write-Warning "Error agregando permisos a $u sobre $mailbox: $($_.Exception.Message)"
            [pscustomobject]@{ Mailbox=$mailbox; User=$u; Action='Add'; Error=$_.Exception.Message }
        }
    }

    foreach ($u in $toRemove) {
        try {
            Ensure-FullAccess -Mailbox $mailbox -User $u -Remove
            Ensure-SendAs    -Mailbox $mailbox -User $u -Remove
            if ($GrantSendOnBehalf) { Ensure-SendOnBehalf -Mailbox $mailbox -User $u -Remove }
            [pscustomobject]@{ Mailbox=$mailbox; User=$u; Action='Remove'; FullAccess='OK'; SendAs='OK'; SendOnBehalf=[bool]$GrantSendOnBehalf }
        } catch {
            Write-Warning "Error removiendo permisos a $u sobre $mailbox: $($_.Exception.Message)"
            [pscustomobject]@{ Mailbox=$mailbox; User=$u; Action='Remove'; Error=$_.Exception.Message }
        }
    }
}

# --- MAIN ---
if (-not (Test-Path -LiteralPath $JsonPath)) { throw "No existe el archivo: $JsonPath" }

Connect-ExchangeIfNeeded

# Admite objeto único o arreglo
$content = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
if ($content -is [System.Collections.IEnumerable] -and -not ($content -is [hashtable])) {
    $records = $content
} else {
    $records = @($content)
}

$results = foreach ($rec in $records) { Process-Record -rec $rec }

# Exporta reporte JSON y CSV
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$base = [System.IO.Path]::ChangeExtension($JsonPath, $null)
$csv = "$base.results_$ts.csv"
$json= "$base.results_$ts.json"
$results | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
$results | ConvertTo-Json -Depth 5 | Out-File -FilePath $json -Encoding UTF8

Write-Host "Listo. Reportes:" -ForegroundColor Green
Write-Host "  CSV : $csv"
Write-Host "  JSON: $json"
