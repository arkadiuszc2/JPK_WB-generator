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

--TODO: create temp tables