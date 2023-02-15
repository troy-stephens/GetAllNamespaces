$outputFile = "namespace-report.csv"

# Get list of all clusters across all subscriptions the current user has access to
$clusters = Search-AzGraph -Query @'
resources 
| where type == 'microsoft.containerservice/managedclusters' 
| project subscriptionId, resourceGroup, name
'@

$output = @()

foreach ($cluster in $clusters) {
    # Set current subscription context
    az account set --subscription $cluster.subscriptionId | Out-Null
    
    # Get credentials for the cluster to use with kubectl 
    # NOTE: it will overwrite existing credentials for the cluster
    $aksContext = az aks get-credentials --overwrite-existing --name $cluster.name --resource-group $cluster.resourceGroup | Out-Null
    
    # Get list of namespaces from the current cluster
    # NOTE: "--insecure-skip-tls-verify" was used because the proxy was breaking SSL
    $namespaces = kubectl get namespaces --insecure-skip-tls-verify -o json | ConvertFrom-Json

    # Add each result to the output
    foreach ($namespace in $namespaces.items) {
        $output += [PSCustomObject]@{
            SubscriptionId = $cluster.subscriptionId
            ResourceGroup = $cluster.resourceGroup
            ClusterName = $cluster.name
            Namespace = $namespace.metadata.name
        }
    }
}

# Write the output in csv format
$output | Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "Namespace report generated: $outputFile"