$logPath = "C:\Temp\Logs\Actualizar-Chrome.log"
New-Item -ItemType Directory -Path (Split-Path $logPath) -Force | Out-Null
$fecha = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
function Log { param($msg) "$fecha - $msg" | Out-File -FilePath $logPath -Append }
 
# Verificar si Chrome está instalado
$chromePath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" -ErrorAction SilentlyContinue)."(Default)"
if (-not $chromePath -or -not (Test-Path $chromePath)) {
    Log "Chrome no está instalado. No se realiza ninguna acción."
    exit
}
 
# Version actual de Chrome
$versionActual = (Get-Item $chromePath).VersionInfo.ProductVersion
Log "Versión actual de Chrome: $versionActual"
 
# Obtener la última versión estable de Chrome desde la API de Google
$url = "https://versionhistory.googleapis.com/v1/chrome/platforms/win64/channels/stable/versions"
$response = Invoke-RestMethod -Uri $url -UseBasicParsing
$ultimaVersion = $response.versions[0].version
 
# Actualizar Chrome si la versión instalada es menor que la última versión
if ($versionActual -lt $ultimaVersion) {
    Log "Actualizando Chrome de $versionActual a $ultimaVersion..."
    $instPath = "$env:TEMP\chrome.msi"
    $url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
    try {
        Invoke-WebRequest -Uri $url -OutFile $instPath -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i `"$instPath`" /qn /norestart" -Wait
        Log "Chrome actualizado correctamente."
    } catch {
        Log "Error al instalar Chrome: $_"
    }
} else {
    Log "Chrome ya está actualizado."
}