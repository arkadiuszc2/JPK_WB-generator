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
	,	numer_rach  nvarchar(28) NOT NULL
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
-- create list of currencies codes to validate if provided code is valid
-- it will be only valid if provided code exists in this list
GO
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'currency'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE dbo.currency 
	(	name   NVARCHAR(20)
	,	code   NVARCHAR(3) 
	,	symbol NVARCHAR(5)
	)

	-- Insert currency records
	INSERT INTO currency VALUES ('Leke', 'ALL', N'Lek');
INSERT INTO currency VALUES ('Dollars', 'USD', N'$');
INSERT INTO currency VALUES ('Afghanis', 'AFN', N'؋');
INSERT INTO currency VALUES ('Pesos', 'ARS', N'$');
INSERT INTO currency VALUES ('Guilders', 'AWG', N'ƒ');
INSERT INTO currency VALUES ('Dollars', 'AUD', N'$');
INSERT INTO currency VALUES ('New Manats', 'AZN', N'ман');
INSERT INTO currency VALUES ('Dollars', 'BSD', N'$');
INSERT INTO currency VALUES ('Dollars', 'BBD', N'$');
INSERT INTO currency VALUES ('Rubles', 'BYR', N'p.');
INSERT INTO currency VALUES ('Euro', 'EUR', N'€');
INSERT INTO currency VALUES ('Dollars', 'BZD', N'BZ$');
INSERT INTO currency VALUES ('Dollars', 'BMD', N'$');
INSERT INTO currency VALUES ('Bolivianos', 'BOB', N'$b');
INSERT INTO currency VALUES ('Convertible Marka', N'BAM', N'KM');
INSERT INTO currency VALUES ('Pula', 'BWP', N'P');
INSERT INTO currency VALUES ('Leva', 'BGN', N'лв');
INSERT INTO currency VALUES ('Reais', 'BRL', N'R$');
INSERT INTO currency VALUES ('Pounds', 'GBP', N'£');
INSERT INTO currency VALUES ('Dollars', 'BND', N'$');
INSERT INTO currency VALUES ('Riels', 'KHR', N'៛');
INSERT INTO currency VALUES ('Dollars', 'CAD', N'$');
INSERT INTO currency VALUES ('Dollars', 'KYD', N'$');
INSERT INTO currency VALUES ('Pesos', 'CLP', N'$');
INSERT INTO currency VALUES ('Yuan Renminbi', N'CNY', N'¥');
INSERT INTO currency VALUES ('Pesos', 'COP', N'$');
INSERT INTO currency VALUES ('Colón', 'CRC', N'₡');
INSERT INTO currency VALUES ('Kuna', 'HRK', N'kn');
INSERT INTO currency VALUES ('Pesos', 'CUP', N'₱');
INSERT INTO currency VALUES ('Koruny', 'CZK', N'Kč');
INSERT INTO currency VALUES ('Kroner', 'DKK', N'kr');
INSERT INTO currency VALUES ('Pesos', 'DOP ', N'RD$');
INSERT INTO currency VALUES ('Dollars', 'XCD', N'$');
INSERT INTO currency VALUES ('Pounds', 'EGP', N'£');
INSERT INTO currency VALUES ('Colones', 'SVC', N'$');
INSERT INTO currency VALUES ('Pounds', 'FKP', N'£');
INSERT INTO currency VALUES ('Dollars', 'FJD', N'$');
INSERT INTO currency VALUES ('Cedis', 'GHC', N'¢');
INSERT INTO currency VALUES ('Pounds', 'GIP', N'£');
INSERT INTO currency VALUES ('Quetzales', 'GTQ', N'Q');
INSERT INTO currency VALUES ('Pounds', 'GGP', N'£');
INSERT INTO currency VALUES ('Dollars', 'GYD', N'$');
INSERT INTO currency VALUES ('Lempiras', 'HNL', N'L');
INSERT INTO currency VALUES ('Dollars', 'HKD', N'$');
INSERT INTO currency VALUES ('Forint', 'HUF', N'Ft');
INSERT INTO currency VALUES ('Kronur', 'ISK', N'kr');
INSERT INTO currency VALUES ('Rupees', 'INR', N'Rp');
INSERT INTO currency VALUES ('Rupiahs', 'IDR', N'Rp');
INSERT INTO currency VALUES ('Rials', 'IRR', N'﷼');
INSERT INTO currency VALUES ('Pounds', 'IMP', N'£');
INSERT INTO currency VALUES ('New Shekels', 'ILS', N'₪');
INSERT INTO currency VALUES ('Dollars', 'JMD', N'J$');
INSERT INTO currency VALUES ('Yen', 'JPY', N'¥');
INSERT INTO currency VALUES ('Pounds', 'JEP', N'£');
INSERT INTO currency VALUES ('Tenge', 'KZT', N'лв');
INSERT INTO currency VALUES ('Won', 'KPW', N'₩');
INSERT INTO currency VALUES ('Won', 'KRW', N'₩');
INSERT INTO currency VALUES ('Soms', 'KGS', N'лв');
INSERT INTO currency VALUES ('Kips', 'LAK', N'₭');
INSERT INTO currency VALUES ('Lati', 'LVL', N'Ls');
INSERT INTO currency VALUES ('Pounds', 'LBP', N'£');
INSERT INTO currency VALUES ('Dollars', 'LRD', N'$');
INSERT INTO currency VALUES ('Switzerland Francs', 'CHF', N'CHF');
INSERT INTO currency VALUES ('Litai', 'LTL', N'Lt');
INSERT INTO currency VALUES ('Denars', 'MKD', N'ден');
INSERT INTO currency VALUES ('Ringgits', 'MYR', N'RM');
INSERT INTO currency VALUES ('Rupees', 'MUR', N'₨');
INSERT INTO currency VALUES ('Pesos', 'MXN', N'$');
INSERT INTO currency VALUES ('Tugriks', 'MNT', N'₮');
INSERT INTO currency VALUES ('Meticais', 'MZN', N'MT');
INSERT INTO currency VALUES ('Dollars', 'NAD', N'$');
INSERT INTO currency VALUES ('Rupees', 'NPR', N'₨');
INSERT INTO currency VALUES ('Guilders', 'ANG', N'ƒ');
INSERT INTO currency VALUES ('Dollars', 'NZD', N'$');
INSERT INTO currency VALUES ('Cordobas', 'NIO', N'C$');
INSERT INTO currency VALUES ('Nairas', 'NGN', N'₦');
INSERT INTO currency VALUES ('Krone', 'NOK', N'kr');
INSERT INTO currency VALUES ('Rials', 'OMR', N'﷼');
INSERT INTO currency VALUES ('Rupees', 'PKR', N'₨');
INSERT INTO currency VALUES ('Balboa', 'PAB', N'B/.');
INSERT INTO currency VALUES ('Guarani', 'PYG', N'Gs');
INSERT INTO currency VALUES ('Nuevos Soles', 'PEN', N'S/.');
INSERT INTO currency VALUES ('Pesos', 'PHP', N'Php');
INSERT INTO currency VALUES ('Zlotych', 'PLN', N'zł');
INSERT INTO currency VALUES ('Rials', 'QAR', N'﷼');
INSERT INTO currency VALUES ('New Lei', 'RON', N'lei');
INSERT INTO currency VALUES ('Rubles', 'RUB', N'руб');
INSERT INTO currency VALUES ('Pounds', 'SHP', N'£');
INSERT INTO currency VALUES ('Riyals', 'SAR', N'﷼');
INSERT INTO currency VALUES ('Dinars', 'RSD', N'Дин.');
INSERT INTO currency VALUES ('Rupees', 'SCR', N'₨');
INSERT INTO currency VALUES ('Dollars', 'SGD', N'$');
INSERT INTO currency VALUES ('Dollars', 'SBD', N'$');
INSERT INTO currency VALUES ('Shillings', 'SOS', N'S');
INSERT INTO currency VALUES ('Rand', 'ZAR', N'R');
INSERT INTO currency VALUES ('Rupees', 'LKR', N'₨');
INSERT INTO currency VALUES ('Kronor', 'SEK', N'kr');
INSERT INTO currency VALUES ('Dollars', 'SRD', N'$');
INSERT INTO currency VALUES ('Pounds', 'SYP', N'£');
INSERT INTO currency VALUES ('New Dollars', 'TWD', N'NT$');
INSERT INTO currency VALUES ('Baht', 'THB', N'฿');
INSERT INTO currency VALUES ('Dollars', 'TTD', N'TT$');
INSERT INTO currency VALUES ('Lira', 'TRY', N'₺');
INSERT INTO currency VALUES ('Liras', 'TRL', N'£');
INSERT INTO currency VALUES ('Dollars', 'TVD', N'$');
INSERT INTO currency VALUES ('Hryvnia', 'UAH', N'₴');
INSERT INTO currency VALUES ('Pesos', 'UYU', N'$U');
INSERT INTO currency VALUES ('Sums', 'UZS', N'лв');
INSERT INTO currency VALUES ('Bolivares Fuertes', 'VEF', N'Bs');
INSERT INTO currency VALUES ('Dong', 'VND', N'₫');
INSERT INTO currency VALUES ('Rials', 'YER', N'﷼');
INSERT INTO currency VALUES ('Zimbabwe Dollars', 'ZWD', N'Z$');
INSERT INTO currency VALUES ('Rupees', 'INR', N'₹');
END
GO
-- drop table currency

-- Select values from table                        
--SELECT * FROM currency;

IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'ELOG_N'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE dbo.ELOG_N
	(	id_elog_n		int not null identity CONSTRAINT PK_ELOG_N PRIMARY KEY
	,	opis_n			nvarchar(100) NOT NULL
	,	dt				datetime NOT NULL DEFAULT GETDATE()
	,	u_name			nvarchar(40) NOT NULL DEFAULT USER_NAME()
	,	h_name			nvarchar(100) NOT NULL DEFAULT HOST_NAME()
	) 
END
GO
--SELECT * FROM ELOG_N

-- TODO create WB and WB_DET tables

/* detale błędu
** musi być najpierw wstawiony nagłowek błedu a potem z ID nagłowka błedu wstawiane są detale
*/
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'ELOG_D'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE dbo.ELOG_D
	(	id_elog_n		int not null 
			CONSTRAINT FK_ELOG_N__ELOG_P FOREIGN KEY
			REFERENCES ELOG_N(id_elog_n)
	,	opis_d			nvarchar(100) NOT NULL
	) 
END
GO

--data validation for tmp_na

/* create empty procedure to be able to use alter later an run script multiple times */
IF NOT EXISTS 
(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'create_empty_proc')
		AND		(OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
)
BEGIN
	DECLARE @sql nvarchar(500)
	SET @sql = 'CREATE PROCEDURE dbo.create_empty_proc AS '
	EXEC sp_sqlexec @sql
END

GO

EXEC dbo.create_empty_proc @proc_name = 'create_empty_fun'
GO

ALTER PROCEDURE dbo.create_empty_fun (@fun_name nvarchar(100))
AS
	IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = @fun_name)
		AND		(OBJECTPROPERTY(o.[ID], N'IsScalarFunction') = 1)
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.' + @fun_name + N' () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END
GO

GO

--convert text to money type
/*test
SELECT dbo.txt2M(N'123,456.89') -- 123456,89
SELECT dbo.txt2M(N'123.456,89') -- 123456,89
SELECT dbo.txt2M(N'123 456,89') -- 123456,89
select dbo.txt2M(netto_fa),* from tmp_fa_na
*/
ALTER FUNCTION dbo.txt2M(@txt nvarchar(20) )
RETURNS MONEY
AS
BEGIN
	SET @txt = REPLACE(@txt, N' ', N'')

	IF @txt LIKE '%,%.%' 
	BEGIN
		SET @txt = REPLACE(@txt, N',', N'')
	END ELSE
	IF @txt LIKE '%.%,%'
	BEGIN
		SET @txt = REPLACE(@txt, N'.', N'')
	END
	SET @txt = REPLACE(@txt, N',', N'.')
	RETURN  CONVERT(money, @txt)
END
GO


EXEC dbo.create_empty_fun 'txt2D'
GO

-- convert data to date type
/* test
SELECT dbo.txt2D(N'2022-03-31') -- 2022-03-31 00:00:00.000
SELECT dbo.txt2D(N'31/03/2022') -- 2022-03-31 00:00:00.000
SELECT dbo.txt2D(N'20220331') -- 2022-03-31 00:00:00.000
select dbo.txt2M(netto_fa),dbo.txt2D(data),* from tmp_fa_na
*/

ALTER FUNCTION dbo.txt2D(@txt nvarchar(10) )
RETURNS DATETIME
AS
BEGIN
--YYYYMMDD
	IF @txt LIKE N'[1-3][0-9][0-9][0-9][0-1][0-9][0-3][0-9]%'
		RETURN CONVERT(datetime, @txt, 112)

-- Replace possible separators to .
	SET @txt = REPLACE(@txt, N'-', N'.')
	SET @txt = REPLACE(@txt, N'/', N'.')
	SET @txt = REPLACE(@txt, N'_', N'.')
	SET @txt = REPLACE(@txt, N' ', N'.')

--YYYY.MM.DD
	IF @txt LIKE N'[1-3][0-9][0-9][0-9].[0-1][0-9].[0-3][0-9]%'
		RETURN CONVERT(datetime, @txt, 102)
--DD.MM.YYYY
	RETURN CONVERT(datetime, @txt, 104)
END
GO


-- validate headers data
CREATE PROCEDURE dbo.tmp_na_check(@err int = 0 output)
AS
	DECLARE @cnt int, @en nvarchar(100), @id_en int

	SET @err = 0

		SET @en = 'Error in procedure tmp_na_check / '

	--headers file must not be empty
	SELECT @cnt = COUNT(*) FROM tmp_wb_na

	IF @cnt = 0
	BEGIN
		SET @en = @en + 'Headers file is empty !!!'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) VALUES (@id_en, '0 rows in tmp_wb_na')

		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END
--parameter number must be unique for every row because it identifies bank statement in db
	DECLARE @totalRows int, @uniqueNum int 

	SELECT @totalRows = COUNT(*) FROM tmp_wb_na
	
	SELECT @uniqueNum = COUNT(DISTINCT numer) FROM tmp_wb_na
	
	IF @uniqueNum < @totalRows 
	BEGIN
		SET @en = @en + 'Bank statement number must be unique !!!'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
		SELECT DISTINCT @id_en, t.numer
		FROM tmp_wb_na t
		WHERE t.numer IN (
			SELECT numer
			FROM tmp_wb_na
			GROUP BY numer
			HAVING COUNT(*) > 1
		)

		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
		RETURN -1
	END
-- start date must be before end date
	DECLARE @InvalidDatesCount int 

	SELECT @InvalidDatesCount = COUNT(*)
	FROM tmp_wb_na
	WHERE data_do < data_od

	IF @InvalidDatesCount > 0
	BEGIN
	SET @en = @en + 'Parameter data_od must be a date before parameter data_do !!!'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d)
		/* 112 - yyyymmdd */
			SELECT @id_en, 'Invalid dates in row. data_od: ' + CONVERT(nvarchar, data_od, 112) + ', data_do: ' + CONVERT(nvarchar, data_do, 112)
			FROM tmp_wb_na
			WHERE data_do < data_od

		RETURN -1
	END
-- creation date must be before start date

	SELECT @InvalidDatesCount = COUNT(*)
	FROM tmp_wb_na
	WHERE data_od < data_utw

	IF @InvalidDatesCount > 0
	BEGIN
	SET @en = @en + 'Paramter data_utw must be a date before data_od !!!'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()
		/* suppose that date in in format dd.mm.yyyy */
		INSERT INTO ELOG_D(id_elog_n, opis_d)
        SELECT @id_en, N'Invalid dates in row. data_utw: ' + CONVERT(nvarchar, data_utw, 112) 
		+ ', data_od: ' + CONVERT(nvarchar, data_od, 112)
        FROM tmp_wb_na
        WHERE data_od < data_utw

    RETURN -1
	END
--every date must be after current date

	DECLARE @date_max nchar(8)
	SET @date_max = CONVERT(nchar(8), GETDATE(), 112) -- rok i mies z dzis

	IF EXISTS ( SELECT 1 FROM tmp_wb_na t WHERE t.data_utw >= @date_max 
	OR t.data_od >= @date_max
    OR t.data_do >= @date_max 
	)
	BEGIN
		SET @en = @en + 'Every date must be before current date!!!'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()
		/* suppose that date in in format dd.mm.yyyy */
		INSERT INTO ELOG_D(id_elog_n, opis_d)
        SELECT 
            @id_en, 
            N'Invalid future data in row: data.utw. ' + CONVERT(nvarchar, t.data_utw, 112) + 
            ', data_od: ' + CONVERT(nvarchar, t.data_od, 112) + 
            ', data_do: ' + CONVERT(nvarchar, t.data_do, 112)
        FROM tmp_wb_na t
        WHERE 
            CONVERT(nchar(8), t.data_utw, 112) >= @date_max 
            OR CONVERT(nchar(8), t.data_od, 112) >= @date_max
            OR CONVERT(nchar(8), t.data_do, 112) >= @date_max 

		RETURN -1
	END
	-- account number must be listed in PODMIOT table

	IF NOT EXISTS (
		SELECT 1
		FROM tmp_wb_na t
		WHERE EXISTS (
			SELECT 1
			FROM PODMIOT p
			WHERE p.numer_rach = t.numer_rach
		)
	)
	BEGIN
		SET @en = @en + 'Every account number must have matching entity in PODMIOT table!!'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
        SELECT DISTINCT @id_en, 'Missing account number: ' + t.numer_rach
        FROM tmp_wb_na t
        WHERE NOT EXISTS (
            SELECT 1
            FROM PODMIOT p
            WHERE p.numer_rach = t.numer_rach
        )

		RAISERROR(@en, 16, 1)
    RETURN -1

		RETURN -1
	END

	EXEC dbo.create_empty_proc @proc_name = 'tmp_poz_check'
	GO
	
-- TODO: data validation for tmp_poz
ALTER PROCEDURE dbo.tmp_poz_check (@err int =0 output)
AS
	EXEC dbo.tmp_na_check @err = @err output

-- check if headers validation caused error
	IF NOT (@err = 0)
	BEGIN
		RAISERROR(N'Errors in headers', 16, 3)
		RETURN -1
	END
	DECLARE @cnt int, @en nvarchar(100), @id_en int
	SET @en = 'Error in procedure: tmp_poz_check / '

-- check if every header have psotions
	SELECT @cnt = COUNT(*)
		FROM tmp_wb_na  n
		WHERE NOT EXISTS 
		( SELECT 1
			FROM tmp_wb_poz  d
			WHERE	d.numer	= n.numer
		)

	IF @cnt > 0
	BEGIN
		SET @en = @en + 'Headers without positions'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
		SELECT @id_en, N'Withdrawal number:' + n.numer
			+ N' / Account num:' + n.numer_rach
		FROM tmp_wb_na n
		WHERE NOT EXISTS 
		( SELECT 1
			FROM tmp_wb_poz d
			WHERE	d.numer	= n.numer
		)
		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END
GO

-- TODO: Add missing currency validation in headers
GO