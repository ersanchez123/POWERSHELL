<#
.SYNOPSIS
Obtiene el inventario de software instalado de uno o varios equipos Windows.

.DESCRIPTION
Lee de forma local o remota las claves de desinstalación del Registro (32/64 bits)
para listar aplicaciones instaladas. Permite incluir actualizaciones (updates/hotfixes),
omitir el ping previo y exportar los resultados a Excel (módulo ImportExcel) o CSV
si el módulo no está disponible.

.PARAMETER ComputerName
Nombre(s) del equipo destino. Acepta múltiples valores y entrada por pipeline.
Por defecto usa el nombre del equipo actual.

.PARAMETER SkipPing
Omite la verificación de conectividad ICMP (Test-Connection). Útil cuando el ping
está bloqueado pero el Registro remoto es accesible.

.PARAMETER IncludeUpdates
Incluye elementos normalmente filtrados como Updates, Security Updates, Service Packs,
HotFix y Rollups. Alias: -IncludeUpdate.

.PARAMETER ExportExcelPath
Ruta del archivo .xlsx a generar con Export-Excel (módulo ImportExcel). Si el módulo
no está instalado, se exporta un CSV con el mismo nombre.

.PARAMETER WorksheetName
Nombre de la hoja de cálculo a usar al exportar a Excel. Por defecto 'SoftwareInventory'.

.OUTPUTS
System.Software.Inventory

.EXAMPLE
get-remote-software -ComputerName localhost -SkipPing | Format-Table DisplayName, Version
Obtiene el inventario local sin hacer ping, mostrando nombre y versión.

.EXAMPLE
get-remote-software -ComputerName 'srv01','srv02' -SkipPing -IncludeUpdates \
  -ExportExcelPath 'C:\Inventarios\software.xlsx' -WorksheetName 'Servidores'
Consulta dos servidores, incluye actualizaciones y exporta a Excel.

.EXAMPLE
'srv01','srv02' | get-remote-software -SkipPing | Out-GridView
Usa entrada por pipeline con dos equipos y muestra los resultados en una grilla.

.NOTES
- Para equipos remotos, debe estar accesible el servicio RemoteRegistry (o ejecutar
  con credenciales/permisos adecuados).
- La exportación a Excel requiere el módulo ImportExcel (Export-Excel). Si no está
  instalado, se generará un archivo CSV de respaldo con el mismo nombre.
- Algunas claves pueden no tener Fecha de instalación o Tamaño estimado.

.NOTES
Paul Chen Charter
Noviembre 2025
#>

Import-Module Import-Excel -ErrorAction SilentlyContinue
Function get-remote-software {
  [OutputType('System.Software.Inventory')]
  [CmdletBinding()]
  Param(
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [switch]$SkipPing,
    [Alias('IncludeUpdate')][switch]$IncludeUpdates,

    [string]$ExportExcelPath,
    [string]$WorksheetName = 'SoftwareInventory'
  )

  Begin {
    $results = [System.Collections.Generic.List[object]]::new()
  }

  Process {
    foreach ($Computer in $ComputerName) {
      if ($SkipPing -or (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
        $paths = @(
          'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
          'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        )
        try {
          $isLocal = @('localhost', '127.0.0.1', $env:COMPUTERNAME, '.') -contains $Computer
          if ($isLocal) {
            $reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64')
          }
          else {
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer, 'Registry64')
          }
        }
        catch {
          Write-Error $_
          continue
        }

        foreach ($path in $paths) {
          Write-Verbose "Checking Path: $path"
          try {
            $regkey = $reg.OpenSubKey($path)
            if (-not $regkey) { continue }
            $subkeys = $regkey.GetSubKeyNames()
          }
          catch {
            Write-Warning "$($Computer): Error abriendo $path - $_"
            continue
          }

          foreach ($key in $subkeys) {
            $thisKey = "$path\$key"
            try {
              $thisSubKey = $reg.OpenSubKey($thisKey)
              $displayName = $thisSubKey.GetValue('DisplayName')
              if (-not $displayName) { continue }
              if (-not $IncludeUpdates) {
                if ($displayName -match '^Update\s+for|^Security Update|^Service Pack|^HotFix|Rollup') { continue }
              }

              $date = $thisSubKey.GetValue('InstallDate')
              if ($date) {
                try { $date = [datetime]::ParseExact($date, 'yyyyMMdd', $null) } catch { $date = $null }
              }

              $publisher = $null
              try { $publisher = $thisSubKey.GetValue('Publisher').Trim() } catch { $publisher = $thisSubKey.GetValue('Publisher') }

              $version = $null
              try { $version = $thisSubKey.GetValue('DisplayVersion').TrimEnd(([char[]](32, 0))) } catch { $version = $thisSubKey.GetValue('DisplayVersion') }

              $uninstallString = $null
              try { $uninstallString = $thisSubKey.GetValue('UninstallString').Trim() } catch { $uninstallString = $thisSubKey.GetValue('UninstallString') }

              $installLocation = $null
              try { $installLocation = $thisSubKey.GetValue('InstallLocation').Trim() } catch { $installLocation = $thisSubKey.GetValue('InstallLocation') }

              $installSource = $null
              try { $installSource = $thisSubKey.GetValue('InstallSource').Trim() } catch { $installSource = $thisSubKey.GetValue('InstallSource') }

              $helpLink = $null
              try { $helpLink = $thisSubKey.GetValue('HelpLink').Trim() } catch { $helpLink = $thisSubKey.GetValue('HelpLink') }

              $sizeMB = $null
              $sizeRaw = $thisSubKey.GetValue('EstimatedSize')
              if ($sizeRaw -as [int]) { $sizeMB = [decimal]([math]::Round(($sizeRaw * 1024) / 1MB, 2)) }

              $obj = [pscustomobject]@{
                ComputerName     = $Computer
                DisplayName      = $displayName
                Version          = $version
                InstallDate      = $date
                Publisher        = $publisher
                UninstallString  = $uninstallString
                InstallLocation  = $installLocation
                InstallSource    = $installSource
                HelpLink         = $helpLink
                EstimatedSizeMB  = $sizeMB
              }
              $obj.pstypenames.Insert(0, 'System.Software.Inventory')
              [void]$results.Add($obj)
              Write-Output $obj
            }
            catch {
              Write-Warning "$key : $_"
            }
          }
        }

        # Si se solicita, incluir tambin los HotFix/Updates del sistema (Win32_QuickFixEngineering)
        if ($IncludeUpdates) {
          try {
            $qfes = Get-CimInstance -ClassName Win32_QuickFixEngineering -ComputerName $Computer -ErrorAction Stop
            foreach ($qfe in $qfes) {
              $installedOn = $null
              $io = $qfe.InstalledOn
              if ($io) {
                try {
                  if ($io -is [datetime]) { $installedOn = $io } else { $installedOn = [datetime]::Parse($io) }
                }
                catch { $installedOn = $null }
              }

              $obj = [pscustomobject]@{
                ComputerName     = $Computer
                DisplayName      = "HotFix $($qfe.HotFixID): $($qfe.Description)"
                Version          = $null
                InstallDate      = $installedOn
                Publisher        = 'Microsoft Corporation'
                UninstallString  = $null
                InstallLocation  = $null
                InstallSource    = $null
                HelpLink         = $qfe.Caption
                EstimatedSizeMB  = $null
              }
              $obj.pstypenames.Insert(0, 'System.Software.Inventory')
              [void]$results.Add($obj)
              Write-Output $obj
            }
          }
          catch {
            Write-Warning "$($Computer): No se pudieron consultar HotFix/Updates (Win32_QuickFixEngineering) - $_"
          }
        }

        $reg.Close()
      }
      else {
        Write-Error "$($Computer): unable to reach remote system!"
      }
    }
  }

  End {
    if ($ExportExcelPath) {
      $exportCmd = Get-Command -Name Export-Excel -ErrorAction SilentlyContinue
      if (-not $exportCmd) {
        Write-Warning 'Export-Excel no está disponible. Instala el módulo ImportExcel: Install-Module ImportExcel'
        try {
          $csvPath = [System.IO.Path]::ChangeExtension($ExportExcelPath, 'csv')
          $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
          Write-Verbose "Inventario exportado como CSV (fallback): $csvPath"
        }
        catch { Write-Error $_ }
      }
      else {
        try {
          $results | Export-Excel -Path $ExportExcelPath -WorksheetName $WorksheetName -AutoSize
          Write-Verbose "Inventario exportado a: $ExportExcelPath (hoja: $WorksheetName)"
        }
        catch { Write-Error $_ }
      }
    }
  }
}
