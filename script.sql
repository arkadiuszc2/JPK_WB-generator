/* create db */

if not exists (select 1 from master ..sysdatabases d where d.[name] = 'jpkdb')
BEGIN
	EXEC sp_sqlexec N'create database jpkdb'
	PRINT 'Creating new database with name jpkdb'
END
ELSE
BEGIN
	PRINT 'Database named jpkdb already exists'
END

USE jpkdb
GO
-- drop procedure rmv_table
/*create procedure to be able to use alter and not create later*/
/* if we use create we cant run script multiple times without error */
IF NOT EXISTS 
	( SELECT 1 FROM sysobjects o
		WHERE (o.[name] = 'rmv_table')
		AND		(OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
	)
BEGIN
	EXEC sp_sqlExec N'CREATE PROCEDURE dbo.rmv_table AS select 1'
END
GO

ALTER PROCEDURE dbo.rmv_table (@tab_name nvarchar(100) )
/* delete table if already exists
query for test:

create table dbo.test (aa int not null)
exec rmv_table @tab_name = 'test'
select * from test  */

AS	
/* check if obj exists and if its a table */
	IF EXISTS 
	( SELECT 1 FROM sysobjects o
		WHERE (o.[name] = @tab_name)	
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable') = 1)
	)
	BEGIN
		DECLARE @sql nvarchar(1000)
		SET @sql = 'DROP TABLE ' + @tab_name
		EXEC sp_sqlexec @sql
	END
GO
exec rmv_table @tab_name = 'tmp_wb_na'
GO

/* data for now in text format, to ommit possible types excpetions connected with input data */
CREATE TABLE dbo.tmp_wb_na
(	numer nvarchar(20) NOT NULL
,	data_utw nvarchar(10) NOT NULL /* date in format RRRR.MM.DD or DD.MM.RRRR */
,   numer_rach nvarchar(20) NOT NULL
,	waluta_rach nvarchar(3) NOT NULL
,	data_od nvarchar(10) NOT NULL
,	data_do nvarchar(10) NOT NULL
,	saldo_poc nvarchar(20) NOT NULL
,	saldo_kon nvarchar(20) NOT NULL
)

CREATE TABLE dbo.tmp_wb_poz
(	numer nvarchar(20) NOT NULL
,	data nvarchar(10) NOT NULL /* date in format RRRR.MM.DD or DD.MM.RRRR */
,	kwota nvarchar(20) NOT NULL
,	saldo_po nvarchar(20) NOT NULL
,	opis nvarchar(100) NOT NULL /* from this dane_odbiorcy will be created */
)
GO