param (
    [Parameter(Mandatory = $true)]
    [string]$subscriptionName
)

# Constants – update these if needed
$workspaceName = "mon-eus2-log-prd-01"
$workspaceResourceGroup = "monitor-eus2-rg-prd-01"

# Set the Azure subscription
Write-Host "Setting subscription to '$subscriptionName'..."
az account set --subscription $subscriptionName

# Get the Log Analytics workspace ID
Write-Host "Retrieving Log Analytics workspace ID..."
$workspace = az monitor log-analytics workspace show `
    --resource-group $workspaceResourceGroup `
    --workspace-name $workspaceName `
    --query "id" -o tsv

if (-not $workspace) {
    Write-Error "Failed to retrieve Log Analytics workspace ID. Please check the workspace name and resource group."
    exit 1
}

# Get all VMs in the subscription
Write-Host "Retrieving all VMs in subscription '$subscriptionName'..."
$vms = az vm list -o json | ConvertFrom-Json

if ($vms.Count -eq 0) {
    Write-Host "No VMs found in subscription '$subscriptionName'."
    exit 0
}

# Loop through each VM and apply diagnostic settings
foreach ($vm in $vms) {
    $vmName = $vm.name
    $vmId = $vm.id
    $vmResourceGroup = $vm.resourceGroup

    Write-Host "`nApplying diagnostic settings to VM: $vmName (Resource Group: $vmResourceGroup)...