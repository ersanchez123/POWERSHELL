param (
    [string]$suscripcion = "57ad0d81-2582-4def-b755-6e0ed5612d13",
    [string]$azureadmin = "ernoisanchez@pancanal.com",
    [string]$OriginalVMName = "syscloud-prod-Test",
    [string]$NewVMName = "syscloud-TestV2",
    [string]$WorkVMName = "syscloud-windows11",
    [string]$ResourceGroup = "SYSCLOUD-EUS2-RG-PRD-01",
    [string]$NewResourceGroup = "netw-eus2-rg-prd-01",
    [string]$VMSize='Standard_D4as_v5',
    [string]$Location = "East US 2",
    [string]$VNetName = "netw-eus2-vnet-prd-01",
    [string]$SubnetName = "vdi-eus2-snet-prd-01",
    [string]$Zone = "1"  # Puedes automatizar esto si deseas que sea igual a la original
)

#region Inicia sesión en Azure
#Import-Module -name Az -ErrorAction Stop
try {
    Connect-AzAccount -Subscription $suscripcion -AccountId $azureadmin
    Write-Host "Inicio de sesión en Azure exitoso." -ForegroundColor Green
}
catch {
    Write-Error "Error al iniciar sesión en Azure. Detalles: $_"
    exit
}
#endregion


$script3 = @"
chkdsk J: /F > C:\chkdsk_J_log.txt
"@

Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroup `
                      -VMName $WorkVMName `
                      -CommandId 'RunPowerShellScript' `
                      -ScriptString $script3

$script4 = @"
chkdsk K: /F > C:\chkdsk_K_log.txt
"@

Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroup `
                      -VMName $WorkVMName `
                      -CommandId 'RunPowerShellScript' `
                      -ScriptString $script4


#Get-AzVMRunCommand -ResourceGroupName $ResourceGroup -VMName $WorkVMName
#Get-AzVMRunCommand -ResourceGroupName "SYSCLOUD-EUS2-RG-PRD-01" -VMName "syscloud-windows11"