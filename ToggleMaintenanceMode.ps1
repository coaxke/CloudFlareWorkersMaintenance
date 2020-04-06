<#
	Calls Cloudflare API to update/query the status of Cloudflare Workers, which provide 
	maintenance mode functionality.
#>

<#===============================================================================================#>

<#
.SYNOPSIS
    Fetches all of the DNS routes for a given Cloudflare Zone ID
.PARAMETER Headers
    HashTable of Requst headers to auth against Cloudflare (API-Key/Email Address)
.PARAMETER zoneID
    Unique Cloudflare ID representing a DNS zone which contains Workers 
#>
function Get-WorkerRoutes(
	[hashtable]$Headers,
	[string]$zoneID) {
	try {		
		$workerRoutes = Invoke-RestMethod -Method Get -Uri "https://api.cloudflare.com/client/v4/zones/$($zoneId)/workers/routes" -Headers $Headers

		if ($workerRoutes.result.count -gt 0) {
			return $workerRoutes.result
		}		
	}
	catch {
		Write-Error $_.Exception.Message
		return $null
	}

	return $null
}


<#
.SYNOPSIS
	Updates and eventually checks the status of a Cloudflare worker for a given route
.PARAMETER workerRoute
	Object which contains the unique ID of the route, the pattern of the rule to be enable (e.g. *subdomain.example.com/*), 
	enabled boolean indicating if the route has been enabled/disabled.
.PARAMETER Headers
    HashTable of Requst headers to auth against Cloudflare (API-Key/Email Address)
.PARAMETER zoneID
	Unique Cloudflare ID representing a DNS zone which contains Workers 
.PARAMETER workerScriptName
	Unique name representing the script of the worker which to enable for a given route. This value is $null if we wish to disable 
	the script on a given route.
#>
function Set-WorkerRouteStatus(
	[PsCustomObject]$workerRoute,	
	[hashtable]$headers,
	[string]$zoneId,
	[object]$workerScriptName) {	
	try {
		#Generate JSON payload + convert to JSON (Setting as a PSCustomObject preserves the order or properties in payload):
		$ApiBody = [pscustomobject]@{
			id      = $workerRoute.Id
			pattern = $workerRoute.Pattern
			script  = $workerScriptName
		} | Convertto-Json		

		#Enable script for the route.
		Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$($zoneId)/workers/routes/$($workerRoute.Id)" `
			-Headers $headers -Body $ApiBody -Method PUT -ContentType 'application/json'

		Write-Host "Set script '$workerScriptName' on worker route '$($workerRoute.Pattern)'."
		
		#We now need to verify that the workerRouteStatus we just set is returned when we query it (double-check)
		#if not, fail the deploy outright - someone needs to investigate what's wrong.
		$CheckRoute = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$($zoneId)/workers/routes/$($workerRoute.Id)" -Headers $headers -Method GET

		if (-not (($CheckRoute.result.script) -eq $workerScriptName)) {
			if ($null -eq $workerScriptName) {
				Write-Error "Attempted to disable CloudFlareRoute '$($workerRoute.Id)' with the pattern '$($workerRoute.Pattern)', however the CloudFlare API
			is not returning the exepected result."
			}
			else {
				Write-Error "Attempted to update CloudFlareRoute '$($workerRoute.Id)' with the pattern '$($workerRoute.Pattern)' and the route '$workerScriptName', however the CloudFlare API
			is not returning the exepected result."				
			}
			
			throw;			
		}
	}
	catch {
		Write-Host "Error updating $($workerRoute.pattern)"
		Write-Error $_.Exception.Message
		throw;
	}
}

##Main:

#Globals vars:
[string]${Maintenance.CfApiKey} = "xxxx123123"
[string]${Maintenance.CfEmail} = "test@example.com"
[string]${Maintenance.CfZoneId} = "zoneID123zoneID123zoneID123zoneID123zoneID123"
[string]${Maintenance.routePattern} = "resdevops.com/*"
[string]${Maintenance.WorkerScriptName} = "some-worker-name"


try {	
	#Assemble CF API Request Auth headers
	$apiRequestHeaders = @{
		'X-Auth-Key'   = ${Maintenance.CfApiKey}
		'X-Auth-Email' = ${Maintenance.CfEmail}
	}


	$allWorkerRoutes = Get-WorkerRoutes -Headers $apiRequestHeaders -zoneID ${Maintenance.CfZoneId}

	if ($allWorkerRoutes -ne $null) {	
		#If we want to toggle multiple different patterns (comma seperated), split them out:
		$allRoutePatterns = (${Maintenance.RoutePattern} -split ",")

		foreach ($routePattern in $allRoutePatterns) {	
			#Its possble the Pattern we pass in could result in multiple Route matches - We'll
			#need to enumerate over them regarless:
			$filteredWorkerRoutes = $allWorkerRoutes | ? { $_.Pattern -eq $routePattern }

			foreach ($filteredWorkerRoute in $filteredWorkerRoutes) {

				Write-Host "Processing $filteredWorkerRoute."
				switch ((${Maintenance.routeAction}).ToLower()) {
					"enable" { Set-WorkerRouteStatus -workerRoute $filteredWorkerRoute -headers $apiRequestHeaders -zoneId ${Maintenance.CfZoneId} -workerScriptName ${Maintenance.WorkerScriptName}; break }
					"disable" { Set-WorkerRouteStatus -workerRoute $filteredWorkerRoute -headers $apiRequestHeaders -zoneId ${Maintenance.CfZoneId} -workerScriptName $null ; break}
					"status" { Write-Host "Route: $($filteredWorkerRoute.pattern), Script value: $($filteredWorkerRoute.script)"; break }
					default { Write-Error "Maintenane routeAction was not an expected value (enable/disable/status)."; break }
				}
			}
		}
		
		Write-Host "Maintenance-mode task complete."
	}
	else {
		Write-Error "No worker routes returned for the zoneID ${Maintenance.CfZoneId}; Please add required routes and re-run the script"
	}
}
catch {
	Write-Error $_
}