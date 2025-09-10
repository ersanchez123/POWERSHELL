Import-Module AZ
$credenciales = Get-Credential
Connect-AzAccount -Credential $credenciales -ErrorAction Stop -Verbose
Enable-AzureRmAlias

#region Suscripciones

#ACP Produccion
$context = Get-AzSubscription -SubscriptionId 02f2cf5d-5232-4c7b-bef3-080a3c7e1c8c
Set-AzContext $context
#endregion

$resourcegroup = "rg_group1"

# Antes
Get-AzVM -ResourceGroupName $resourcegroup -Status | Select-Object name,powerstate

# Encendido
#Get-AzVM -ResourceGroupName $resourcegroup  | Start-AzVM  -NoWait 

# Apagado
#Get-AzVM -ResourceGroupName $resourcegroup | Stop-AzVM -Force -NoWait

# Despues
#Get-AzVM -ResourceGroupName $resourcegroup -Status | Select-Object name,powerstate
