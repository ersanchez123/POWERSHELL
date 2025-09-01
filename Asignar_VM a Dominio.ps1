#region funciones
# Funcion de logging
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
 
    Write-Output $logEntry
    Add-Content -Path $LogPath -Value $logEntry
}
#endregion
 
#region configuracion
# Variables predefinidas
$Domain = "canal.acp"
$OUPath = "OU=SYSCLOUD,OU=PROD,OU=Corporativos,OU=SERVIDORES,DC=canal,DC=acp"
$LogPath = "C:\Logs\join-domain.log"
 
# Solicitar credenciales
$DomainAdmin = Get-Credential -Message "Formato pancanal\admin"
 
# Crear carpeta de logs si no existe
$logDir = Split-Path $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
#endregion
 
#region proceso
Write-Log "==== Inicio del proceso de union al dominio ===="
 
# Verificar si ya está unido al dominio
$ComputerDomain = (Get-WmiObject Win32_ComputerSystem).Domain
if ($ComputerDomain -eq $Domain) {
    Write-Log "Este equipo ya pertenece al dominio $Domain" -Level "WARN"
    exit
}
 
# Comprobar resolucion DNS del dominio
if (-not (Resolve-DnsName $Domain -ErrorAction SilentlyContinue)) {
    Write-Log "No se pudo resolver el dominio $Domain. Verifique DNS." -Level "ERROR"
    exit 1
}
Write-Log "Resolucion DNS de $Domain exitosa."
 
# Ajustar zona horaria
try {
    Set-TimeZone -Id "SA Pacific Standard Time" -PassThru | Out-Null
    Write-Log "Zona horaria configurada correctamente."
}
catch {
    Write-Log "Error al configurar zona horaria: $_" -Level "ERROR"
}
 
# Desactivar solo firewall de dominio
try {
    Set-NetFirewallProfile -Profile Domain -Enabled False
    Write-Log "Perfil de firewall de dominio desactivado temporalmente."
}
catch {
    Write-Log "Error al modificar configuracion de firewall: $_" -Level "ERROR"
}
 
# Intentar union al dominio
try {
    Add-Computer -DomainName $Domain `
        -Credential $DomainAdmin `
        -OUPath $OUPath `
        -Force `
        -Restart
    Write-Log "Join al dominio exitosa. Reiniciando equipo..."
}
catch {
    Write-Log "Error al unir al dominio: $_" -Level "ERROR"
    exit 1
}
#endregion