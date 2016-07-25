Function Install-olaDatabaseBackup
{
<#
.SYNOPSIS
Automatically installs or updates Ola Hallengren's Maintenance Solution. Wrapper for Install-SqlDatabaseBackup, Install-SqlDatabaseIntegrityCheck and Install-SqlIndexOptimize.

.DESCRIPTION
This command downloads and installs Maintenance Solution, with Ola's permission.
	
To read more about Maintenance Solution, please visit https://ola.hallengren.com
	
.PARAMETER SqlServer
The SQL Server instance.You must have sysadmin access and server version must be SQL Server version 2000 or higher.

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

$scred = Get-Credential, then pass $scred object to the -SqlCredential parameter. 

Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials. To connect as a different Windows user, run PowerShell as that user.

.PARAMETER OutputDatabaseName
Outputs just the database name instead of the success message

.NOTES 
dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbatools.io/Install-olaDatabaseBackup

.EXAMPLE
Install-olaDatabaseBackup -SqlServer sqlserver2014a -Database master

Installs Maintenance Plans to sqlserver2014a's master database. Logs in using Windows Authentication.
	
.EXAMPLE   
Install-olaDatabaseBackup -SqlServer sqlserver2014a -SqlCredential $cred

Pops up a dialog box asking which database on sqlserver2014a you want to install the proc to. Logs into SQL Server using SQL Authentication.

	CreateJobs
	BackupDirectory (do a check)
	CleanupTime
	OutputFileDirectory
	LogToTable
	Database
	JobNameSystemFull = 'DatabaseBackup - SYSTEM_DATABASES - FULL',
	JobNameUserDiff = 'DatabaseBackup - USER_DATABASES - DIFF',
	JobNameUserFull = 'DatabaseBackup - USER_DATABASES - FULL',
	JobNameUserLog =  'DatabaseBackup - USER_DATABASES - LOG',
	JobNameSystemIntegrityCheck = 'DatabaseIntegrityCheck - SYSTEM_DATABASES'
	JobNameUserIntegrityCheck = 'DatabaseIntegrityCheck - USER_DATABASES'
	JobNameUserIndexOptimize = 'IndexOptimize - USER_DATABASES'
	JobNameDeleteBackupHistory = 'sp_delete_backuphistory'
	JobNamePurgeBackupHistory = 'sp_purge_jobhistory'
	JobNameOutputFileCleanup = 'Output File Cleanup'
	JobNameComandLogCleanup =  'CommandLog Cleanup'
	
	FragmentationLevel1 = 30%
	FragmentationLevel2 = 50%
	FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE'
	FragmentationHigh = 'INDEX_REBUILD_ONLINE'
	
#>
	
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential,
		[string]$Databases,
		[string]$Directory,
		[ValidateSet('FULL', 'DIFF', 'LOG')]
		[string]$BackupType,
		[switch]$Verify,
		[Parameter(Mandatory = $true, HelpMessage = "Specify cleanup time in hours. Infinite = 0, 7d = 168, 30d = 720, 60d = 1440, 90d = 2160, 365d = 8760")]
		[int]$CleanupTime,
		[int]$CleanupTimeDays,
		[ValidateSet('AfterBackup', 'BeforeBackup')]
		[string]$CleanupMode = 'AfterBackup',
		[ValidateSet('Default', 'Yes', 'No')]
		[string]$Compress,
		[switch]$CopyOnly,
		[switch]$ChangeBackupType,
		[ValidateSet('Native', 'Litespeed', 'SQLBackup', 'SQLSafe')]
		[string]$BackupSoftware = 'Native',
		[switch]$CheckSum,
		[int]$BlockSize,
		[int]$BufferCount,
		[int]$MaxTransferSize,
		[ValidateLength(0, 64)]
		[int]$NumberOfFiles,
		[ValidateScript({
				switch ($BackupSoftware)
				{
					'Default' { return $false }
					'Litespeed' { $_ -in 0..8 }
					'SQLBackup' { $_ -in 0..4 }
					'SQLSafe' { $_ -in 1..4 }
				}
			})]
		[int]$CompressionLevel,
		[string]$Description,
		[ValidateScript({
				switch ($BackupSoftware)
				{
					'Default' { return $false }
					{ 'Litespeed' -or 'SQLBackup' -or 'SQLSafe' } { $_ -in 1..32 }
				}
			})]
		[int]$Threads,
		[ValidateScript({
				switch ($BackupSoftware)
				{
					'Litespeed' { return $true }
					Default { return $false }
				}
			})]
		[int]$ThrottlePercent,
		[switch]$Encrypt,
		[ValidateSet('RC2_40', 'RC2_56', 'RC2_112', 'RC2_128', 'TRIPLE_DES_3KEY', 'RC4_128', 'AES_128', 'AES_192', 'AES_256')]
		[string]$EncryptionAlgorithm,
		# This needs to be a dynamic param

		[string]$ServerCertificate,
		# This needs to be a dynamic param

		[string]$ServerAsymmetricKey,
		# This needs to be a dynamic param

		[string]$EncryptionKey,
		[switch]$ReadWriteFileGroups,
		[switch]$OverrideBackupPreference,
		[switch]$NoRecovery,
		[string]$URL,
		# This needs to be a dynamic param

		[string]$Credential,
		# validate

		[string]$MirrorDirectory,
		[int]$MirrorCleanupTime,
		[ValidateSet('AfterBackup', 'BeforeBackup')]
		[string]$MirrorCleanupMode = 'AfterBackup',
		[switch]$LogToTable,
		[switch]$OutputOnly
		
		# NULL	SQL Server native backup (the default)
		# LITESPEED	LiteSpeed for SQL Server
		# SQLBACKUP	Red Gate SQL Backup Pro
		# SQLSAFE	Idera SQL Safe Backup
		
		# Set the LiteSpeed for SQL Server, Red Gate SQL Backup Pro, or Idera SQL Safe Backup compression level.
		# In LiteSpeed for SQL Server, the compression levels 0 to 8 are supported. In Red Gate SQL Backup Pro, levels 0 to 4 are supported, and in Idera SQL Safe Backup, levels 1 to 4 are supported.
		# Specify the time, in hours, after which the backup files are deleted. If no time is specified, then no backup files are deleted.
		# DatabaseBackup has a check to verify that transaction log backups that are newer than the most recent full or differential backup are not deleted.
		
	)
	
	DynamicParam { if ($sqlserver) { return Get-ParamInstallDatabase -SqlServer $sqlserver -SqlCredential $SqlCredential } }
	
	BEGIN
	{
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential -RegularUser
		$source = $sourceserver.DomainInstanceName
		
		Function Get-SpWhoIsActive
		{
			
			$url = 'http://sqlblog.com/files/folders/42453/download.aspx'
			$temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\")
			$zipfile = "$temp\spwhoisactive.zip"
			
			try
			{
				Invoke-WebRequest $url -OutFile $zipfile
			}
			catch
			{
				#try with default proxy and usersettings
				(New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
				Invoke-WebRequest $url -OutFile $zipfile
			}
			
			# Unblock if there's a block
			Unblock-File $zipfile -ErrorAction SilentlyContinue
			
			# Keep it backwards compatible
			$shell = New-Object -COM Shell.Application
			$zipPackage = $shell.NameSpace($zipfile)
			$destinationFolder = $shell.NameSpace($temp)
			$destinationFolder.CopyHere($zipPackage.Items())
			
			Remove-Item -Path $zipfile
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
		Write-Warning "hello"
		return
		if ($database.length -eq 0)
		{
			$database = Show-SqlDatabaseList -SqlServer $sourceserver -Title "$actiontitle Maintenance Plans" -Header $header -DefaultDb "master"
			
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
			$temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\")
			$file = Get-ChildItem "$temp\who*active*.sql" | Select -First 1
			$path = $file.FullName
			
			if ($path.Length -eq 0 -or $force -eq $true)
			{
				try
				{
					Write-Output "Downloading Maintenance Plans zip file, unzipping and $actioning."
					Get-SpWhoIsActive
				}
				catch
				{
					throw "Couldn't download Maintenance Plans. Please download and $action manually from http://sqlblog.com/files/folders/42453/download.aspx."
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
			Write-Output "Finished $actioning Maintenance Plans in $database on $SqlServer "
		}
	}
}