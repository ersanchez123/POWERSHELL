
<#
	.NOTES
	===========================================================================
	 Created with: 	Powershell
	 Created on:   	Octubre 2024
	 Created by:   	Paul Chen
	 Organization: 	Autoridad del Canal de Panama
	 Filename:      M365-DelegadosEnUnBuzon.ps1
	===========================================================================
	.DESCRIPTION
        Script para listar delegados a un buzon de ExchangeOnline
        Necesita los modulos ExchangeOnline
#>

Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-ExchangeOnline -UserPrincipalName ernoisanchez@pancanal.com -ShowProgress $true -ErrorAction Stop

$Buzon = "ACP-Empleos@pancanal.com"
$FullAccess = Get-MailboxPermission -Identity $Buzon | Where-Object { $_.AccessRights -eq "FullAccess" } | Select-Object User, AccessRights
$SendAS = Get-RecipientPermission -Identity $Buzon | Where-Object { $_.Trustee -ne $null -and $_.AccessRights -eq "SendAs" } | Select-Object Trustee, AccessRights
$SendOnBehalf = (Get-Mailbox -Identity $Buzon).GrantSendOnBehalfTo | ForEach-Object { Get-Recipient $_ } | Select-Object Name

Write-Output "Full Access"
$FullAccess
Write-Output "SendAS"
$SendAS
Write-Output "SendOnBehalf"
$SendOnBehalf

<# Documentación del Script

Propósito:
Este script de PowerShell se utiliza para recuperar y mostrar los permisos de un buzón  en Exchange Online, específicamente los permisos de acceso completo (Full Access), enviar como (SendAs), y enviar en nombre de (SendOnBehalf).

Módulos y Conexión:
- Import-Module ExchangeOnlineManagement: Importa el módulo de administración de Exchange Online para interactuar con la configuración y permisos de los buzones.
- Connect-ExchangeOnline: Conecta a Exchange Online usando un User Principal Name (UPN).

Variables y Procesos:
- $SharedMailbox: Define el buzón compartido cuyo nombre es buzon@pancanal.com.
- $FullAccess: Recoge los usuarios que tienen permisos completos sobre el buzón compartido mediante Get-MailboxPermission y filtra aquellos que tienen el derecho de "FullAccess".
- $SendAS: Recoge los usuarios que tienen permisos de enviar correos electrónicos como si fueran el buzón compartido (SendAs) usando Get-RecipientPermission.
- $SendOnBehalf: Obtiene la lista de usuarios que pueden enviar correos electrónicos en nombre del buzón compartido mediante GrantSendOnBehalfTo y Get-Recipient.

Salida:
El script imprime los permisos en tres secciones:
1. Full Access: Muestra los usuarios con permisos completos sobre el buzón.
2. SendAS: Muestra los usuarios con permisos para enviar correos como el buzón compartido.
3. SendOnBehalf: Muestra los usuarios que pueden enviar correos en nombre del buzón.

#>