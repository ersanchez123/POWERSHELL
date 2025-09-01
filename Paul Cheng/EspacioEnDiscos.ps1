

<#
	.NOTES
	===========================================================================
	 Created with: 	Powershell
	 Created on:   	Abril 2019
	 Created by:   	Paul Chen
	 Organization: 	Autoridad del Canal de Panama
	 Filename:      C:\Users\paulchen\GitPowershell\powershell\WindowsManagement\EspacioEnDiscos.ps1
	===========================================================================
	.DESCRIPTION
        Script para determinar los espacios en discos fijos (3) via WMI.
        Queda probar con CMI, pero no es soportado en los equipos viejos
        .REFERENCES
        https://devblogs.microsoft.com/scripting/hey-scripting-guy-can-windows-powershell-call-wmi-methods/
        https://www.petri.com/checking-system-drive-free-space-with-wmi-and-powershell

#>

Clear-Host
$Credenciales = Get-Credential -Message "Credenciales Administrativas para ejectuar la tarea: "
#
# Para obtene la lista de computadoras a inspeccionar, se puede utilizar un archivo txt con los nombre de los equipos
# Get-AdComputer permite obtener todos los objetos computadoras de un OU del Active Directory
#
Get-AdComputer -SearchBase 'OU=Corporativos,OU=Servidores,DC=canal,Dc=acp' -Filter * | Select-Object -ExpandProperty name | Sort-Object name -CaseSensitive | Out-File C:\Powershell\Input\Servidores.txt
$Computers = Get-Content C:\Powershell\Input\Servidores.txt
$Computers = $Computers | Sort-Object
#
# Inicialización de arreglo de salida
#
$Output = @()
$SinComunicacion = @()
# Empieza el loop
Foreach ($Computer in $Computers) {
    # Validar conectividad por ping
    $ping = Test-Connection -ComputerName $Computer -Count 1 -Quiet
    Write-Host 'Prueba de comunicacion con '$Computer    
    # Si responde a ping, intentar obtener los datos con las credenciales provistas.    
    if ($ping ) {
        $Output += Get-WmiObject Win32_Volume -Filter "DriveType = '3'" -ComputerName $Computer  -Credential $Credenciales -ErrorAction SilentlyContinue| ForEach-Object {
            #
            # Creación de objeto que tendrá la información de los equipos y discos.
            #
            [PSCustomObject]@{
                Computer     = $Computer
                DriveLetter  = $_.DriveLetter
                TotalSizeGB  = ([Math]::Round($_.Capacity / 1GB, 2)) -as [float]
                UsedSpaceGB  = (([Math]::Round($_.Capacity / 1GB, 2)) - ([Math]::Round($_.FreeSpace / 1GB, 2))) -as [float]
                FreeSpaceGB  = ([Math]::Round($_.FreeSpace / 1GB, 2)) -as [float]
                "FreeSpace%" = ([Math]::Round($_.FreeSpace / $_.Capacity * 100, 2)) -as [float] 
            }       
        }
    }
    else { Write-Host "$Computer no responde..."
           $SinComunicacion += $Computer
    }
}
#
# Salida en pantalla
#
$Output |  Out-GridView
$SinComunicacion | Out-GridView
#
# Salida en csv y html
#
$Output | Export-Csv -NoTypeInformation -Path C:\Powershell\Exit\DiskSpace3.csv
$SinComunicacion | Export-Csv -NoTypeInformation -Path C:\Powershell\Exit\SinComunicacion.csv
Import-Csv C:\Powershell\Exit\DiskSpace3.csv | ConvertTo-Html -Fragment | Out-File  C:\Powershell\Exit\DiskSpace3.html