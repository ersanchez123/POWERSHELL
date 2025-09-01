######################################################################################
#
#EJECUCION DE SCRIPT ROBOCOPY ELEVADO CON PSEXEC
#######################################################################################
#
#Programa: 2_Robocopyelevado.ps1
#
# Autor: Eric Noriel Sanchez
#
# FECHA : 14 Julio 2025
#########################################################################################
#DESCRIPCION: El siguiente Script realiza la copia de ROBOCOPY para la maquina de Trabajo 
#"syscloud-windows11" , Basicamente toma todos los datos de disco de Sistema Origen J:\
# Y lo copia a Disco de Sistema Destino K:\
#
#Recomendacion: Los discos deben estar Atachados y Listos para el COPY, ejecutado con 
#Usuario Administracion en AZURE, el PSEXEC debe estar instalado en la Maquina de Trabajo
# Se eleva el comando ROBOCOPY mediante un Start-Process
#
#OPERACIONES
##############
#1. Realiza un Robocopy elevado con Start-Process.
#2. Utiliza la funcionalidad de PSEXEC en la maquina VM.
#3. Cuando se esta en el Proceso de Copiado de J:\  a K:\ se genera un Log en el disco C:\
#   robocopyOS.log se ve el avance de la copia.
########################################################################################


#Generacion de Parametros Iniciales
param (
    [string]$suscripcion = "57ad0d81-2582-4def-b755-6e0ed5612d13",
    [string]$azureadmin = "ernoisanchez@pancanal.com",
    [string]$WorkVMName = "syscloud-windows11",
    [string]$ResourceGroup = "SYSCLOUD-EUS2-RG-PRD-01"
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


#ROBOCOPY CON PSEXEC ELEVADO
#-----------------------------------------
# Script que se ejecutará dentro de la VM(La evelacion se logra con el PSExec)
$script3 = @'
Write-Host "✅ Iniciando Robocopy con PsExec elevado..."

# Ruta de PsExec en la VM
$psexecPath = "C:\Tools\PsExec.exe"

# Crear el script de robocopy
$robocopyScript = @"
Start-Process -FilePath 'robocopy.exe' -ArgumentList @(
    'J:\',
    'K:\',
    '/COPYALL',
    '/E',
    '/ZB',
    '/MIR',
    '/XD', 'System Volume Information', '$RECYCLE.BIN', 'WindowsAzure',
    '/XF', 'pagefile.sys', 'swapfile.sys',
    '/XJ',
    '/R:1',
    '/W:1',
    '/MT:13',
    '/LOG:C:\robocopyOS.log'
) -Wait
"@

# Guardar el script temporalmente
$tempScriptPath = "$env:TEMP\robocopy_elevado.ps1"
$robocopyScript | Out-File -FilePath $tempScriptPath -Encoding UTF8

# Ejecutar robocopy con PsExec elevado
Start-Process -FilePath $psexecPath -ArgumentList "-accepteula -h powershell.exe -ExecutionPolicy Bypass -File `"$tempScriptPath`"" -Wait
'@
#El script se ejecuta en la VM Uso del PSExec, Robocopy para ello se hace un script con el 
#Robocopy y se llama directamete con el -Ecoding UTF 
#Con funcionalidad de Admin Sistemas para que copie todos los Files


#EJECUCION DEL SCRIPT DENTRO DE LA VM 
$cmd = Get-AzVMRunCommand -ResourceGroupName $ResourceGroup -VMName $WorkVMName
if ($cmd.InstanceViewExecutionState -ne "Running") {
   Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroup `
                      -VMName $WorkVMName `
                      -CommandId 'RunPowerShellScript' `
                      -ScriptString $script3
} else {
    Remove-AzVMRunCommand -ResourceGroupName $ResourceGroup -VMName $WorkVMName -RunCommandName "RobocopyElevado"
   
}

Write-Output "Proceso Robocopy completado"