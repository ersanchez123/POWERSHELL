#region funciones
function EnviarEmailDotNet {
    [CmdletBinding()]
    param(
        [string[]]$To, 
        [string]$Subject,
        [string]$Body,
        [string[]]$Attachments
    )

    $SmtpServer = "smtp.canal.acp"
    $Msg = New-Object Net.Mail.MailMessage
    $Smtp = New-Object Net.Mail.SmtpClient($SmtpServer)
    $Msg.From = "powershell@pancanal.com"
    $To | ForEach-Object { $Msg.To.Add($_) }
    $Msg.Subject = $Subject
    $Msg.Body = $Body
    $Attachments | ForEach-Object { $Msg.Attachments.Add((New-Object Net.Mail.Attachment($_))) }
    $Smtp.Send($Msg)
}
#endregion

#region modulos
Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.Compute -ErrorAction Stop
Import-Module ImportExcel -ErrorAction Stop
#endregion

#region autenticacion
# Iniciando sesión en Azure con identidad gestionada    
Write-Host "Iniciando sesión en Azure..." -ForegroundColor Yellow
$clientId = "deb8c261-267b-44e4-9449-cd45339837e1"
Connect-AzAccount -Identity -AccountId $clientId -ErrorAction Stop
Set-AzContext -Subscription "521ba46c-e50d-4068-85f4-98d48a35b75e" -ErrorAction Stop
#endregion

#region variables
$rgName = "azuremigratedapps-eus2-rg-dev-01"
$vms = Get-AzVM -ResourceGroupName $rgName -ErrorAction Stop
$jobs = @()
$salidaxlsx = "E:\powershell\output\azure-exadata-vms-apagadas.xlsx"
#endregion

#region apagar VMs en paralelo
foreach ($vm in $vms) {
    Write-Host  "Apagando " $vm.name -ForegroundColor Yellow
        $job = Start-Job -ScriptBlock {
        param($vmName, $rgName)
        Stop-AzVM -Name $vmName -ResourceGroupName $rgName -Force -NoWait #-WhatIf
    } -ArgumentList $vm.Name, $rgName
    $jobs += $job
}
#endregion

#region esperar a que terminen los jobs
$jobs | ForEach-Object { $_ | Wait-Job }
#endregion
#region verificar estado de las VMs
$vmsStatus = @()
foreach ($vm in $vms) {
    $status = Get-AzVM -ResourceGroupName $rgName -Name $vm.Name -Status
    $powerState = $status.Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -ExpandProperty DisplayStatus
    $vmsStatus += [PSCustomObject]@{
        VMName = $vm.Name
        PowerState = $powerState
    }
}
#endregion

#region salida
$vmsStatus | Export-Excel  $salidaxlsx -AutoSize -AutoFilter
# Enviar correo con los resultados
Write-Output "Enviando correo con los resultados..."
EnviarEmailDotNet -To @("syscloud@pancanal.com") `
    -Subject "Azure - Servidores Exadata Dev - Apagado" `
    -Body "Apagado de servidores $(Get-Date -Format 'yyyy-MM-dd')." `
    -Attachments @($salidaxlsx)

Write-Output "Fin del script"
#endregion
