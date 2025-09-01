param (
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
#COnexion AZURE
Connect-AzAccount

#$script = "Get-Volume | Select-Object DriveLetter, FileSystemLabel, SizeRemaining, Size"

#Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroup `
                      #-VMName $WorkVMName `
                      #-CommandId 'RunPowerShellScript' `
                      #-ScriptString $script



$script = @"
Get-Partition -DriveLetter E | Set-Partition -NewDriveLetter J
"@

Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroup  `
                      -VMName $WorkVMName `
                      -CommandId 'RunPowerShellScript' `
                      -ScriptString $script
