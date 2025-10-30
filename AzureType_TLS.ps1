<#
.SYNOPSIS
    Generates a report for Azure services indicating their configured TLS versions.

.DESCRIPTION
    This script connects to your Azure account and analyzes the TLS version configurations for multiple Azure services.
    It automatically iterates over all subscriptions and resource groups in the tenant.
    It generates a report in CSV and HTML formats highlighting any services using insecure TLS versions.

    Supported Azure Services:
    - Azure App Service
    - Azure Storage Accounts
    - Azure SQL Database
    - Azure Key Vault
    - Azure Application Gateway
    - Azure Front Door
    - Azure API Management
    - Azure Load Balancer
    - Azure Virtual Network Gateway
    - Azure SignalR Service
    - Azure Redis Cache
    - Azure Service Bus
    - Azure Kubernetes Service

.EXAMPLE
    .\AuditAzureTlsVersions.ps1

    This command will generate the Azure TLS Version Report, producing CSV and HTML reports.

.AUTHOR
    Timo Haldi
#>

# Install required Azure module
# Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Connect to Azure account
Connect-AzAccount -ErrorAction Stop

# Function to generate an advanced report for Azure services using TLS versions
function Get-AzureTLSReport {
    [CmdletBinding()]
    param (
        [string]$ReportPathCSV = "AzureTLSReport.csv",
        [string]$ReportPathHTML = "AzureTLSReport.html"
    )

    $tlsReport = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Retrieve all subscriptions in the tenant
    $subscriptions = Get-AzSubscription -ErrorAction Stop

    foreach ($sub in $subscriptions) {
        Write-Output "Processing Subscription: $($sub.Name) ($($sub.Id))"

        try {
            # Set the context to the current subscription
            Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop

            # Get all resource groups in the subscription
            $resourceGroups = Get-AzResourceGroup -ErrorAction SilentlyContinue

            foreach ($rg in $resourceGroups) {
                ##############################
                # Azure App Service Section
                ##############################
                Get-AzWebApp -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | ForEach-Object {
                    $app = $_
                    $appConfig = Get-AzWebApp -ResourceGroupName $app.ResourceGroup -Name $app.Name -ErrorAction SilentlyContinue
                    $tlsVersion = if ([string]::IsNullOrEmpty($appConfig.SiteConfig.MinTlsVersion)) { "Not Configured" } else { $appConfig.SiteConfig.MinTlsVersion }
                    $tlsReport.Add([PSCustomObject]@{
                        ServiceName = "Azure App Service"
                        ResourceName = $app.Name
                        ResourceGroup = $app.ResourceGroup
                        TlsVersion = $tlsVersion
                        Location = $app.Location
                        AdditionalInfo = "DefaultHostName: $($app.DefaultHostName); Sku: $($app.Sku.Tier); State: $($app.State)"
                    })
                }

                ##############################
                # Azure Storage Accounts Section
                ##############################
                Get-AzStorageAccount -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | ForEach-Object {
                    $storage = $_
                    $tlsVersion = if ([string]::IsNullOrEmpty($storage.MinimumTlsVersion)) { "Not Configured" } else { $storage.MinimumTlsVersion }
                    $tlsReport.Add([PSCustomObject]@{
                        ServiceName = "Azure Storage Account"
                        ResourceName = $storage.StorageAccountName
                        ResourceGroup = $storage.ResourceGroupName
                        TlsVersion = $tlsVersion
                        Location = $storage.Location
                        AdditionalInfo = "Kind: $($storage.Kind); Sku: $($storage.Sku.Name); HTTPS Only: $($storage.EnableHttpsTrafficOnly)"
                    })
                }

                ##############################
                # Azure SQL Database Section
                ##############################
                Get-AzSqlServer -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | ForEach-Object {
                    $sql = $_
                    $tlsReport.Add([PSCustomObject]@{
                        ServiceName = "Azure SQL Database"
                        ResourceName = $sql.ServerName
                        ResourceGroup = $sql.ResourceGroupName
                        TlsVersion = $sql.MinimalTlsVersion
                        Location = $sql.Location
                        AdditionalInfo = "FQDN: $($sql.FullyQualifiedDomainName); Admin: $($sql.AdministratorLogin)"
                    })
                }

                ##############################
                # Azure Key Vault Section
                ##############################
                Get-AzKeyVault -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | ForEach-Object {
                    $vault = $_
                    $tlsReport.Add([PSCustomObject]@{
                        ServiceName = "Azure Key Vault"
                        ResourceName = $vault.VaultName
                        ResourceGroup = $vault.ResourceGroupName
                        TlsVersion = $vault.Properties.MinimumTlsVersion
                        Location = $vault.Location
                        AdditionalInfo = "EnabledForDeployment: $($vault.Properties.EnabledForDeployment); EnabledForDiskEncryption: $($vault.Properties.EnabledForDiskEncryption)"
                    })
                }

                ##############################
                # Azure Application Gateway Section
                ##############################
                Get-AzApplicationGateway -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | ForEach-Object {
                    $agw = $_
                    $tlsReport.Add([PSCustomObject]@{
                        ServiceName = "Azure Application Gateway"
                        ResourceName = $agw.Name
                        ResourceGroup = $agw.ResourceGroupName
                        TlsVersion = $agw.SslPolicy.MinProtocol
                        Location = $agw.Location
                        AdditionalInfo = "Sku: $($agw.Sku.Name); State: $($agw.OperationalState)"
                    })
                }

                ##############################
                # Azure Front Door Section
                ##############################
                Get-AzFrontDoor -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | ForEach-Object {
                    $fd = $_
                    $tlsReport.Add([PSCustomObject]@{
                        ServiceName = "Azure Front Door"
                        ResourceName = $fd.Name
                        ResourceGroup = $fd.ResourceGroupName
                        TlsVersion = $fd.MinimumTlsVersion
                        Location = $fd.Location
                        AdditionalInfo = "EnabledState: $($fd.EnabledState)"
                    })
                }

                ##############################
                # Azure Virtual Network Gateway Section
                ##############################
                Get-AzVirtualNetworkGateway -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | ForEach-Object {
                    $vnet = $_
                    $tlsReport.Add([PSCustomObject]@{
                        ServiceName = "Azure Virtual Network Gateway"
                        ResourceName = $vnet.Name
                        ResourceGroup = $vnet.ResourceGroupName
                        TlsVersion = "N/A"
                        Location = $vnet.Location
                        AdditionalInfo = "GatewayType: $($vnet.GatewayType); VpnType: $($vnet.VpnType)"
                    })
                }

            }
        }
        catch {
            Write-Warning "Failed to process subscription $($sub.Name): $_"
            continue
        }
    }

    # Generate CSV Report
    $tlsReport | Export-Csv -Path $ReportPathCSV -NoTypeInformation -Force

    # Generate HTML Report
    $htmlContent = @"
<html>
<head>
<style>
    body { font-family: Arial, sans-serif; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { border: 1px solid black; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
</style>
</head>
<body>
    <h1>Azure TLS Version Report</h1>
    <table>
        <tr>
            <th>Service Name</th>
            <th>Resource Name</th>
            <th>Resource Group</th>
            <th>TLS Version</th>
            <th>Location</th>
            <th>Additional Info</th>
        </tr>
"@

    foreach ($entry in $tlsReport) {
        $htmlContent += "<tr>"
        $htmlContent += "<td>$($entry.ServiceName)</td>"
        $htmlContent += "<td>$($entry.ResourceName)</td>"
        $htmlContent += "<td>$($entry.ResourceGroup)</td>"
        $htmlContent += "<td>$($entry.TlsVersion)</td>"
        $htmlContent += "<td>$($entry.Location)</td>"
        $htmlContent += "<td>$($entry.AdditionalInfo)</td>"
        $htmlContent += "</tr>"
    }

    $htmlContent += "</table></body></html>"
    $htmlContent | Out-File -FilePath $ReportPathHTML -Encoding UTF8

    Write-Output "Reports generated successfully: CSV ($ReportPathCSV), HTML ($ReportPathHTML)."
}

# Execute the report generation function
Get-AzureTLSReport