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
--drop table dbo.tmp_wb_na

/* data for now in text format, to ommit possible types excpetions connected with input data */
CREATE TABLE dbo.tmp_wb_na
(	numer nvarchar(20) NOT NULL
,	data_utw nvarchar(10) NOT NULL /* date in format RRRR.MM.DD or DD.MM.RRRR */
,   numer_rach nvarchar(28) NOT NULL -- TODO: Change to IBAN
,	waluta_rach nvarchar(3) NOT NULL
,	data_od nvarchar(10) NOT NULL
,	data_do nvarchar(10) NOT NULL
,	saldo_poc nvarchar(20) NOT NULL
,	saldo_kon nvarchar(20) NOT NULL
)
GO
--SELECT * FROM tmp_wb_na
exec rmv_table @tab_name = 'tmp_wb_poz'  -- is it necessary because ssis deletes tables before importing data??
GO
CREATE TABLE dbo.tmp_wb_poz
(	numer nvarchar(20) NOT NULL
,	data nvarchar(10) NOT NULL /* date in format RRRR.MM.DD or DD.MM.RRRR */
,	kwota nvarchar(20) NOT NULL
,	saldo_po nvarchar(20) NOT NULL
,	opis nvarchar(256) NOT NULL /* from this dane_odbiorcy will be created */
)
GO

-- create table with additional data neede for jpk but not provided in headers or positions
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'PODMIOT'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE dbo.Podmiot 
	(	PODMIOT_ID	nchar(4) NOT NULL CONSTRAINT PK_Podmiot PRIMARY KEY
	,	KodUrzedu	nvarchar(3) NOT NULL
	,	NIP			nvarchar(10) NOT NULL
	,	REGON		nvarchar(9) NOT NULL
	,	KodKraju	nvarchar(40) NOT NULL 
	,	Wojewodztwo nvarchar(40) NOT NULL 
	,	Powiat		nvarchar(40) NOT NULL 
	,	Gmina		nvarchar(40) NOT NULL 
	,	Ulica		nvarchar(40) NOT NULL
	,	NrDomu		nvarchar(10) NOT NULL
	,	NrLokalu	nvarchar(40) NOT NULL
	,	Miejscowosc nvarchar(40) NOT NULL 
	,	KodPocztowy nchar(6) NOT NULL
	,	Poczta		nvarchar(40) NOT NULL
	)
END
GO
-- fill table PODMIOT with test data
IF NOT EXISTS ( SELECT 1 FROM Podmiot )
BEGIN
INSERT INTO dbo.Podmiot 
(
    PODMIOT_ID, 
    KodUrzedu, 
    NIP, 
    REGON, 
    KodKraju, 
    Wojewodztwo, 
    Powiat, 
    Gmina, 
    Ulica, 
    NrDomu, 
    NrLokalu, 
    Miejscowosc, 
    KodPocztowy, 
    Poczta
)
VALUES
(
    '0001', 
    '026', 
    '1234567890', 
    '012345678', 
    'Polska', 
    'Mazowieckie', 
    'warszawski', 
    'Warszawa', 
    'Marszałkowska', 
    '100', 
    '12A', 
    'Warszawa', 
    '00-001', 
    'Warszawa'
)
INSERT INTO dbo.Podmiot 
(
    PODMIOT_ID, 
    KodUrzedu, 
    NIP, 
    REGON, 
    KodKraju, 
    Wojewodztwo, 
    Powiat, 
    Gmina, 
    Ulica, 
    NrDomu, 
    NrLokalu, 
    Miejscowosc, 
    KodPocztowy, 
    Poczta
)
VALUES
(
    '0002', 
    '026', 
    '0987654321', 
    '876543210', 
    'Polska', 
    'Mazowieckie', 
    'warszawski',
    'Warszawa', 
    'Krakowskie Przedmieście', 
    '50', 
    '5B', 
    'Warszawa', 
    '00-002',
    'Warszawa' 
)


END

--data validation for tmp_na
CREATE PROCEDURE dbo.tmp_na_check
AS
--parameter number must be unique for every row because it identifies bank statement in db
	DECLARE @totalRows int, @uniqueNum int 

	SELECT @totalRows = COUNT(*) FROM tmp_wb_na
	
	SELECT @uniqueNum = COUNT(DISTINCT numer) FROM tmp_wb_na
	
	IF @uniqueNum < @totalRows 
	BEGIN
		RAISERROR(N'Parameter numer must be unique for every row', 16, 6)
		RETURN -1
	END
-- start date must be before end date
	DECLARE @InvalidDatesCount int 

	SELECT @InvalidDatesCount = COUNT(*)
	FROM tmp_wb_na
	WHERE data_do < data_od

	IF @InvalidDatesCount > 0
	BEGIN
		RAISERROR(N'Parameter data_od must be a date before parameter data_do', 16, 6)
		RETURN -1
	END
-- creation date must be before start date

	SELECT @InvalidDatesCount = COUNT(*)
	FROM tmp_wb_na
	WHERE data_od < data_utw

	IF @InvalidDatesCount > 0
	BEGIN
		RAISERROR(N'Paramter data_utw must be a date before data_od', 16, 6)
		RETURN -1
	END
--every date must be after current date

	DECLARE @date_max nchar(8)
	SET @date_max = CONVERT(nchar(6), GETDATE(), 112) -- rok i mies z dzis

	IF EXISTS ( SELECT 1 FROM tmp_wb_na t WHERE t.data_utw >= @date_max 
	OR t.data_od >= @date_max
    OR t.data_do >= @date_max 
	)
	BEGIN
		RAISERROR(N'Every date must be before current date', 16, 6)
		RETURN -1
	END

-- TODO: data validation for tmp_poz

GO