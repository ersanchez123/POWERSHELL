<#
	.NOTES
	===========================================================================
	 Created with: 	Powershell
	 Created on:   	Junio 2025
	 Created by:   	Paul Chen
	 Organization: 	Autoridad del Canal de Panama
	 Filename:      pwsh-mira-encendido-dev-identity.ps1
 	===========================================================================
	.DESCRIPTION
        Script para encender en una secuencia especifica las VMS del ambiente Dev de MIRA
        Necesita los modulos: AZ
    .REFERENCES

    .CHANGES
        11/21/2023 - Script inicial
        6/10/2025 - Cambio de autenticacion a identidad gestionada
#>

#region funciones
function EnviarEmailDotNet {
    [CmdletBinding()]
    param(
        [string[]]$To, 
        [string]$Subject,
        [string]$Body
    )

    $SmtpServer = "smtp.canal.acp"
    $Msg = New-Object Net.Mail.MailMessage
    $Smtp = New-Object Net.Mail.SmtpClient($SmtpServer)
    $Msg.From = "powershell@pancanal.com"
    $To | ForEach-Object { $Msg.To.Add($_) }
    $Msg.Subject = $Subject
    $Msg.Body = $Body
    $Msg.IsBodyHtml = $true
    $Smtp.Send($Msg)
}
#endregion 

#region modulos
Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.Compute -ErrorAction Stop
#endregion

#region autenticacion
# Iniciando sesión en Azure con identidad gestionada    
Write-Host "Iniciando sesión en Azure..." -ForegroundColor Yellow
$clientId = "01d5362a-491e-42d0-a21c-9934e7545ac1"
Connect-AzAccount -Identity -AccountId $clientId -ErrorAction Stop
#endregion

#region variables
$resourceGroup = "mira-eus2-rg-dev-01"

# Definir la Secuencia
$vmOrder = @{
    "mira-eus2-dpt1" = 1
    "mira-eus2-dgi1" = 2
    "mira-eus2-drd1" = 3
    "mira-eus2-dbd1" = 4
    "mira-eus2-dbd2" = 5
    "mira-eus2-dbd3" = 6
    "mira-eus2-dge1" = 7
    "mira-eus2-drt1" = 8
}

# Ordenar por secuencia definida
$sortedVMs = $vmOrder.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key }
#endregion

#region encendido secuencial
$encendidas = @()
foreach ($vmName in $sortedVMs) {
    $vm = Get-AzVM -Name $vmName -ResourceGroupName $resourceGroup -Status
    $VMPowerstate = $vm.PowerState
    Write-Output "$vmName - Estado: $VMPowerstate"

    if ($VMPowerstate -like "*running*") {
        Write-Output "$vmName ya está encendida. Reiniciando..."
        Restart-AzVM -ResourceGroupName $resourceGroup -Name $vmName -NoWait
    }
    else {
        Write-Output "$vmName está apagada. Encendiendo..."
        Start-AzVM -ResourceGroupName $resourceGroup -Name $vmName -NoWait
    }

    Start-Sleep -Seconds 300
    
    # Verificar conectividad (simplemente se registra en el array, no hay ping desde Runbook)
    $encendidas += [PSCustomObject]@{
        ComputerName = $vmName
        Estado = "Encendido/Reiniciado"
        Timestamp = (Get-Date).ToString("s")
    }
}
#endregion

#region salidas
$htmlTable = $encendidas | ConvertTo-Html -Fragment
$emailBody = @"
<html>
<head>
<style>
    table {
        border-collapse: collapse;
        width: 60%;
    }
    th, td {
        border: 1px solid black;
        padding: 8px;
        text-align: left;
    }
</style>
</head>
<body>
    <h2>Servidores MIRA - Ambiente Dev</h2>
    $htmlTable
</body>
</html>
"@

$recipient = "syscloud@pancanal.com","eapaulk@pancanal.com"
$subject = "Proyecto MIRA - Encendido Ambiente DEV"
EnviarEmailDotNet -To $recipient -Subject $subject -Body $emailBody
Write-Output "Reporte enviado."
#endregion

Exit