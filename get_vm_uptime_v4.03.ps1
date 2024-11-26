$outputFile = "vms_uptime_info.csv"
$logFile = "error_logging.txt"

# Login to Azure if not already logged in
Connect-AzAccount

# Create an array to hold the VM details
$vmDetails = @()

# Get all subscriptions in the tenant
$subscriptions = Get-AzSubscription

foreach ($subscription in $subscriptions) {
    $subscriptionId = $subscription.Id
    # Set the subscription context
    Set-AzContext -SubscriptionId $subscriptionId
    Write-Host "Processing subscription: $subscriptionId"

    # Get the list of VMs in the subscription
    $vms = Get-AzVM

    foreach ($vm in $vms) {
        $resourceGroup = $vm.ResourceGroupName
        $vmName = $vm.Name
        Write-Host "Processing VM: $vmName"

        try {
            # Check the OS type
            $osType = $vm.StorageProfile.OsDisk.OsType
            if ($osType -eq "Windows") {
                Write-Host "Skipping Windows VM: $vmName"
                continue
            }

            # Get the VM status
            $vmStatus = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Status
            $powerState = $vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' } | Select-Object -ExpandProperty DisplayStatus
            
            # Skip VMs that are not running
            if ($powerState -ne 'VM running') {
                Write-Host "Skipping VM that is not running: $vmName"
                continue
            }

            # Ensure the VM status object has the necessary data
            if ($null -ne $vmStatus.Statuses -and $vmStatus.Statuses.Count -gt 0) {
                # Extract the time property for uptime calculation
                $timeProperty = $vmStatus.Statuses | Where-Object { $_.Code -eq "ProvisioningState/succeeded" } | Select-Object -ExpandProperty Time -ErrorAction SilentlyContinue
                
                if ($timeProperty) {
                    # Calculate uptime
                    $uptime = (Get-Date) - $timeProperty
                    Write-Output "VM Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"

                    # Get tags from the VM
                    $tags = $vm.Tags
                    $environmentType = if ($tags.ContainsKey('TypeOfEnvironment')) { $tags['TypeOfEnvironment'] } else { 'N/A' }
                    $owner = if ($tags.ContainsKey('owner')) { $tags['owner'] } else { 'N/A' }

                    # Add the details to the array
                    $vmDetails += [PSCustomObject]@{
                        Subscription     = $subscriptionId
                        VMName           = $vmName
                        ResourceGroup    = $resourceGroup
                        Uptime           = "$($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
                        EnvironmentType  = $environmentType
                        Owner            = $owner
                    }
                } else {
                    Write-Host "Skipping VM $vmName as the uptime cannot be determined."
                    continue
                }
            } else {
                Write-Host "Skipping VM $vmName as it has no valid statuses."
                continue
            }
        } catch {
            # Log the error details
            $errorMessage = "Skipping VM $vmName in resource group $resourceGroup due to error: $_"
            Write-Output $errorMessage
            Add-Content -Path $logFile -Value $errorMessage
            Add-Content -Path $logFile -Value $_.Exception.ToString()
        }
    }
}

# Export the details to a CSV file
$vmDetails | Export-Csv -Path $outputFile -NoTypeInformation

Write-Output "VM uptimes have been exported to $outputFile"
Write-Output "Errors have been logged to $logFile"