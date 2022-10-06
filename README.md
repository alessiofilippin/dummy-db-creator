# Dummy DB Scripter

These set of scripts will use powershell and some .NET libraries to script the schema and data of a list of DBs.

This could be helpful if there is a need to create a dummy DB with a subset of data from existing DBs for testing or QA purposes.

Scripts are also easy to integrate in a pipeline workflow to automate the export and import in different locations or target SQL Servers.

## Known Limitations

- Script execution tend to be very long or unpredictable if the data that you are trying to script is very big. Like hundreds of GBs. **However, you shouldn't be using a powershell script to do that ;)**

- Importing to Azure SQL Database is not possible. This is because the output .sql files contain the "USE" directive which it's not supported by Azure SQL. If you wish to import the dummy DBs into Azure SQL, you will need to open each .sql and execute each state separately by targetting different DBs.

- The script will export all the data contained in the tables in the input. This also means any sensitive value. It's up to you to make sure to don't script sensitive tables.

- Stored procedures will not exported. But you can always prepare script to add them automatically when you will be restoring the dummy DBs somewhere.

## Prerequisites

The following things are required on the system which it will execute the scripts:

- [ThreadJob Powershell Package](https://www.powershellgallery.com/packages/ThreadJob/2.0.3) This is required if you wish to enable parallel execution.

- [SqlServer Powershell Module](https://www.powershellgallery.com/packages/SqlServer/21.1.18256) This is **mandatory** as the script make use of some libraries from such module.

- Admin rights to execute the script.

- Either credentials or AD user to login into the target SQL Server.

# How-To-Use

## 1) Add DBs

Open the "_DBScripterManager.ps1" and add one DB definition for each database that you wish to script, as per this example:

```
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
```

and remember to add each database to the main list:

```
$allDBs = $testAdminDB
```

### Triggers:

**isNTuser**: True if you are using an AD user, False if you are using username/password auth.

**outputDBName**: If you want the Output DB to have different name than the source. Change this value.

**tablesToInclude**: List of DB tables to script. These tables will be scripted using line-by-line .sql file.

**bcpTables**: List of DB tables to script. These tables will be scripted using the [bcp utility](https://learn.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver16). This can help if the data in the table is huge.

**bcpIdentity**: Same as bcpTables but this will preserve the column identity. See option "-E" of [bcp utility](https://learn.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver16).

## 2) Review the Generic DB Settings

If you want your DB to be scripted with different magic or flavour. You might review and change **_Generic-DB-Create-Script.sql** changes to this file might break the script.

## 3) Execute

- Open an admin Powershell Session.
- Make sure that "import-module SqlServer" is there.
- Execute **_DBScripterManager.ps1**

# Results

If the script is successful - it will create 3 different type of folders:

- **Logs** = you will find all the transcription of the execution in this folder. Useful to troubleshoot errors or issues with teh execution.

- **SqlOutput-databaseName** = One folder for each Database. It will contain 2 .sql files: one for the schema and one for the data.

- **databaseName** = One folder per each Database. It will contain the result of the bcp scripting, if any. Both Identity and normal.

