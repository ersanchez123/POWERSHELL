######################################################################################
#
#EJECUCION DE SCRIPT COPIA DISCO DE DATOS DE UNA VM AZURE
#######################################################################################
#
#Programa: CopiaDiscoDATA.ps1
#
# Autor: Eric Noriel Sanchez
#
# FECHA : 21 Julio 2025
#
# Execution:  CopiaDiscoData.ps1 "syscloud-prod7" "syscloud-eus2-rg-prd-01" "East US 2" "2"
#
######################################################################################
param (
    #[Parameter(Mandatory = $true)]
    [string]$VMName ="syscloud-prod7",

    #[Parameter(Mandatory = $true)]
    [string]$ResourceGroup ="syscloud-eus2-rg-prd-01",

    #[Parameter(Mandatory = $true)]
    [string]$Location ="East US 2",

    #[Parameter(Mandatory = $false)]
    [string]$Zone ="2"  # Puedes ajustar esto según tu configuración

)

$suscripcion = "57ad0d81-2582-4def-b755-6e0ed5612d13"
$azureadmin = "ernoisanchez@pancanal.com"

Import-Module Az.Accounts
#region Inicia sesión en Azure
#Import-Module -name Az -ErrorAction Stop
try {
    Connect-AzAccount -Subscription $suscripcion -AccountId $azureadmin 
    #Connect-AzAccount
    Write-Host "Inicio de sesión en Azure exitoso." -ForegroundColor Green
}
catch {
    Write-Error "Error al iniciar sesión en Azure. Detalles: $_"
    exit
}
#endregion


#ACP Produccion
#$context = Get-AzSubscription -SubscriptionId $suscripcion
#Set-AzContext $context

# Obtener la fecha actual
$fecha = Get-Date -Format "yyyyMMdd-HHmm"

# Obtener la VM
$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup

# Iterar sobre los discos de datos
foreach ($dataDisk in $vm.StorageProfile.DataDisks) {
    $diskName = $dataDisk.Name
    $disk = Get-AzDisk -ResourceGroupName $ResourceGroup -DiskName $diskName

    # Crear snapshot del disco de datos
    $snapshotConfig = New-AzSnapshotConfig -SourceUri $disk.Id -Location $Location -CreateOption Copy -SkuName Standard_LRS
    $snapshotName = "$($diskName)Snapshot$fecha"
    $snapshot = New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName $snapshotName -ResourceGroupName $ResourceGroup

    # Crear disco desde snapshot
    $diskConfig = New-AzDiskConfig -Location $Location -CreateOption Copy -SourceResourceId $snapshot.Id -SkuName Standard_LRS -Zone $Zone
    $newDiskName = "$($diskName)DataDiskCopy$fecha"
    $newDisk = New-AzDisk -DiskName $newDiskName -Disk $diskConfig -ResourceGroupName $ResourceGroup

    Write-Output "Snapshot y copia del disco '$diskName' creados exitosamente."
    Write-Output "Disco '$newDisk' creado exitosamente."
}
