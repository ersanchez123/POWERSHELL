######################################################################################
#
#EJECUCION DE SCRIPT DESATACHAR y ATACHAR
#######################################################################################
#
#Programa: 3_Desatach.ps1
#
# Autor: Eric Noriel Sanchez
#
# FECHA : 16 Julio 2025
#########################################################################################
#DESCRIPCION: El siguiente Script realiza el desatachado o disociacion de los Discos 
#             de la VM de TRABAJO una vez copiado con el Script anterior 
#             2_Robocopyelevado.ps1 y la asociacion a la Nueva VM creada
#             para eso hace un SWAP de disco de Sistema con el Disco Nuevo.
#
#OPERACIONES
##############
#1. Desatacha el disco Destino de la maquina de Trabajo.
#2. Atacha a la Maquina virtual Nueva el Disco de sistema.
#3. Se encientre la VM nueva con el nuevo disco de sistema Operativo recien aplicado
#   lka transfusion.
########################################################################################
param (
    [string]$suscripcion = "57ad0d81-2582-4def-b755-6e0ed5612d13",
    [string]$azureadmin = "ernoisanchez@pancanal.com",
    [string]$OriginalVMName = "syscloud-prod-Test",
    [string]$NewVMName = "syscloud-TestV3",
    [string]$WorkVMName = "syscloud-windows11",
    [string]$ResourceGroup = "SYSCLOUD-EUS2-RG-PRD-01"

)

$fecha = Get-Date -Format "yyyyMMdd"
#region Inicia sesión en Azure
#Import-Module -name Az -ErrorAction Stop
Import-Module Az.Accounts

try {
    Connect-AzAccount -Subscription $suscripcion -AccountId $azureadmin
    Write-Host "Inicio de sesión en Azure exitoso." -ForegroundColor Green
}
catch {
    Write-Error "Error al iniciar sesión en Azure. Detalles: $_"
    exit
}

#ASIGNACION DE NOMBRE DE DISCO A ATTACHAR
$destDiskName  = "$NewVMName-OSCopy-$fecha"


#Desattachar disco destino
$workVM = Get-AzVM -Name $WorkVMName -ResourceGroupName $ResourceGroup

# Verificar si el disco existe en la VM
$destDisk = $workVM.StorageProfile.DataDisks | Where-Object { $_.Name -eq $destDiskName }

if ($destDisk) {
    Write-Host "Desasociando disco: $destDiskName"

# Crear una lista vacía del tipo correcto
    $typedDiskList = New-Object 'System.Collections.Generic.List[Microsoft.Azure.Management.Compute.Models.DataDisk]'

# Filtrar y agregar los discos válidos para no DESATTACHAR
    foreach ($disk in $workVM.StorageProfile.DataDisks) {
        if ($disk.Name -ne $destDiskName) {
             $typedDiskList.Add($disk)
            }
    }

# Asignar la lista tipada a la VM
   $workVM.StorageProfile.DataDisks = $typedDiskList

  # Actualizar la VM
    Update-AzVM -VM $workVM -ResourceGroupName $ResourceGroup

    Write-Host "Disco desasociado correctamente."
} else {
    Write-Warning "El disco '$destDiskName' no está asociado a la VM '$WorkVMName'."
}

# Swap OS Disk en la VM Recien Creada

# Get the VM 
$vm = Get-AzVM -ResourceGroupName $ResourceGroup -Name $NewVMName

# (Optional) Stop/ deallocate the VM
Stop-AzVM -ResourceGroupName $ResourceGroup -Name $vm.Name -Force

# Get the new disk that you want to swap in
$disk = Get-AzDisk -ResourceGroupName $ResourceGroup -Name $destDiskName

# Set the VM configuration to point to the new disk  
Set-AzVMOSDisk -VM $vm -ManagedDiskId $disk.Id -Name $disk.Name 

# Update the VM with the new OS disk
Update-AzVM -ResourceGroupName $ResourceGroup -VM $vm 

# Start the VM
Start-AzVM -Name $vm.Name -ResourceGroupName $ResourceGroup 

Write-Output "Proceso completado y Finalizado"


