Import-Module AZ
Connect-AzAccount



Enable-AzureRmAlias

#region Suscripciones

#ACP Produccion
$context = Get-AzSubscription -SubscriptionId 57ad0d81-2582-4def-b755-6e0ed5612d13
Set-AzContext $context

# ACP Innovacion a934be38-18ed-417b-a39c-c527695899b6
# $context = Get-AzSubscription -SubscriptionId a934be38-18ed-417b-a39c-c527695899b6
# Set-AzContext $context

# Servicios 263c7f88-a92b-47ff-9819-af2f218dcbe8
# $context = Get-AzSubscription -SubscriptionId 263c7f88-a92b-47ff-9819-af2f218dcbe8
# Set-AzContext $context

# AcpDataCenter cd9ca105-dd28-458e-ac4c-d01dc35c30ac
# $context = Get-AzSubscription -SubscriptionId cd9ca105-dd28-458e-ac4c-d01dc35c30ac
# Set-AzContext $context

# ACPCloud 3048dd0f-423e-40f1-b251-61e681fda259
# $context = Get-AzSubscription -SubscriptionId 3048dd0f-423e-40f1-b251-61e681fda259
# Set-AzContext $context

#Modelos Predictivos 91c3f4cb-950d-43ce-88c9-4ed506657134
#$context = Get-AzSubscription -SubscriptionId 91c3f4cb-950d-43ce-88c9-4ed506657134
#Set-AzContext $context

#MICANAL 4e4c9605-199e-4847-a663-09292497d4a7

#endregion

#region Cantidad de Recursos
#Se necesita el modulo de AzGraph
#https://docs.microsoft.com/en-us/azure/governance/resource-graph/samples/starter?tabs=azure-powershell#list-resources
Import-Module -Name Az.ResourceGraph
Clear-Host
Search-AzGraph -Query "Resources | summarize count()" -Subscription 57ad0d81-2582-4def-b755-6e0ed5612d13
Search-AzGraph -Query "Resources | summarize count()" -Subscription a934be38-18ed-417b-a39c-c527695899b6
Search-AzGraph -Query "Resources | summarize count()" -Subscription 263c7f88-a92b-47ff-9819-af2f218dcbe8
Search-AzGraph -Query "Resources | summarize count()" -Subscription cd9ca105-dd28-458e-ac4c-d01dc35c30ac
Search-AzGraph -Query "Resources | summarize count()" -Subscription 3048dd0f-423e-40f1-b251-61e681fda259
Search-AzGraph -Query "Resources | summarize count()" -Subscription 91c3f4cb-950d-43ce-88c9-4ed506657134
Search-AzGraph -Query "Resources | summarize count()" -Subscription 4e4c9605-199e-4847-a663-09292497d4a7
#endregion

#region Proyecto MIRA
$rg = Get-AzResourceGroup | Select-Object resourcegroupname,location | Sort-Object resourcegroupname
Get-AzResource -ResourceGroupName rg-mira-dev-use2 | Sort-Object ResourceType,Name | ft -AutoSize | Out-File C:\powershell\output\miradev.txt
Get-AzResource -ResourceGroupName rg-mirapre-use2  | Sort-Object ResourceType,Name | ft -AutoSize | Out-File C:\powershell\output\mirapre.txt
Get-AzResource -ResourceGroupName rg-miraprod-eus2 | Sort-Object ResourceType,Name | ft -AutoSize | Out-File C:\powershell\output\miraprod.txt
Get-AzResource -ResourceGroupName RG-GestLabor-DEV-EUS2 | Sort-Object ResourceType,Name | ft -AutoSize | Out-File C:\powershell\output\RG-GestLabor-Dev.txt
Get-AzResource -ResourceGroupName RG-GestLabor-Prod-EUS2 | Sort-Object ResourceType,Name | ft -AutoSize | Out-File C:\powershell\output\RG-GestLabor-Prod.txt

#Get-AzVM -ResourceGroupName rg-miraprod-eus2 -Status | ft -AutoSize
#Get-AzVM -ResourceGroupName rg-mira-dev-use2 -Status | start-AzVM -Force
#Get-AzVM -ResourceGroupName rg-mirapre-use2 -Status  | stop-AzVM -verbose -Force
#endregion

#region Proyecto Virtual Desktops
#Get-AzVM -ResourceGroupName rg-acpvirtualdesktops-eus2 -Status | ft -AutoSize
#Get-AzVM -ResourceGroupName rg-acpvirtualdesktops-eus2 | Stop-AzVM -Force
#Get-AzVM -ResourceGroupName rg-acpvirtualdesktops-eus2 | Start-AzVM

#Stop-AzVM -ResourceGroupName rg-acpvirtualdesktops-eus2 -Name wvd-kiosko-0 -Force 
#Stop-AzVM -ResourceGroupName rg-acpvirtualdesktops-eus2 -Name wvd-kiosko-1 -Force 

Get-AzADGroupMember -GroupDisplayName wvd-ingenieria | Select-Object userprincipalname | Sort-Object userprincipalname
#endregion

#SQL Server
Get-AzVM -ResourceGroupName MBDESU2RGDES01 -Status | ft -AutoSize

#Bamboo Azure
Get-AzVM -ResourceGroupName BAMBEUS2RG01 -Status | ft -AutoSize


#region permisos
#suscripcion
Get-AzRoleAssignment | Select-Object RoleDefinitionName,Scope,DisplayName | Sort-Object RoleDefinitionName,DisplayName | export-csv C:\powershell\output\AZR_ACPProduccion.csv -NoTypeInformation

#resource groups
$salida = @()
$resourcegroups = Get-AzResourceGroup | Select-Object resourcegroupname
foreach($resourcegroup in $resourcegroups){
$salida+= $resourcegroup.ResourceGroupName
    $salida+= Get-AzRoleAssignment -ResourceGroupName $resourcegroup.ResourceGroupName | Select-Object RoleDefinitionName,DisplayName
  
    
    
    }
$salida | out-file C:\powershell\output\Permisos_ResourceGroups_ACPProduccion.txt

#endregion

#region reporte de recursos
$salida = @()
$resourcegroups = Get-AzResourceGroup | Select-Object resourcegroupname
Write-Host "Resource Group: " $resourcegroup.ResourceGroupName
foreach($resourcegroup in $resourcegroups){
    $salida+= Get-AzResource -ResourceGroupName $resourcegroup.ResourceGroupName | Select-Object Name,ResourceGroupName,ResourceType,Location,Tags,ResourceID
    }
$salida | Out-File C:\powershell\output\ACPProduccion.txt
#endregion

#region Uso de Tags

Get-AzTag 
$array = @()
$recursos = Get-AzResource -ResourceGroupName rg-miraprod-eus2 | Select-Object ResourceID
foreach($recurso in $recursos){ 
    $lista = Get-AzTag -ResourceId $recurso.ResourceId
    $array += $lista
    }

(Get-AzResource -ResourceGroupName rg-mira-dev-use2).Tags
(Get-AzResource -ResourceGroupName rg-mirapre-use2).Tags
(Get-AzResource -ResourceGroupName rg-miraprod-eus2).Tags

#Elimina los tags del Resource Group
#Desarollo
Set-AzureRmResourceGroup -Name rg-mirapre-use2 -Tag @{}

#CentroDeDatos
Set-AzureRmResourceGroup -Name DUOMFAEUS2RGPROD01 -Tag @{}



#Limpiar todos tags de los objetos dentro del resource group se necesita el ResourceID
Get-AzResource -ResourceGroupName rg-mira-dev-use2 | Select-Object ResourceID | Remove-AzTag -Verbose
Get-AzResource -ResourceGroupName rg-mirapre-use2 | Select-Object ResourceID | Remove-AzTag -Verbose
Get-AzResource -ResourceGroupName rg-miraprod-eus2 | Select-Object ResourceID | Remove-AzTag -Verbose
Get-AzResource -ResourceGroupName ADDCEUS2RG01 | Select-Object ResourceID | Remove-AzTag -Verbose

#Limpia todos los tags de todos los rg de una subscripcion
$resourcegroups = Get-AzResourceGroup | Select-Object resourcegroupname,location | Sort-Object resourcegroupname
foreach($resourcegroup in $resourcegroups){
    Get-AzResource -ResourceGroupName $resourcegroup.ResourceGroupName | Select-Object ResourceID | Remove-AzTag -Verbose
    }


#Asignar Tags y reemplazar los existentes
$tags = @{“app”=”mira”; “env”=”dev”}
Get-AzResource -ResourceGroupName rg-mira-dev-use2| select-object ResourceID | Update-AzTag -Tag $tags -Operation Replace -Verbose

#Desconocido
#$devrg = "BLACKBOXPP"
#$tags = @{“app”=”desconocido";}
#Set-AzureRmResourceGroup -Name $devrg -Tag @{}
#Set-AzureRmResourceGroup -Name $devrg -Tag $tags
#Get-AzResource -ResourceGroupName $devrg | select-object ResourceID | Update-AzTag -Tag $tags -Operation Replace -Verbose

#Desarrollo
$devrg = "VAISEUS2RG01"
$tags = @{“app”=”vais"; “env”=”prod”}
Set-AzureRmResourceGroup -Name $devrg -Tag @{}
Set-AzureRmResourceGroup -Name $devrg -Tag $tags
Get-AzResource -ResourceGroupName $devrg | select-object ResourceID | Update-AzTag -Tag $tags -Operation Replace -Verbose

#Ciberseguridad
$segrg = "NetworkWatcherRG"
$tags = @{“app”=”ciberseguridad”; “env”=”prod”}
Set-AzureRmResourceGroup -Name $segrg -Tag @{}
Set-AzureRmResourceGroup -Name $segrg -Tag $tags
Get-AzResource -ResourceGroupName $segrg | select-object ResourceID | Update-AzTag -Tag $tags -Operation Replace -Verbose

#CentroDeDatos
$cdrg = "DUOMFAEUS2RGPROD01"
$tags = @{“app”=”centrodedatos”; “env”=”prod”}
Set-AzureRmResourceGroup -Name $cdrg -Tag @{}
Set-AzureRmResourceGroup -Name $cdrg -Tag $tags
Get-AzResource -ResourceGroupName $cdrg | select-object ResourceID | Update-AzTag -Tag $tags -Operation Replace -Verbose

#endregion

#Recursos sin TAGS, usualmente las extensiones no se le pueden asignar tags
Get-AzResource `
    | Where-Object {$null -eq $_.Tags -or $_.Tags.Count -eq 0} `
    | Format-Table -AutoSize 
#

Get-AzResource -ResourceGroupName rg-mira-dev-use2 | Select-Object Name,ResourceGroupName,ResourceType,Location,Tags,ResourceID,SubscriptionID | out-file C:\powershell\output\miradev.txt

$rg = Get-AzResourceGroup | Select-Object -ExpandProperty resourcegroupname | Sort-Object resourcegroupname

Get-AzVM -ResourceGroupName CanalPanamaRG01 -Status | ft -AutoSize
Get-AzVM -ResourceGroupName GEOEVEUS2RGTRN -Status | ft -AutoSize
Get-AzVM -ResourceGroupName INNOVAEUS2RG01 -Status | ft -AutoSize


#region Windows Virtual Desktops
Get-AzVM -ResourceGroupName rg-wvd-prod-eus2 -Status | ft -AutoSize
Enter-PSSession azr-vdi-0 -Credential pancanal\paulichen
Enter-PSSession azr-tdf-pa-0 -Credential pancanal\paulichen
Enter-PSSession azr-tdf-pa-1 -Credential pancanal\paulichen
Exit-PSSession

#Arreglo del timezone
Set-TimeZone -Id "SA Pacific Standard Time" -PassThru
Get-Timezone
#endregion

Disconnect-AzAccount