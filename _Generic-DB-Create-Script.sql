
declare @DBName varchar(200) = '--DB--'
declare @Collation varchar(200) = '--Collation--'
declare @FileGroups varchar(max) = '--FileGroups--'

declare @primaryFile nvarchar(max) = CAST(serverproperty('InstanceDefaultDataPath') AS VARCHAR(MAX)) + @DBName + '_Primary.mdf'
declare @defaultFileGroupPath nvarchar(max) = CAST(serverproperty('InstanceDefaultDataPath') AS VARCHAR(MAX)) + @DBName + '_'
declare @memoryFile nvarchar(max) = CAST(serverproperty('InstanceDefaultDataPath') AS VARCHAR(MAX)) + @DBName + '_MemOpt'
declare @logFile  nvarchar(max) = CAST(serverproperty('InstanceDefaultLogPath') AS VARCHAR(MAX)) + @DBName + '_Log.ldf'


declare @sql nvarchar(max) = 
'
USE [master];


DROP DATABASE IF EXISTS @DBName;

CREATE DATABASE @DBName
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = @DBName, FILENAME = ''@primaryFile'', SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB ), 
 FILEGROUP [MemOpt] CONTAINS MEMORY_OPTIMIZED_DATA  DEFAULT
( NAME = N''MemOpt'', FILENAME = ''@memoryFile'' , MAXSIZE = UNLIMITED)
 LOG ON 
( NAME = N''Log'', FILENAME = ''@logFile'' , SIZE = 73728KB , MAXSIZE = UNLIMITED , FILEGROWTH = 65536KB )
COLLATE @Collation;
'

set @sql = @sql;
set @sql = REPLACE(@sql, '@dbname', @dbname)
set @sql = REPLACE(@sql, '@Collation', @Collation)
set @sql = REPLACE(@sql, '@memoryFile',@memoryFile)
set @sql = REPLACE(@sql, '@primaryFile', @primaryFile)
set @sql = REPLACE(@sql, '@defaultFileGroupPath', @defaultFileGroupPath)
set @sql = REPLACE(@sql, '@logFile', @logFile)

exec sp_executesql @sql




SET @FileGroups = RTRIM(LTRIM(@FileGroups))

IF (@FileGroups != '')
BEGIN 
	DECLARE @FileGroupsSQL NVARCHAR(MAX) = ''
	SELECT @FileGroupsSQL = STRING_AGG(
	('ALTER DATABASE @DBName ADD FILEGROUP [' + value + '];
	  ALTER DATABASE @DBName ADD FILE (FILENAME = ''@defaultFileGroupPath' + value + '.ndf'', NAME = ' + value + '_FILE, SIZE = 20MB, MAXSIZE = 200MB, FILEGROWTH = 100MB) TO FILEGROUP [' + value + '];
	'), '')
	FROM string_split(@FileGroups,' ')


	set @sql = @FileGroupsSQL
	set @sql = REPLACE(@sql, '@dbname', @dbname)
	set @sql = REPLACE(@sql, '@Collation', @Collation)
	set @sql = REPLACE(@sql, '@memoryFile',@memoryFile)
	set @sql = REPLACE(@sql, '@primaryFile', @primaryFile)
	set @sql = REPLACE(@sql, '@defaultFileGroupPath', @defaultFileGroupPath)
	set @sql = REPLACE(@sql, '@logFile', @logFile)

	exec sp_executesql @sql

END


set @sql =
'
ALTER DATABASE @DBName SET COMPATIBILITY_LEVEL = 140;
USE @DBName
IF (1 = FULLTEXTSERVICEPROPERTY(''IsFullTextInstalled''))
begin
EXEC [dbo].[sp_fulltext_database] @action = ''enable''
end;
ALTER DATABASE @DBName SET ANSI_NULL_DEFAULT OFF;
ALTER DATABASE @DBName SET ANSI_NULLS OFF;
ALTER DATABASE @DBName SET ANSI_PADDING OFF ;
ALTER DATABASE @DBName SET ANSI_WARNINGS OFF ;
ALTER DATABASE @DBName SET ARITHABORT OFF ;
ALTER DATABASE @DBName SET AUTO_CLOSE OFF ;
ALTER DATABASE @DBName SET AUTO_SHRINK OFF ;
ALTER DATABASE @DBName SET AUTO_UPDATE_STATISTICS ON ;
ALTER DATABASE @DBName SET CURSOR_CLOSE_ON_COMMIT OFF ;
ALTER DATABASE @DBName SET CURSOR_DEFAULT  GLOBAL ;
ALTER DATABASE @DBName SET CONCAT_NULL_YIELDS_NULL OFF ;
ALTER DATABASE @DBName SET NUMERIC_ROUNDABORT OFF ;
ALTER DATABASE @DBName SET QUOTED_IDENTIFIER OFF ;
ALTER DATABASE @DBName SET RECURSIVE_TRIGGERS OFF ;
ALTER DATABASE @DBName SET  DISABLE_BROKER ;
ALTER DATABASE @DBName SET AUTO_UPDATE_STATISTICS_ASYNC OFF ;
ALTER DATABASE @DBName SET DATE_CORRELATION_OPTIMIZATION OFF ;
ALTER DATABASE @DBName SET TRUSTWORTHY OFF ;
ALTER DATABASE @DBName SET ALLOW_SNAPSHOT_ISOLATION OFF ;
ALTER DATABASE @DBName SET PARAMETERIZATION SIMPLE ;
ALTER DATABASE @DBName SET READ_COMMITTED_SNAPSHOT OFF ;
ALTER DATABASE @DBName SET HONOR_BROKER_PRIORITY OFF ;
ALTER DATABASE @DBName SET RECOVERY SIMPLE ;
ALTER DATABASE @DBName SET  MULTI_USER ;
ALTER DATABASE @DBName SET PAGE_VERIFY CHECKSUM  ;
ALTER DATABASE @DBName SET DB_CHAINING OFF ;
ALTER DATABASE @DBName SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) ;
ALTER DATABASE @DBName SET TARGET_RECOVERY_TIME = 60 SECONDS ;
ALTER DATABASE @DBName SET DELAYED_DURABILITY = DISABLED ;
ALTER DATABASE @DBName SET QUERY_STORE = OFF;
ALTER DATABASE @DBName SET  READ_WRITE ;'

set @sql = REPLACE(@sql, '@dbname', @dbname)
exec sp_executesql @sql

GO


