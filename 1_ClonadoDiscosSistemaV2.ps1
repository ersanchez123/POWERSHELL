#################################################################################################
#
#EJECUCION DE SCRIPT PARA OPerACIONES CON DISCOS DE SISTEMA Y GENERACION DE VM NUEVA
#################################################################################################
#
#Programa: 1_ClonadoDiscosSistemaV2.ps1
#
# Autor: Eric Noriel Sanchez
#
# FECHA : 15 Julio 2025
##################################################################################################
#DESCRIPCION: El siguiente Script realiza las operaciones de :
#
# 1. Creacion de snapshop de los Discos
# 2. Creacion de Discos a partir de los Snapshop
# 3. Creacion de la VM nueva con la nueva Red y de tipo TrustedLaunch(Mayores SIZE)
# 4. El script toma la maquina $OriginalVMName  como maquina a clonar y 
#    $NewVMName  la nueva VM a crear.
# 5. Los SNAPSHOP: $OriginalVMName-Snapshop-$fecha-PRE  (ORIGEN)
#                 $NewVMName-Snapshop-$fecha-PRE       (DESTINO)
# 6. Los DISCOS:  $OriginalVMName-OSCopy-$fecha-PRE     (ORIGEN)
#                $NewVMName-OSCopy-$fecha              (DESTINO)
#
#7. Atachar Discos a la maquina de Trabajo.
#8.Asignacion de Unidades a los discos (J y K) respectivamente                
#9. Realiza tambien un CHSKDISK de los DISCOS J y K antes del Proceso siguiente que es el ROBOCOPY
#
###################################################################################################
#Generacion de Parametros Iniciales
param (
    [string]$suscripcion = "57ad0d81-2582-4def-b755-6e0ed5612d13",
    [string]$azureadmin = "ernoisanchez@pancanal.com",
    [string]$OriginalVMName = "syscloud-prod-Test",
    [string]$NewVMName = "syscloud-TestV3",
    [string]$WorkVMName = "syscloud-windows11",
    [string]$ResourceGroup = "SYSCLOUD-EUS2-RG-PRD-01",
    [string]$NewResourceGroup = "netw-eus2-rg-prd-01",
    [string]$VMSize='Standard_D4as_v5',
    [string]$Location = "East US 2",
    [string]$VNetName = "netw-eus2-vnet-prd-01",
    [string]$SubnetName = "vdi-eus2-snet-prd-01",
    [string]$Zone = "1"  # Puedes automatizar esto si deseas que sea igual a la original
)

Import-Module Az.Accounts
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

#ACP Produccion
$context = Get-AzSubscription -SubscriptionId $suscripcion
Set-AzContext $context


# Obtener fecha
$fecha = Get-Date -Format "yyyyMMdd"

$adminUsername = "adminuser"
$adminPassword = "ContraseñaSegura123!"


# 1. Detener VM original
Stop-AzVM -Name $OriginalVMName -ResourceGroupName $ResourceGroup -Force

# 2. Obtener disco de sistema
$vm = Get-AzVM -Name $OriginalVMName -ResourceGroupName $ResourceGroup
$osDisk = Get-AzDisk -ResourceGroupName $ResourceGroup -DiskName $vm.StorageProfile.OsDisk.Name

# 3. Crear snapshot del disco original
$snapshotConfig = New-AzSnapshotConfig -SourceUri $osDisk.Id -Location $Location -CreateOption Copy -SkuName Standard_LRS 
$snapshot = New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName "$OriginalVMName-Snapshop-$fecha-PRE" -ResourceGroupName $ResourceGroup

# 4. Crear disco desde snapshot
$diskConfig = New-AzDiskConfig -Location $Location -CreateOption Copy -SourceResourceId $snapshot.Id -SkuName Standard_LRS -Zone $Zone
$originalDiskCopy = New-AzDisk -DiskName "$OriginalVMName-OSCopy-$fecha-PRE" -Disk $diskConfig -ResourceGroupName $ResourceGroup


# 5. Crear NIC para nueva VM
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork (Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $NewResourceGroup)
$nic = New-AzNetworkInterface -Name "$NewVMName-nic" -ResourceGroupName $NewResourceGroup -Location $Location -SubnetId $subnet.Id

# 6. Crear nueva VM destino
# Convert password to a secure string
$securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
# Create PSCredential object
$cred = New-Object System.Management.Automation.PSCredential ($adminUsername, $securePassword)
#$cred = Get-Credential

$vmConfig = New-AzVMConfig -VMName $NewVMName -VMSize $VMSize -Zone $Zone
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $NewVMName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
$vmConfig = Set-AzVMOSDisk -VM $vmConfig -CreateOption FromImage -DiskSizeInGB 127 -StorageAccountType Standard_LRS
$vmConfig.SecurityProfile = @{ SecurityType = "TrustedLaunch" }

New-AzVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vmConfig

# 9. Detener VM New
Stop-AzVM -Name $NewVMName -ResourceGroupName $ResourceGroup -Force

# 10. Snapshot del disco de la nueva VM
$newVM = Get-AzVM -Name $NewVMName -ResourceGroupName $ResourceGroup
$newOSDisk = Get-AzDisk -ResourceGroupName $ResourceGroup -DiskName $newVM.StorageProfile.OsDisk.Name
$newSnapshotConfig = New-AzSnapshotConfig -SourceUri $newOSDisk.Id -Location $Location -CreateOption Copy -SkuName Standard_LRS
$newSnapshot = New-AzSnapshot -Snapshot $newSnapshotConfig -SnapshotName "$NewVMName-Snapshop-$fecha-PRE" -ResourceGroupName $ResourceGroup

# 11. Crear disco desde snapshot destino
$newDiskConfig = New-AzDiskConfig -Location $Location -CreateOption Copy -SourceResourceId $newSnapshot.Id -SkuName Standard_LRS -Zone $Zone
$destDisk = New-AzDisk -DiskName "$NewVMName-OSCopy-$fecha" -Disk $newDiskConfig -ResourceGroupName $ResourceGroup

# 11 y 12. Encender VM original y de trabajo
Start-AzVM -Name $OriginalVMName -ResourceGroupName $ResourceGroup
Start-AzVM -Name $WorkVMName -ResourceGroupName $ResourceGroup

# 13. Desattachar discos de la VM de trabajo
$workVM = Get-AzVM -Name $WorkVMName -ResourceGroupName $ResourceGroup
$workVM.StorageProfile.DataDisks.Clear()
Update-AzVM -VM $workVM -ResourceGroupName $ResourceGroup

# 14. Atachar discos original 
Add-AzVMDataDisk -VM $workVM -Name $originalDiskCopy.Name -CreateOption Attach -ManagedDiskId $originalDiskCopy.Id -Lun 0
#Add-AzVMDataDisk -VM $workVM -Name "$OriginalVMName-OSCopy-$fecha-PRE" -CreateOption Attach -ManagedDiskId $originalDiskCopy.Id -Lun 0

Update-AzVM -VM $workVM -ResourceGroupName $ResourceGroup

$script = @"
Get-Partition -DriveLetter E | Set-Partition -NewDriveLetter J
"@

Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroup  `
                      -VMName $WorkVMName `
                      -CommandId 'RunPowerShellScript' `
                      -ScriptString $script



#15  Atachar disco destino
Add-AzVMDataDisk -VM $workVM -Name $destDisk.Name -CreateOption Attach -ManagedDiskId $destDisk.Id -Lun 1
Update-AzVM -VM $workVM -ResourceGroupName $ResourceGroup

$script2 = @"
Get-Partition -DriveLetter E | Set-Partition -NewDriveLetter K
"@

Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroup  `
                      -VMName $WorkVMName `
                      -CommandId 'RunPowerShellScript' `
                      -ScriptString $script2



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

Write-Output "Proceso de snapshop, discos y Creacion de VM Completado"

