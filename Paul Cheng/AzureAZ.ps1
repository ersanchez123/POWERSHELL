Connect-AzAccount 

$acpsubs = Get-AzSubscription | Select-Object name,id,State

Get-AzRoleDefinition | Select-Object Name, Description | export-csv \\ossus\Powershell\Output\AzureRoles.csv

Set-AzContext -Subscription "ACPDATACENTER"
 
Get-AzRoleAssignment | Select-Object DisplayName, RoleDefinitionName | Sort-Object RoleDefinitionName | export-csv \\ossus\Powershell\Output\ACPDATACENTER.csv -NoTypeInformation