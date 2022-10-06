[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo');
[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Management.Sdk.Sfc');
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMOExtended")

Start-Transcript -Path "$($scriptPath)\Logs\$($databaseName)_Log.txt"
new-item -Path "$($scriptPath)\SqlOutput-$($databaseName)" -itemtype directory

Write-Host "Connecting to $databaseName";
Write-Host "Parameter scriptPath " $scriptPath 
Write-Host "Parameter destinationServerName " $destinationServerName 
Write-Host "Parameter fileWithCreationScript " $fileWithCreationScript 
Write-Host "Parameter destinationDBPrefix "$destinationDBPrefix 
Write-Host "Parameter serverName " $serverName 
Write-Host "Parameter username " $username 
Write-Host "Parameter password *****"  
Write-Host "Parameter databaseName " $databaseName 
Write-Host "Parameter databaseOutputName " $outputDBName
Write-Host "Parameter schemaFileName " $schemaFileName 
Write-Host "Parameter dataFileName " $dataFileName 
Write-Host "Parameter tablesToInclude " $tablesToInclude
Write-Host "Parameter bcpTables " $bcpTables 
Write-Host "Parameter bcpIdentity " $bcpIdentity
Write-Host "Parameter reenableFKs " $reenableFKs
Write-Host "Parameter isNTuser " $isNTuser

$schemaFileName = $outputDBName + "-schema.sql"
$dataFileName = $outputDBName + "-data.sql"


#Check if _Generic-DB-Create-Script.sql exist
if((Test-Path $fileWithCreationScript) -ne $True)
{
    $Error | select * | Out-File -FilePath "$($scriptPath)\genericlogs_$($outputDBName).txt"
    throw "_Generic-DB-Create-Script.sql not found"
}

#Auth 
if($isNTuser -eq $true)
{
    $myAuth = new-object Microsoft.SqlServer.Management.Common.ServerConnection
    $myAuth.LoginSecure = $true
    $myAuth.ConnectAsUser = $true
    $myAuth.ConnectAsUserName = $username
    $myAuth.ApplicationIntent = "ReadOnly"
    $myAuth.ConnectAsUserPassword = $password
    $myAuth.TrustServerCertificate = $true
    $myAuth.ServerInstance=$serverName
}
else {
    $myAuth = new-object Microsoft.SqlServer.Management.Common.ServerConnection
    $myAuth.LoginSecure = $false
    $myAuth.LoginSecure = $false
    $myAuth.ConnectAsUser = $false
    $myAuth.Login = $username    
    $myAuth.ApplicationIntent = "ReadOnly"
    $myAuth.Password = $password
    $myAuth.TrustServerCertificate = $false
    $myAuth.ServerInstance=$serverName
}


Write-Host "MyAuth Obj with: $($myAuth)"
Write-Host "connection with: $($serverName)"
$sqlServer = new-object Microsoft.SqlServer.Management.SMO.Server($myAuth)

Write-Host "SQL INSTANCE DETAILS AFTER CONNECTION"
Write-Host $sqlServer.Databases
$sqlDb = $sqlServer.Databases[$databasename]
Write-Host "SQL DB -> $($sqlDb)"
$collation = $sqlDb.Collation;
$destinationDBName = $destinationDBPrefix + $outputDBName
$fileGroups = "";

foreach ($f in $sqlDb.FileGroups)
{
    if (($f.FileGroupType -eq 0) -and ($f.Name -ne "PRIMARY"))
    {
        $fileGroups = $fileGroups + " " + $f.Name
    }
}


$options = new-object Microsoft.SqlServer.Management.Smo.ScriptingOptions
$options.ExtendedProperties = $true
$options.AppendToFile = $true
$options.DRIAll = $true
$options.ScriptOwner = $false
$options.Permissions = $false
$options.Indexes = $true
$options.Triggers = $true
$options.ScriptBatchTerminator = $true
$options.Filename = $scriptPath + "\SqlOutput-$($databaseName)\" + $schemaFileName + ".tmp"
$options.IncludeHeaders = $true
$options.ToFileOnly = $true
$options.ContinueScriptingOnError = $true;


Write-Host "Scripting database schema...";

$errorhandler=
{
    param([object]$sender, [Microsoft.SqlServer.Management.Smo.ScriptingErrorEventArgs]$args)
	write-host $args.Current.Value; 
};

$progresshandler=
{
    param([object]$sender, [Microsoft.SqlServer.Management.Smo.ProgressReportEventArgs]$args2)
	write-host "Scripting Progress: "  $args2.TotalCount " of " $args2.Total "(" $args2.Current. ")"; 

};

$discoveryhandler=
{
    param([object]$sender, [Microsoft.SqlServer.Management.Smo.ProgressReportEventArgs]$args3)
	write-host "Discovery Progress: "  $args3.TotalCount " of " $args3.Total; 
};


$transfer = new-object Microsoft.SqlServer.Management.Smo.Transfer($sqlDb)
$transfer.CopyAllUsers = $false
$transfer.CopyAllLogins = $false
$transfer.CopyAllViews = $true
$transfer.CopyAllSequences = $true
$transfer.DestinationDatabase              = $destinationDBName


$transfer.options = $options
$transfer.add_ScriptingError($errorhandler);
$transfer.add_DiscoveryProgress($discoveryhandler);

#Use the progress handler only if you are debugging
#$transfer.add_ScriptingProgress($progresshandler);

try{
    $transfer.ScriptTransfer();
}
catch
{
    $Error | select * | Out-File -FilePath "$($scriptPath)\schemalogs_$($databaseName).txt"
    throw "Error trying to do Script transfer"
}


#Write-Host $Error

# Schema is done! Add the create db part and remove the users.

$newSchemafile = $scriptPath + "\SqlOutput-$($databaseName)\" + $schemaFileName 

((((Get-Content -path $fileWithCreationScript -Raw) -replace '--collation--',$collation) -replace '--DB--', $destinationDBName) -replace '--FileGroups--', $fileGroups) | Set-Content -Path $newSchemafile

Add-Content $newSchemafile "USE [$destinationDBName]"

Get-Content $options.Filename | Where { $_ -notmatch "^CREATE USER" } | Add-Content $newSchemafile
Remove-Item –path $options.Filename -ErrorAction Ignore

Write-Host "Database schema scripting complete.";

if ($tablesToInclude -eq "")
{
    Write-Host "No tables included. No data file will be written.";   
}
else{
    $Objects = $sqlDb.Tables

    $dataFile = $scriptPath + "\SqlOutput-$($databaseName)\" + $dataFileName;

    Remove-Item –path $dataFile -ErrorAction Ignore
    New-Item $dataFile -type file -force

    #before starting disable all check constraints!

    $disableChecks = "EXEC sp_msforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT all'"
    $dropDDLTrigger = "DROP  TRIGGER IF EXISTS [DDLTrigger] ON DATABASE"
    $identifier = "SET QUOTED_IDENTIFIER ON"
    $ansi = "SET ANSI_NULLS ON"
    $go = "GO"
    $use = "USE [$destinationDBName]"

    $use >> $dataFile
    $identifier >> $dataFile
    $go >> $dataFile
    $ansi >> $dataFile
    $go >> $dataFile
    $dropDDLTrigger >> $dataFile
    $go >> $dataFile
    $disableChecks >> $dataFile
    $go >> $dataFile


    # NORMAL SCRIPTER #
    foreach ($t in $tablesToInclude.Split(','))
    {
        $search = $t | Select-String -Pattern '^[\[]?([\w_\.]*)[\]]?\.[\[]?([\w_\.]*)[\]]?$';
        $tableSchema = $search.Matches.Groups[1].ToString();
        $tableName = $search.Matches.Groups[2].ToString();

        $info = "Currently writing " + $tableSchema + "." + $tableName
        Write-Host $info

        $scriptr = new-object Microsoft.SqlServer.Management.Smo.Scripter($sqlServer)
        $scriptr.Options.AppendToFile = $True
        $scriptr.Options.AllowSystemObjects = $False
        $scriptr.Options.ScriptData = $True
        $scriptr.Options.ToFileOnly = $True
        $scriptr.Options.ScriptSchema = $False
        $scriptr.Options.Indexes = $True
        $scriptr.Options.FileName = $dataFile
        
        
        $tb = $sqlDb.Tables | Where {($_.Schema -eq $tableSchema ) -and ($_.Name -eq $tableName)}

        
        try{
            $scriptr.EnumScript($tb)
            Write-host $tb
        }
        catch
        {
            $Error | select * | Out-File -FilePath "$($scriptPath)\datalogs_$($databaseName).txt"
            Write-Host "$($Error)"
            throw "Error trying to do Script Enum"
        }    
    }
}

# BCP Scripter #
if($bcpTables -ne "")
{
    foreach ($bcpt in $bcpTables.Split(','))
    {

        $search = $bcpt | Select-String -Pattern '^[\[]?([\w_\.]*)[\]]?\.[\[]?([\w_\.]*)[\]]?$';
        $tableSchema = $search.Matches.Groups[1].ToString();
        $tableName = $search.Matches.Groups[2].ToString();

        ## BCP SCRIPTER ##
        try{
            #Create bcp files
            New-Item -Path "$($scriptPath)\$($sqlDb.Name)\$($tableSchema).$($tableName).bcp" -Force
            
            #$command =  "bcp" + "$($tableSchema).$($bcpt)" + "OUT" + "$($scriptPath)\$($tableSchema).$($bcpt).bcp" + "-S" + $serverName + "-T -d"  + $sqlDb.Name + "-n"
            #$command | out-file -FilePath "$($scriptPath)\command.txt"
            
            #Populate bcp File
            $time = Get-Date -Format "MM/dd/yyyy HH:mm"
            Write-Host "-- $($time) -- Scripting $($tableSchema).$($tableName) --"
            bcp "[$($tableSchema)].[$($tableName)]" OUT "$($scriptPath)\$($sqlDb.Name)\$($tableSchema).$($tableName).bcp" -S $serverName -T -d $sqlDb.Name -n -K ReadOnly -l 60
        }
        catch
        {
            $Error | select * | Out-File -FilePath "$($scriptPath)\bcplogs_$($databaseName).txt"
            throw "Error trying to do bcp"
            Write-Host "$($Error)"
        }

    }
}


# BCP Scripter Identity #
if($bcpIdentity -ne "")
{
    foreach ($bcpt in $bcpIdentity.Split(','))
    {
        $search = $bcpt | Select-String -Pattern '^[\[]?([\w_\.]*)[\]]?\.[\[]?([\w_\.]*)[\]]?$';
        $tableSchema = $search.Matches.Groups[1].ToString();
        $tableName = $search.Matches.Groups[2].ToString();

        WRITE-HOST $tablename


        ## BCP SCRIPTER ##
        try{
            #Create bcp files
            New-Item -Path "$($scriptPath)\$($sqlDb.Name)\$($tableSchema).$($tableName).Identity.bcp" -Force
            
            #$command =  "bcp" + "$($tableSchema).$($bcpt)" + "OUT" + "$($scriptPath)\$($tableSchema).$($bcpt).bcp" + "-S" + $serverName + "-T -d"  + $sqlDb.Name + "-n"
            #$command | out-file -FilePath "$($scriptPath)\command.txt"
            
            #Populate bcp File
            $time = Get-Date -Format "MM/dd/yyyy HH:mm"
            Write-Host "-- $($time) -- Scripting $($tableSchema).$($tableName) --"
            bcp "[$($tableSchema)].[$($tableName)]" OUT "$($scriptPath)\$($sqlDb.Name)\$($tableSchema).$($tableName).Identity.bcp" -S $serverName -T -d $sqlDb.Name -n -K ReadOnly -E -l 60
        }
        catch
        {
            $Error | select * | Out-File -FilePath "$($scriptPath)\bcplogs_$($databaseName).txt"
            throw "Error trying to do bcp"
            Write-Host "$($Error)"
        }

    }
}

 
#Re-enabled FK (if we want to)

if ($reenableFKs = $true)
{
    $enableChecks = "EXEC sp_msforeachtable ""ALTER TABLE ?  WITH CHECK CHECK CONSTRAINT all"""
    $go = "GO"

    $go >> $dataFile
    $enableChecks >> $dataFile
    $go >> $dataFile
}

Write-Host "Data file written.";

Stop-Transcript
exit