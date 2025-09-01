# Fix-AzModules.ps1
# Este script desinstala todos los módulos Az.* y AzureRM.*, luego instala Az.Accounts versión 2.12.1

Write-Host "Desinstalando módulos Az y AzureRM..." -ForegroundColor Yellow
Get-InstalledModule -Name Az* -ErrorAction SilentlyContinue | Uninstall-Module -AllVersions -Force
Get-InstalledModule -Name AzureRM* -ErrorAction SilentlyContinue | Uninstall-Module -AllVersions -Force

Write-Host "Instalando Az.Accounts versión 2.12.1..." -ForegroundColor Yellow
Install-Module -Name Az.Accounts -RequiredVersion 2.12.1 -Force -AllowClobber

Write-Host "`nMódulo instalado:" -ForegroundColor Green
Get-InstalledModule -Name Az.Accounts

Write-Host "`nReinicia PowerShell antes de ejecutar Connect-AzAccount." -ForegroundColor Cyan
