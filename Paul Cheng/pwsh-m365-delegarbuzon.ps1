<#
	.NOTES
	===========================================================================
	 Created with: 	Powershell
	 Created on:   	Marzo 2024
	 Created by:   	Paul Chen
	 Organization: 	Autoridad del Canal de Panama
	 Filename:      \\alderaan\Powershell\Scripts\Workspaces\MIRA\pwsh-m365-delegarbuzon.ps1
	===========================================================================
	.DESCRIPTION
        Script para asignar delegados a un buzon de ExchangeOnline
        Necesita los modulos ExchangeOnline
    .REFERENCES

    .CHANGES
        20240315 - V1.0


Descripción:
El script se conecta a Exchange Online con credenciales de administrador, valida la existencia del buzón al que se van a delegar permisos y verifica si los usuarios a los que se les delegarán permisos también existen. Luego, delega los permisos FullAccess y SendAs a los usuarios especificados en el buzón dado. Finalmente, muestra los permisos delegados en forma tabular.

Algoritmo:

1. Parámetros y variables:
    - Se establecen las variables $cuenta_admin, $buzon_para_delegar y $delegados con los valores pertinentes.
    - Se valida que los correos electrónicos en $delegados tengan un formato válido.

2. Conexión a Exchange Online:
    - Se intenta conectar a Exchange Online utilizando Connect-ExchangeOnline con la cuenta de administrador especificada. Se maneja cualquier error que pueda ocurrir.

3. Validación de buzón para delegar:
    - Se verifica si el buzón especificado en $buzon_para_delegar existe utilizando Get-Recipient.
    - Si existe, se muestra un mensaje indicando su existencia. Si no existe, se muestra un mensaje de advertencia y se termina el script.

4. Validación de usuarios a delegar:
    - Se itera a través de cada usuario especificado en $delegados.
    - Para cada usuario, se verifica su existencia utilizando Get-Recipient.
    - Si existe, se muestra un mensaje indicando su existencia. Si no existe, se muestra un mensaje de advertencia y se termina el script.

5. Delegación de permisos:
    - Se itera a través de cada usuario en $usuariosDelegados.
    - Para cada usuario, se intenta agregar permisos FullAccess al buzón especificado utilizando Add-MailboxPermission.
    - Cualquier error que ocurra durante este proceso se maneja y se muestra un mensaje indicando el error.

6. Verificación de permisos:
    - Se obtienen los permisos delegados en el buzón utilizando Get-MailboxPermission y Get-RecipientPermission.
    - Los resultados se formatean en tablas y se muestran.

7. Eliminación de permisos (opcional):
    - Se define una función Remove-AllPermissions para eliminar permisos FullAccess y SendAs de los delegados especificados.
    - Se llama a la función con los delegados y el buzón como parámetros.

8. Finalización:
    - Se desconecta de Exchange Online utilizando Disconnect-ExchangeOnline.
    - Se muestra un mensaje indicando la finalización del script.
#>

Clear-Host
#region Parametros
$cuenta_admin = "paulichen@pancanal.com"
$buzon_para_delegar = "fio-notificacion@pancanal.com"
# Importar los delegados desde un archivo de texto
$delegados = Get-Content -Path "\\alderaan\Powershell\Input\delegados.txt" 
# Validar que todos los delegados tengan el formato de correo electrónico
foreach ($delegado in $delegados) {
    Write-Host  "Validando formato de correo electrónico para $delegado..." -ForegroundColor Green
    if ($delegado -notmatch '^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$') {
        Write-Host "El delegado '$delegado' no tiene un formato de correo electrónico válido, terminando script..." -ForegroundColor Red
        Exit
    }
}
#endregion

# Conectar a Exchange Online
Connect-ExchangeOnline -UserPrincipalName $cuenta_admin -ErrorAction Stop
 
#region Proceso
# Definir el buzon a delegar y validar que existe
Write-Host "Validando buzón para delegar permisos..." -ForegroundColor Green
if (Get-Recipient -Identity $buzon_para_delegar) {
    Write-Host "El buzon $buzon_para_delegar existe"
}
else { 
    Write-Host "El buzon $buzon_para_delegar no existe, terminando script..." -ForegroundColor Yellow
    Exit
}
$buzonDestino = $buzon_para_delegar

Write-Host "Lista de delegados actuales:" 
Get-Recipient -Identity $buzon_para_delegar | Get-MailboxPermission | Format-Table -AutoSize
  
# Validar que lista de usuarios para delegar existe
Write-Host "Validando usuarios para delegar permisos..." -ForegroundColor Green
foreach ($delegado in $delegados) {
    $result = Get-Recipient -Identity $delegado -ErrorAction SilentlyContinue
    if ($result) {
        Write-Output "$delegado existe"
    }
    else {
        Write-Output "$delegado no existe, terminando script..."
        Exit
    }
}
$usuariosDelegados = $delegados
    
# Procesar cada usuario 
Write-Host
foreach ($usuarioDelegado in $usuariosDelegados) {
    try {
        # Agregar los permisos FullAccess y SendAS
            
        Write-Host "Agregando permisos a $usuarioDelegado..." -ForegroundColor Green
        Add-MailboxPermission -Identity $buzonDestino -User $usuarioDelegado -AccessRights FullAccess -InheritanceType All -ErrorAction Stop
        Add-RecipientPermission -Identity $buzonDestino -AccessRights SendAs -Trustee $usuarioDelegado -Confirm:$false -ErrorAction Stop
        Write-Host "Permisos delegados a $usuarioDelegado correctamente."
    }
    catch {
        Write-Host "Error al delegar permisos a $usuarioDelegado $_"
    }

}
#endregion

#region Verificacion de permisos
# Verificar los permisos delegados
Get-MailboxPermission   -Identity $buzonDestino    | Format-Table -AutoSize
Get-RecipientPermission -Identity $buzonDestino    | Format-Table -AutoSize
#endregion

#region Eliminar permisos de los delegados
<#
function Remove-AllPermissions {
    param (
        [string]$Mailbox,
        [array]$Delegates
    )

    foreach ($delegate in $Delegates) {
        try {
            # Eliminar permisos FullAccess
            Remove-MailboxPermission -Identity $Mailbox -User $delegate -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop
            Write-Host "Permiso FullAccess eliminado para $delegate."

            # Eliminar permisos SendAs
            Remove-RecipientPermission -Identity $Mailbox -Trustee $delegate -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            Write-Host "Permiso SendAs eliminado para $delegate."

            Remove-MailboxPermission -Identity $Mailbox -User $delegate -AccessRights ReadPermission -Confirm:$false

        }
        catch {
            Write-Host "Error al eliminar permisos para $delegate $_" -ForegroundColor Red
        }
    }
}
#endregion

# Llamar a la función para eliminar permisos
Remove-AllPermissions -Mailbox $buzonDestino -Delegates "alaguerra@pancanal.com", "JMarinas@pancanal.com", "Irodriguez@pancanal.com"
#>

Disconnect-ExchangeOnline -Confirm:$false
Write-Host "Finito..." -ForegroundColor Yellow