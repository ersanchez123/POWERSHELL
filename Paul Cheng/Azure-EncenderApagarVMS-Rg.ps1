Import-Module AZ
$credenciales = Get-Credential
Connect-AzAccount -Credential $credenciales -ErrorAction Stop -Verbose
Enable-AzureRmAlias

#region Suscripciones

#ACP Produccion
$context = Get-AzSubscription -SubscriptionId 57ad0d81-2582-4def-b755-6e0ed5612d13
Set-AzContext $context
#endregion

$resourcegroup = "vdc-eus2-rg-prd-01"

# Antes
Get-AzVM -ResourceGroupName $resourcegroup -Status | Select-Object name,powerstate

# Encendido
Get-AzVM -ResourceGroupName $resourcegroup  | Start-AzVM  -NoWait 

# Apagado
Get-AzVM -ResourceGroupName $resourcegroup | Stop-AzVM -Force -NoWait

# Despues
Get-AzVM -ResourceGroupName $resourcegroup -Status | Select-Object name,powerstate
