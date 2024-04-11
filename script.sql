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
-- drop table tmp_wb_poz
exec rmv_table @tab_name = 'tmp_wb_poz'  -- is it necessary because ssis deletes tables before importing data??
GO
CREATE TABLE dbo.tmp_wb_poz
(	numer nvarchar(20) NOT NULL
,	lp int NOT NULL
,	numer_wiersza nvarchar(20) NOT NULL
,	data nvarchar(10) NOT NULL /* date in format RRRR.MM.DD or DD.MM.RRRR */
,	kwota nvarchar(20) NOT NULL
,	saldo_po nvarchar(20) NOT NULL
,	nazwa_kontrahenta nvarchar(256) NOT NULL
,	opis nvarchar(256) NOT NULL /* from this dane_odbiorcy will be created */
)
GO

-- create table with additional data neede for jpk but not provided in headers or positions
-- drop table Podmiot
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

--drop table known_acc_num
--create table connecting podmiot with its account numbers (one podmiot can have multiple acc_num and create different bank statements)
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'known_acc_num'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE known_acc_num (
    id_podmiotu nchar(4) NOT NULL,
    numer_rach NVARCHAR(28) NOT NULL,
    CONSTRAINT pk_numer_rach PRIMARY KEY (numer_rach),
    CONSTRAINT fk_podmiotu FOREIGN KEY (id_podmiotu) REFERENCES PODMIOT(PODMIOT_ID)
);

END
GO

-- fill table with data
IF NOT EXISTS ( SELECT 1 FROM known_acc_num )
BEGIN
	INSERT INTO dbo.known_acc_num
	(
		id_podmiotu,
		numer_rach

	)
	VALUES
	(
		'0001',
		'PL61109010140000071219812874'
	)
END
GO

-- Error Handling
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

/* final table for headers */
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'WB'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE dbo.WB
	(	numer_rach 	nvarchar(28) NOT NULL CONSTRAINT FK_WB__known_acc_num FOREIGN KEY
							REFERENCES known_acc_num(numer_rach)
											/* with what account number its connected, knowing numer_rach whe know PODMIOT to from data in known_acc_num table */
	,	numer		nvarchar(20)	NOT NULL CONSTRAINT PK_WB1 PRIMARY KEY
											/* unique number for every bank statement */
	,	saldo_pocz  money	NOT NULL
	,	saldo_kon	money	NOT NULL
	,	waluta_rach nvarchar(3)	NOT NULL
	,	data_utw datetime NOT NULL
	,	data_od datetime	NOT NULL
	,	data_do datetime NOT NULL
	)
END
GO

/*final table for positions*/
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'WB_DET'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN

	CREATE TABLE dbo.WB_DET
	(	numer		nvarchar(20) NOT NULL CONSTRAINT FK_WB_DET__WB FOREIGN KEY
							REFERENCES WB(numer)	/* number of connected bank statement */
	,	lp			int	NOT NULL IDENTITY CONSTRAINT PK_WB_DET PRIMARY KEY
													/* to identify a position in one bank statement */
	,	data datetime NOT NULL
	,	kwota money NOT NULL
	,	saldo_po money NOT NULL
	,	nazwa_kontrahenta nvarchar(256)
	,	opis nvarchar(256) NOT NULL
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

ALTER PROCEDURE dbo.create_empty_proc (@proc_name nvarchar(100))
/* przekazujemy samą nazwę procedura sama dodaje dbo.
*/
AS
	IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = @proc_name)
		AND		(OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE PROCEDURE dbo.' + @proc_name + N' AS '
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

EXEC dbo.create_empty_fun 'txt2M'
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

EXEC dbo.create_empty_proc @proc_name = 'tmp_na_check'
GO

-- validate headers data
ALTER PROCEDURE dbo.tmp_na_check(@err int = 0 output)
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

			RAISERROR(@en, 16, 4)
			SET @err = 1
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

		SET @err = 1
		RAISERROR(@en, 16, 4)
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

			SET @err = 1
			RAISERROR(@en, 16, 4)
		RETURN -1
	END
-- Check if currency in header has its matching code in currency table


IF EXISTS (
    SELECT 1
    FROM tmp_wb_na t
    WHERE NOT EXISTS (
        SELECT 1
        FROM currency c
        WHERE c.code = t.waluta_rach
    )
)
BEGIN
    SET @en = @en + N'Currency code from header does not exist in currency table'
    
    INSERT INTO ELOG_N(opis_n) VALUES (@en)
    SET @id_en = SCOPE_IDENTITY()

    INSERT INTO ELOG_D(id_elog_n, opis_d) 
        SELECT DISTINCT @id_en, 'Wrong currency code: ' + t.waluta_rach
        FROM tmp_wb_na t
        WHERE NOT EXISTS (
            SELECT 1
            FROM currency c
            WHERE c.code = t.waluta_rach
        )

		RAISERROR(@en, 16, 4)
		SET @err = 1
    RETURN -1
END

-- check if account number from header is connected with Podmiot entity in known_acc_num table

IF NOT EXISTS (
    SELECT 1
    FROM tmp_wb_na n
    WHERE EXISTS (
        SELECT 1
        FROM known_acc_num nt
        WHERE nt.numer_rach = n.numer_rach
    )
)
BEGIN
    SET @en = @en + N'Account number for header is not connected with any known podmiot'
    
    INSERT INTO ELOG_N(opis_n) VALUES (@en)
    SET @id_en = SCOPE_IDENTITY()
    
    INSERT INTO ELOG_D(id_elog_n, opis_d) 
        SELECT DISTINCT @id_en, 'Invalid account number: ' + n.numer_rach
        FROM tmp_wb_na n
        WHERE NOT EXISTS (
            SELECT 1
            FROM known_acc_num nt
            WHERE nt.numer_rach = n.numer_rach
        )

    RAISERROR(@en, 16, 4)
    RETURN -1
END
GO

	
-- TODO: data validation for tmp_poz

EXEC dbo.create_empty_proc @proc_name = 'tmp_poz_check'
GO


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

-- check if every header have positions
	SELECT @cnt = COUNT(*)
		FROM tmp_wb_na  n
		WHERE NOT EXISTS 
		( SELECT 1
			FROM tmp_wb_poz  d
			WHERE	d.numer	= n.numer
		)

	IF @cnt > 0
	BEGIN
		SET @en = @en + 'Headers without positions exists'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
		SELECT @id_en, N'Bank statement number:' + n.numer
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

-- check if every postion have its header
SELECT @cnt = COUNT(*)
		FROM tmp_wb_poz  n
		WHERE NOT EXISTS 
		( SELECT 1
			FROM tmp_wb_na  d
			WHERE	d.numer	= n.numer
		)

	IF @cnt > 0
	BEGIN
		SET @en = @en + N'Postitons without headers exists'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
		SELECT @id_en,  N'Bank statement number:' + n.numer
		FROM tmp_wb_poz n
		WHERE NOT EXISTS 
		( SELECT 1
			FROM tmp_wb_na d
			WHERE	d.numer	= n.numer
		)
		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END

-- check if date of the postions is between dates of the connected header

	IF EXISTS (
    SELECT 1
    FROM tmp_wb_poz poz
    WHERE NOT EXISTS (
        SELECT 1
        FROM tmp_wb_na na
        WHERE na.numer = poz.numer 
        AND poz.data > na.data_od 
        AND poz.data < na.data_do
    )
)
BEGIN
    Set @en = @en + N'Invalid date in position compared to its header'

    INSERT INTO ELOG_N(opis_n) VALUES (@en)
    SET @id_en = SCOPE_IDENTITY()
    
    INSERT INTO ELOG_D(id_elog_n, opis_d) 
        SELECT DISTINCT @id_en, 'Invalid date in position of bank statement with number: ' + poz.numer + ', Invalid date: ' + CONVERT(nvarchar, poz.data, 120)
        FROM tmp_wb_poz poz
        WHERE NOT EXISTS (
            SELECT 1
            FROM tmp_wb_na na
            WHERE na.numer = poz.numer 
            AND poz.data > na.data_od 
            AND poz.data < na.data_do
        )
		SET @err = 1
		RAISERROR(@en, 16, 4)
    RETURN -1
END

-- make a loop to create final tables with data for jpk

	
	DECLARE CC INSENSITIVE CURSOR FOR 
		SELECT n.numer, n.numer_rach, n.waluta_rach
			, dbo.txt2D(n.data_utw)		AS data_utw
			, dbo.txt2D(n.data_od)		AS data_od
			, dbo.txt2D(n.data_do)	AS data_do
			, dbo.txt2M(n.saldo_poc) AS saldo_poc
			, dbo.txt2M(n.saldo_kon) AS saldo_kon
			FROM tmp_wb_na n

	DECLARE @numer nvarchar(20), @numer_rach nvarchar(28), @waluta_rach nvarchar(3)
	 , @data_utw datetime, @data_od datetime, @data_do datetime, @saldo_poc money, @saldo_kon money
	 , @TrCnt int
	 OPEN CC
	 FETCH NEXT FROM CC INTO @numer, @numer_rach, @waluta_rach, @data_utw, @data_od, @data_do, @saldo_poc, @saldo_kon

	 -- start inserting headers and positions
	 WHILE (@@FETCH_STATUS = 0) AND (@err = 0)
	 BEGIN
		SET @TrCnt = @@TRANCOUNT
		IF @TrCnt =0 
			BEGIN TRAN TR_POZ_NA
		ELSE 
			SAVE TRAN TR_POZ_NA

		/* insert bank statement header */
		INSERT INTO WB (numer_rach, numer, saldo_kon, saldo_kon, waluta_rach, data_utw, data_od, data_do)
			VALUES (@numer_rach, @numer, @saldo_kon, @saldo_poc, @waluta_rach, @data_utw, @data_od, @data_do)
		/* get id */
		SELECT @err=@@ERROR /*, @id_wb = SCOPE_IDENTITY() */

		IF @err = 0
		BEGIN
			/* if header was inserted successfully insert position */
			INSERT INTO WB_DET ( numer, lp, data, kwota, saldo_po, nazwa_kontrahenta, opis)
			SELECT @numer, 
			t.lp
			, dbo.txt2M(t.data) 
			, t.kwota
			, dbo.txt2M(t.saldo_po)
			, t.nazwa_kontrahenta
			, dbo.txt2M(t.opis)
			FROM dbo.tmp_wb_poz t

			SET @err = @@ERROR 
		END
		IF @err = 0 /* wszystko OK */
		BEGIN
			IF @trCnt = 0 /* zapisz zmiany */
				COMMIT TRAN TR_POZ_NA
		END 
		ELSE /* odwołaj zmiany */
			ROLLBACK TRAN TR_POZ_NA

		FETCH NEXT FROM CC INTO @numer, @numer_rach, @waluta_rach, @data_utw, @data_od, @data_do, @saldo_poc, @saldo_kon
	 END
	 CLOSE CC
	 DEALLOCATE CC
	GO
-- SELECT * FROM tmp_wb_poz
-- SELECT * FROM tmp_wb_na
-- SELECT * FROM known_acc_num

-- Whate can be done to imrpove in future: list all types of jpk_wb and create procedure which choose type and takes as second and third argument dates of the bank statement to be then able too choose which bank statemnt
-- from our data take to generate report



-- create functions for preapring data for xml
EXEC dbo.create_empty_fun @fun_name = 'SAFT_CLEAR_TXT'
GO

ALTER FUNCTION dbo.SAFT_CLEAR_TXT(@msg nvarchar(256) )
/* clear text are from dangerous characters*/
RETURNS nvarchar(256)
AS
BEGIN
	IF (@msg IS NULL)  OR (RTRIM(@msg) = N'')
		RETURN N''

	SET @msg = LTRIM(RTRIM(@msg))
	/* clear potentially dangerous characters for XML within the string */
	SET @msg = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@msg,'\n',N' '),N'<',N'?'),N'>','?'),N':',N'?'),N'\',N'?')
	SET @msg = REPLACE(@msg,N'/',N'!')
	RETURN RTRIM(LEFT(@msg,255)) /* limit for SAFT text field is 255 */
END
GO

EXEC dbo.create_empty_fun @fun_name = 'SAFT_CLEAR_VATID'
GO

ALTER FUNCTION dbo.SAFT_CLEAR_VATID(@vatid nvarchar(20) )
RETURNS nvarchar(10)
AS
BEGIN
	/* sometimes they are spaces and other chars in NIP, - and : */
	/* NIP can have country prefix but jpk dont want to include it  */
	SET @vatid = REPLACE(REPLACE(REPLACE(@vatid,N' ',N''),N':',''),N'-','')
	SET @vatid = dbo.SAFT_CLEAR_TXT(@vatid)
	/* clear potentially dangerous characters for XML within the string */
	IF @vatid LIKE 'VATID%'
		SET @vatid = RTRIM(SUBSTRING(@vatid,6,20))
	IF (@vatid LIKE 'NIP%') OR (@vatid LIKE 'VAT%')
		SET @vatid = RTRIM(SUBSTRING(@vatid,4,20))
/* delete prefix if exists
- in theory we shuld compare with ue countries dictionary */
	IF @vatid LIKE N'[A-Z][A-Z][1-9]%'
		SET @vatid = LTRIM(RTRIM(SUBSTRING(@vatid,3,20)))

	RETURN LEFT(@vatid,10)
END
GO


EXEC dbo.create_empty_fun @fun_name = 'SAFT_DEFAULT'
GO

ALTER FUNCTION dbo.SAFT_DEFAULT( @msg nvarchar(250), @default nvarchar(20)=N'brak' )
/* sometimes we can type 'brak' in JPK when we dont have some info */
RETURNS nvarchar(250)
AS
BEGIN
	RETURN LTRIM(RTRIM(ISNULL(dbo.SAFT_NULL(@msg),@default)))
END
GO

EXEC dbo.create_empty_fun @fun_name = 'SAFT_NULL'
GO

ALTER FUNCTION dbo.SAFT_NULL(@msg nvarchar(250) )
RETURNS nvarchar(250)
AS
/* when text is empty but must be an XML NULL*/
BEGIN
	IF @msg IS NULL OR RTRIM(@msg)=N''
		RETURN NULL
	RETURN @msg
END
GO

EXEC dbo.create_empty_fun @fun_name = 'SAFT_DATE'
GO

ALTER FUNCTION dbo.SAFT_DATE(@d datetime )
/* data fromat accepted in jpk */
RETURNS nchar(10)
AS
BEGIN
	RETURN CONVERT(nchar(10), @d, 120)
END
GO

EXEC dbo.create_empty_fun @fun_name = 'SAFT_GET_AMT'
GO
ALTER FUNCTION dbo.SAFT_GET_AMT(@amt money )
/* money format accepted in xml */
RETURNS nvarchar(20)
AS
BEGIN
	IF @amt IS NULL
		RETURN N''
	RETURN RTRIM(LTRIM(STR(@amt,18,2)))
END
GO

EXEC dbo.create_empty_fun @fun_name = 'PobierzSumeObciazen'
GO

ALTER FUNCTION PobierzSumeObciazen(@numer_wyciagu_var NVARCHAR(20))
RETURNS MONEY
AS
BEGIN
    DECLARE @suma_obciazen MONEY;

    SELECT @suma_obciazen = SUM(kwota)
    FROM WB_DET
    WHERE kwota < 0
      AND numer = @numer_wyciagu_var;

    RETURN ISNULL(@suma_obciazen, 0);
END
GO
-- SELECT dbo.PobierzSumeObciazen('NumerWyciagu') AS SumaObciazen;
EXEC dbo.create_empty_fun @fun_name = 'PobierzSumeUznan'
GO

ALTER FUNCTION PobierzSumeUznan(@numer_wyciagu_var NVARCHAR(20))
RETURNS MONEY
AS
BEGIN
    DECLARE @suma_obciazen MONEY;

    SELECT @suma_obciazen = SUM(kwota)
    FROM WB_DET
    WHERE kwota > 0
      AND numer = @numer_wyciagu_var;

    RETURN ISNULL(@suma_obciazen, 0);
END
GO

EXEC dbo.create_empty_fun @fun_name = 'LiczbeWierszyDlaNumeru'
GO

ALTER FUNCTION LiczbaWierszyDlaNumeru
(
    @numer_wyciagu_var NVARCHAR(20)
)
RETURNS INT
AS
BEGIN
    DECLARE @liczbaWierszy INT;

    SELECT @liczbaWierszy = COUNT(*)
    FROM WB_DET
    WHERE numer = @numer_wyciagu_var;

    RETURN @liczbaWierszy;
END;
GO

--generate xml - for now i will focus on generating 1 report suppsoing i have 1 header with many positions
-- then loop can be created to generate many xmls for many headers with many positions 

GO
