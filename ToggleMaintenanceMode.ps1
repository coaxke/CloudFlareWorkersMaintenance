<#
	Calls Cloudflare API to update/query the status of Cloudflare Workers, which provide 
	maintenance mode functionality.
#>

<#===============================================================================================#>

<#
.SYNOPSIS
    Fetches all of the DNS filters for a given Cloudflare Zone ID
.PARAMETER Headers
    HashTable of Requst headers to auth against Cloudflare (API-Key/Email Address)
.PARAMETER zoneID
    Unique Cloudflare ID representing a DNS zone which contains Workers 
#>
function Get-WorkerFilters(
[hashtable]$Headers,
[string]$zoneID)
{
	try
	{
		#TODO - Handle API response pagination
		$workerFilters = Invoke-RestMethod -Method Get -Uri "https://api.cloudflare.com/client/v4/zones/$($zoneId)/workers/filters" -Headers $Headers

		if($workerFilters.result.count -gt 0)
		{
			return $workerFilters.result
		}		
	}
	catch
	{
		Write-Error $_.Exception.Message
		return $null
	}

	return $null
}


<#
.SYNOPSIS
	Updates and eventually checks the status of a Cloudflare worker 
.PARAMETER workerFilter
	Object which contains the unique ID of the filter, the pattern of the rule to be enable (e.g. *subdomain.example.com/*), 
	enabled boolean indicating if the filter has been enabled/disabled.
.PARAMETER enableFilter
	boolen indicating if the worker-filter is to be enabled ($true) or disabled ($false)
.PARAMETER Headers
    HashTable of Requst headers to auth against Cloudflare (API-Key/Email Address)
.PARAMETER zoneID
    Unique Cloudflare ID representing a DNS zone which contains Workers 
#>
function Set-WorkerFilterStatus(
[PsCustomObject]$workerFilter,
[bool]$enableFilter,
[hashtable]$headers,
[string]$zoneId)
{	
	try
	{
		#Generate JSON payload + convert to JSON (Setting as a PSCustomObject preserves the order or properties in payload):
		$ApiBody =  [pscustomobject]@{
			id = $workerFilter.Id
			pattern = $workerFilter.Pattern
			enabled = $enableFilter		
		}|Convertto-Json		

		Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$($zoneId)/workers/filters/$($workerFilter.Id)" `
			-Headers $headers -Body $ApiBody -Method PUT -ContentType 'application/json'

		Write-Host "Set $($workerFilter.Pattern) to $enableFilter"		
		
		#We now need to verify that the workerFilterStatus we just set is returned when we query it (double-check)
		#if not, fail the deploy outright - someone needs to investigate whats wrong.
		$CheckFilter = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$($zoneId)/workers/filters/$($workerFilter.Id)" -Headers $headers -Method GET

		if(-not (($CheckFilter.result.enabled) -eq $enableFilter))
		{
			Write-Error "Attempted to update CloudflareFilter $($workerFilter.Id)) with the pattern $($workerFilter.Pattern) and the status of $enableFilterm however, the Cloudflare API
			is not returning the exepected result (Cloudflare result is $($CheckFilter.result.enabled)."
			throw;
		}
	}
	catch
	{
		Write-Host "Error updating $($workerFilter.pattern)"
		Write-Error $_.Exception.Message
		throw;
	}
}

##Main:

#Globals vars:
[string]${Maintenance.CfApiKey} = "xxxx123123"
[string]${Maintenance.CfEmail} = "test@example.com"
[string]${Maintenance.CfZoneId} = "zoneID123zoneID123zoneID123zoneID123zoneID123"
[string]${Maintenance.FilterPattern} = "resdevops.com/*"
[string]${Maintenance.FilterAction} = "enable"


try
{	
	#Assemble CF API Request Auth headers
	$apiRequestHeaders = @{
							'X-Auth-Key' = ${Maintenance.CfApiKey}
							'X-Auth-Email' = ${Maintenance.CfEmail}
						}


	$allWorkerFilters = Get-WorkerFilters -Headers $apiRequestHeaders -zoneID ${Maintenance.CfZoneId}

	if($allWorkerFilters -ne $null)
	{	
		#If we want to toggle multiple different patterns (comma seperated), split them out:
		$allFilterPatterns = (${Maintenance.FilterPattern} -split ",")

		foreach($filterPattern in $allFilterPatterns)
		{	
			#Its possble the Pattern we pass in could result in multiple Route matches - We'll
			#need to enumerate over them regarless:
			$filteredWorkerFilters = $allWorkerFilters | ? {$_.Pattern -eq $filterPattern}

			foreach($filteredWorkerFilter in $filteredWorkerFilters)
			{

				Write-Host "Processing $filteredWorkerFilter."
				switch((${Maintenance.FilterAction}).ToLower())
				{
					"enable" {Set-WorkerFilterStatus -workerFilter $filteredWorkerFilter -enableFilter $true -headers $apiRequestHeaders -zoneId ${Maintenance.CfZoneId}; break}
					"disable" {Set-WorkerFilterStatus -workerFilter $filteredWorkerFilter -enableFilter $false -headers $apiRequestHeaders -zoneId ${Maintenance.CfZoneId}; break}
					"status" {Write-Host "Filter: $($filteredWorkerFilter.Pattern), Enabled: $($filteredWorkerFilter.Enabled)"; break}
					default {Write-Error "Maintenane FilterAction was not an expected value (enable/disable/status)."; break}
				}
			}
		}
		
		Write-Host "Maintenance-mode task complete."
	}
	else
	{
		Write-Error "No worker filters returned for the zoneID ${Maintenance.CfZoneId}; Please add required filters and re-run the script"
	}
}
catch
{
	Write-Error $_
}