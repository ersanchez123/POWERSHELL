
param(
    [string]$ResourceGroupName="rs_group1",
    [string]$UAMIName ="miuser"
)

# Desactiva el autosave del contexto para evitar conflictos
Disable-AzContextAutosave -Scope Process

#region modulos
Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.Compute -ErrorAction Stop
#endregion

# Conexión inicial con la identidad del Automation Account
$initialContext = (Connect-AzAccount -Identity).Context
Set-AzContext -SubscriptionId $initialContext.Subscription.Id -DefaultProfile $initialContext

# Obtener la identidad administrada asignada por el usuario
$uami = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $UAMIName -DefaultProfile $initialContext

# Conectarse usando la UAMI
$uamiContext = (Connect-AzAccount -Identity -AccountId $uami.ClientId).Context
Set-AzContext -SubscriptionId $uamiContext.Subscription.Id -DefaultProfile $uamiContext

# Obtener las VMs del grupo de recursos
$vms = Get-AzVM -ResourceGroupName $ResourceGroupName -DefaultProfile $uamiContext

foreach ($vm in $vms) {
    Write-Output "Apagando VM: $($vm.Name)"
    Stop-AzVM -Name $vm.Name -ResourceGroupName $ResourceGroupName -Force -DefaultProfile $uamiContext
}
