<#
	.NOTES
	===========================================================================
	 Created with: 	Powershell
	 Created on:   	Julio 2025
	 Created by:   	Paul Chen
	 Organization: 	Autoridad del Canal de Panama
	 Filename:      pwsh-mira-encendido-dev-identity-v2.ps1
 	===========================================================================
	.DESCRIPTION
        Script para encender en una secuencia especifica las VMS del ambiente Dev de MIRA
        Necesita los modulos: AZ
    .REFERENCES

    .CHANGES
        11/21/2023 - Script inicial
        6/10/2025 - Cambio de autenticacion a identidad gestionada
        7/28/2025 - Cambio de secuencia por instrucciones de CContreras/ESRI
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

function Start-VMGroup {
    param (
        [string[]]$vmNames,
        [string]$rgName
    )
    foreach ($vm in $vmNames) {
        Write-Output "Encendiendo $vm..."
        Start-AzVM -Name $vm -ResourceGroupName $rgName -NoWait #-WhatIf
    }

    # Esperamos a que estén encendidas
    foreach ($vm in $vmNames) {
        while ($true) {
            $status = (Get-AzVM -ResourceGroupName $rgName -Name $vm -Status).Statuses |
            Where-Object { $_.Code -like "PowerState*" } |
            Select-Object -ExpandProperty DisplayStatus
            Write-Output "$vm estado: $status"
            if ($status -eq "VM running") {
                break
            }
            Start-Sleep -Seconds 15
        }
    }
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
$encendidas = @()
$rgName = "mira-eus2-rg-dev-01"
# Grupo 1
$grupo1 = @("mira-eus2-dpt1", "mira-eus2-dgi1", "mira-eus2-drd1")
# Grupo 2
$grupo2 = @("mira-eus2-dbd1", "mira-eus2-dbd2", "mira-eus2-dbd3")
# Grupo 3
$grupo3 = @("mira-eus2-dge1")
#endregion

#region Proceso
# Iniciar Grupo 1
Write-Output "Iniciando grupo 1..."
Start-VMGroup -vmNames $grupo1 -rgName $rgName

# Esperar 1 minuto
Write-Output "Esperando 1 minuto..."
Start-Sleep -Seconds 60

# Iniciar Grupo 2
Write-Output "Iniciando grupo 2..."
Start-VMGroup -vmNames $grupo2 -rgName $rgName

# Esperar 15 minutos
Write-Output "Esperando 15 minutos..."
Start-Sleep -Seconds 900

# Iniciar Grupo 3
Write-Output "Iniciando grupo 3..."
Start-VMGroup -vmNames $grupo3 -rgName $rgName

Write-Output "Secuencia completada."

foreach ($vmName in $grupo1 + $grupo2 + $grupo3) {
    $ping = Test-Connection -ComputerName $vmName -Count 2 -Quiet -ErrorAction SilentlyContinue
    $estado = if ($ping) { "En línea" } else { "Sin respuesta" }
    $encendidas += [PSCustomObject]@{
        ComputerName = $vmName
        Estado       = $estado
        Timestamp    = (Get-Date).ToString("s")
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
#$recipient = "paulchen@pancanal.com"
$subject = "Proyecto MIRA - Encendido Ambiente DEV"
EnviarEmailDotNet -To $recipient -Subject $subject -Body $emailBody
Write-Output "Reporte enviado."
#endregion
Exit