
# Script para apagar una máquina virtual en Azure usando Managed Identity y Runbook
# autor : Eric Noriel Sanchez
# fecha : 2025-09-11

param (
    [string]$ResourceGroupName="rg_group1",
    [string]$VMName="VMWindows123"
)

# Paso 1: Autenticación con Managed Identity
# $account = Connect-AzAccount -Identity 

$clientId = "edb7424f-a087-4b66-8aef-92b7acf22bec"
Connect-AzAccount -Identity -AccountId $clientId -ErrorAction Stop
Set-AzContext -Subscription "02f2cf5d-5232-4c7b-bef3-080a3c7e1c8c" -ErrorAction Stop


# Paso 2: Obtener suscripciones disponibles
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }

if (-not $subscriptions) {
    throw "No se encontraron suscripciones habilitadas para esta identidad."
}

# Mostrar todas las suscripciones disponibles
Write-Output "Suscripciones disponibles:"
$subscriptions | ForEach-Object {
    Write-Output "Nombre: $($_.Name), ID: $($_.Id), TenantId: $($_.TenantId)"
}

# Paso 3: Seleccionar la primera suscripción (o puedes filtrar por ID si lo prefieres)
$selectedSub = $subscriptions | Select-Object -First 1
Write-Output "Usando suscripción: $($selectedSub.Name) - $($selectedSub.Id)"

# Paso 4: Establecer el contexto
Set-AzContext -SubscriptionId $selectedSub.Id

# Paso 5: Confirmar contexto
$currentContext = Get-AzContext
Write-Output "Contexto actual:"
Write-Output "SubscriptionId: $($currentContext.Subscription.Id)"
Write-Output "TenantId: $($currentContext.Tenant.Id)"
Write-Output "Account: $($currentContext.Account)"

# Paso 6: Apagar la máquina virtual
Write-Output "Apagando la VM: $VMName en el grupo de recursos: $ResourceGroupName"
Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
Write-Output "VM apagada correctamente."
