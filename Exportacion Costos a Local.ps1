Get-AzConsumptionUsageDetail | Export-Csv -Path "C:\Temp\Logs\AzureCosts_produc2.csv" -NoTypeInformation

Get-AzConsumptionUsageDetail | ConvertTo-Json | Out-File -FilePath "C:\Temp\Logs\AzureCosts.json"


Get-AzConsumptionUsageDetail -StartDate "2025-05-01" -EndDate "2025-05-05" | Export-Csv -Path "C:\Temp\Logs\AzureCosts_May.csv" -NoTypeInformation




#Para todas las Subscriptciones

# Obtener todas las suscripciones en la cuenta de Azure
$subscriptions = Get-AzSubscription

# Iterar sobre cada suscripción y exportar los detalles de consumo
foreach ($sub in $subscriptions) {
    Select-AzSubscription -SubscriptionId $sub.Id
    Get-AzConsumptionUsageDetail | Export-Csv -Path $("C:\Temp\Logs\AzureCosts_" + $sub.Name + "_" + (Get-Date -Format "yyyyddMM_HHmmtt") + ".csv") -NoTypeInformation
}
