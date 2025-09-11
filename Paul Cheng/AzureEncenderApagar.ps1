
Write-Host "Iniciando sesión en Azure..." -ForegroundColor Yellow

#$credenciales = Get-Credential
#Connect-AzAccount -Credential $credenciales -ErrorAction Stop -Verbose

Import-Module AZ
$clientId = "edb7424f-a087-4b66-8aef-92b7acf22bec"
Connect-AzAccount -Identity -AccountId $clientId -ErrorAction Stop

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
#Get-AzVM -ResourceGroupName "rg_group1" | Start-AzVM  -NoWait 

# Apagado
#Get-AzVM -ResourceGroupName $resourcegroup | Stop-AzVM -Force -NoWait

#Get-AzVM -ResourceGroupName "rg_group1" | Stop-AzVM -Force -NoWait

# Despues
#Get-AzVM -ResourceGroupName $resourcegroup -Status | Select-Object name,powerstate
