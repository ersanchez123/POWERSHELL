#https://gist.github.com/jorgeasaurus/011fbbe0bef8804b66cd4d155109c38e

function Get-PSModuleUpdates {
    param
    (
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [string]$Name,

        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [version]$Version,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Repository = 'PSGallery',

        [switch]$OutdatedOnly
    )
    
    process {
        try {
            $latestVersion = [version](Find-Module -Name $Name -Repository $Repository -ErrorAction Stop).Version
            $needsUpdate = $latestVersion -gt $Version
        } catch {
            Write-Warning "Error finding module $Name in repository $($Repository): $_"
            return
        }

        if ($needsUpdate -or -not $OutdatedOnly) {
            [PSCustomObject]@{
                ModuleName     = $Name
                CurrentVersion = $Version
                LatestVersion  = $latestVersion
                NeedsUpdate    = $needsUpdate
                Repository     = $Repository
            }
        }
    }
}

$Modules = Get-InstalledModule | Sort-Object Name | Get-PSModuleUpdates -OutdatedOnly
$Modules | Format-Table
$Modules | Export-Csv -Path "\\alderaan\Powershell\Output\ActualizarModulos.csv"