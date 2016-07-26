Function Install-OlaIntegrityCheck
{
<#

#>
	
	[CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential,
		[string]$Path,
		[ValidateSet('CHECKDB', 'CHECKFILEGROUP', 'CHECKTABLE', 'CHECKALLOC', 'CHECKCATALOG', 'CHECKALLOC', 'CHECKCATALOG')]
		[string[]]$CheckCommands,
		[switch]$PhysicalOnly,
		[switch]$NoIndex,
		[switch]$ExtendedLogicalChecks,
		[switch]$TabLock,
		[string]$FileGroups,
		[string]$Objects,
		[int]$LockTimeout,
		[switch]$LogToTable,
		[switch]$OutputOnly
	)
	
	DynamicParam { if ($sqlserver) { return Get-ParamInstallDatabase -SqlServer $sqlserver -SqlCredential $SqlCredential } }
	
	BEGIN
	{
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential -RegularUser
		$source = $sourceserver.DomainInstanceName
		
		$temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\")
		
		switch ($OutputOnly)
		{
			$true { $Execute = $false }
			$false { $Execute = $true }
		}
	
		
		Function Get-OlaMaintenanceSolution
		{
			
			$url = 'https://ola.hallengren.com/scripts/IndexOptimize.sql'
			$sqlfile = "$temp\IndexOptimize.sql"
			
			try
			{
				Invoke-WebRequest $url -OutFile $sqlfile
			}
			catch
			{
				#try with default proxy and usersettings
				(New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
				Invoke-WebRequest $url -OutFile $sqlfile
			}
			
			# Unblock if there's a block
			Unblock-File $sqlfile -ErrorAction SilentlyContinue
			
			return $sqlfile
		}
		
		# Used a dynamic parameter? Convert from RuntimeDefinedParameter object to regular array
		$Database = $psboundparameters.Database
		
		if ($Header -like '*update*')
		{
			$action = "update"
		}
		else
		{
			$action = "install"
		}
		
		$textinfo = (Get-Culture).TextInfo
		$actiontitle = $textinfo.ToTitleCase($action)
		
		if ($action -eq "install")
		{
			$actioning = "installing"
		}
		else
		{
			$actioning = "updating"
		}
		
		
	}
	
	PROCESS
	{
		
		if ($database.length -eq 0)
		{
			$database = Show-SqlDatabaseList -SqlServer $sourceserver -Title "$actiontitle MaintenancePlan" -Header $header -DefaultDb "master"
			
			if ($database.length -eq 0)
			{
				throw "You must select a database to $action the procedure"
			}
			
			if ($database -ne 'master')
			{
				Write-Warning "You have selected a database other than master. When you run Show-SqlWhoIsActive in the future, you must specify -Database $database"
			}
		}
		
		if ($Path.Length -eq 0)
		{
			$sqlfile = "$temp\MaintenanceSolution.sql"
			$path = $file.FullName
			
			if ($path.Length -eq 0 -or $force -eq $true)
			{
				try
				{
					Write-Output "Downloading MaintenancePlan zip file, unzipping and $actioning."
					Get-OlaMaintenanceSolution
				}
				catch
				{
					throw "Couldn't download MaintenancePlan. Please download and $action manually from http://sqlblog.com/files/folders/42453/download.aspx."
				}
			}
			
			$path = (Get-ChildItem "$temp\who*active*.sql" | Select -First 1).Name
			$path = "$temp\$path"
		}
		
		if ((Test-Path $Path) -eq $false)
		{
			throw "Invalid path at $path"
		}
		
		$sql = [IO.File]::ReadAllText($path)
		$sql = $sql -replace 'USE master', ''
		$batches = $sql -split "GO\r\n"
		
		foreach ($batch in $batches)
		{
			try
			{
				$null = $sourceserver.databases[$database].ExecuteNonQuery($batch)
				
			}
			catch
			{
				Write-Exception $_
				throw "Can't $action stored procedure. See exception text for details."
			}
		}
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		
		if ($OutputDatabaseName -eq $true)
		{
			return $database
		}
		else
		{
			Write-Output "Finished $actioning MaintenancePlan in $database on $SqlServer "
		}
	}
}