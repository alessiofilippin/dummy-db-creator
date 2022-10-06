# For debugging purposes, you should not run in parallel.
$runParallel = $true

# This class defines all the settings needed to script a particular database.
Class DBJob 
{
    # Static properties mean that we keep these settings the same for all dbs.
    [String]$scriptPath = (Split-Path $script:MyInvocation.MyCommand.Path);
    [String]$destinationServerName = "";
    [String]$fileWithCreationScript = (Split-Path $script:MyInvocation.MyCommand.Path) + "\_Generic-DB-Create-Script.sql";
    [String]$destinationDBPrefix = "Dummy_";

    # this is what changes per db.
    [String]$serverName;
    [String]$databaseName;
    [String]$username;
    [String]$password;
    [Bool]$isNTuser;
    [String]$outputDBName;
    [String]$tablesToInclude;
    [String]$bcpTables;
	[String]$bcpIdentity;
    [Bool]$reenableFKs;
};


# now we define settings for each db.

#TEMPLATE
# DB Definition.
#$dbAuth = New-Object DBJob;
#$dbAuth.serverName = "serverIP,Port" or "serverhost"
#$dbAuth.databaseName = "DatabaseNameInput"
#$dbAuth.outputDBName = "DatabaseNameOutput";
#$dbAuth.tablesToInclude = "[master].[table1],[master].[table2]";
#$dbAuth.bcpTables = "[master].[table3],[master].[table4]";
#$dbAuth.bcpIdentity = "";
#$dbAuth.reenableFKs = $true

# test config
$testAdminDB = New-Object DBJob;
$testAdminDB.serverName = "alef********.database.windows.net,1433";
$testAdminDB.databaseName = "AdminDB";
$testAdminDB.outputDBName = "AdminDBScripted";
$testAdminDB.password = "**********";
$testAdminDB.username = "**********";
$testAdminDB.isNTuser = $false;
$testAdminDB.tablesToInclude = "[dbo].[test]";
$testAdminDB.bcpTables = "[dbo].[test]";
$testAdminDB.bcpIdentity = "";
$testAdminDB.reenableFKs = $true;



# This is the list of dbs that are going to be scripted.
# $allDBs = $db1, $db2, db3
$allDBs = $testAdminDB

# This is the script blocked that will be executed in parallel.
$scriptPerDB = 
{
    param($dbObj) 

    Write-Host "DB Found for scripting: " $dbObj.databaseName;

    $scriptPath = $dbObj.scriptPath;

    $databaseName = $dbObj.databaseName;
    $scriptPath = $dbObj.scriptPath 
    $destinationServerName = $dbObj.destinationServerName 
    $fileWithCreationScript = $dbObj.fileWithCreationScript 
    $destinationDBPrefix = $dbObj.destinationDBPrefix 
    $serverName = $dbObj.serverName 
    $username = $dbObj.username 
    $password = $dbObj.password 
    $isNTuser = $dbObj.isNTuser
    $databaseName = $dbObj.databaseName 
    $outputDBName = $dbObj.outputDBName 
    $schemaFileName = $dbObj.schemaFileName 
    $dataFileName = $dbObj.dataFileName 
    $tablesToInclude = $dbObj.tablesToInclude 
    $bcpTables = $dbObj.bcpTables
	$bcpIdentity = $dbObj.bcpIdentity
    $reenableFKs = $dbObj.reenableFKs
    $scriptRaptorTestUsers = $dbObj.scriptRaptorTestUsers


    & "$scriptPath\_DBScripter.ps1" -scriptPath $scriptPath -destinationServerName $destinationServerName -fileWithCreationScript $fileWithCreationScript -destinationDBPrefix $destinationDBPrefix -serverName $serverName -databaseName $databaseName -tablesToInclude $tablesToInclude -bcpTables $bcpTables -bcpIdentity $bcpIdentity -reenableFKs $reenableFKs -scriptRaptorTestUsers $scriptRaptorTestUsers -outputDBName  $outputDBName

    
}

if ($runParallel -eq $true)
{
    Write-Host "Running in parallel"

    $allJobs = @()
    $StartTime = Get-Date -DisplayHint Time

    foreach ($db in $allDBs)
    {
        $allJobs += Start-ThreadJob -ScriptBlock $scriptPerDB -ArgumentList $db -Name "Scripting-$($db.databaseName)"
    }

    # Check job status
    $allJobs | Get-Job
    $exit = $False
    do{
        $jobStatus = $allJobs | Get-Job
        write-host "Check in progress..."
        foreach($job in $jobStatus)
        {
            if($job.State -ne 'Running')
            {$exit = $True}
            else {
                $exit = $False
                write-host "Threads still running..."
                break
            }
        }
        Start-Sleep -Seconds 10

        if($StartTime.AddMinutes(50) -le (Get-Date -DisplayHint Time))
        {
            $exit = $True
            $time = Get-Date -Format "MM/dd/yyyy HH:mm"
            Write-Host "Exit for timeout... $($time)"
        }

    } while ($exit -eq $False)

    $allJobs | Get-Job
    $allJobs | Stop-Job

}
else
{
    Write-Host "Not running in parallel"

    foreach ($db in $allDBs)
    {
       Invoke-Command -ScriptBlock $scriptPerDB -ArgumentList $db
    }

}