SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[SubstituteManualIntegrationSQLParameters] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@reportID uniqueidentifier = null,
	@parameters IntegrationSQLCollection READONLY,
	@SQLBase nvarchar(MAX) OUTPUT
AS
DECLARE @propertyIDs GuidCollection
DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @tempStr nvarchar(500)
DECLARE @nameID uniqueidentifier
DECLARE @SQLID uniqueidentifier
DECLARE @tempName nvarchar(50)
DECLARE @tempParameters nvarchar(4000)
DECLARE @tempParameterType nvarchar(30)
DECLARE @paraCtr int
DECLARE @paraMaxCtr int
DECLARE @columnName nvarchar(100)
DECLARE @monthOffset int
DECLARE @lastParameterIdentifier uniqueidentifier = NEWID()
DECLARE @thisParameterIdentifier uniqueidentifier
DECLARE @conjuncture nvarchar(7) = ' AND '
DECLARE @columnType nvarchar(50)
DECLARE @clauseCount int
DECLARE @endOffsetComparer nvarchar(5) = ' <= '
DECLARE @startComparer nvarchar(5) = ' >= '
DECLARE @lastValue nvarchar(10)

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #TempSQL (
		Sequence			int identity,
		NameID				uniqueidentifier null,
		SQLID				uniqueidentifier not null,
		FROMClause			nvarchar(500) null,
		WHEREClause			nvarchar(1000) null,
		ColumnName			nvarchar(100) null,
		ParameterDataType	nvarchar(100) not null)
		
	INSERT #TempSQL
		SELECT DISTINCT sqlReport.IntegrationSQLReportID AS 'NameID', sql1.IntegrationSQLID AS 'SQLID', sql1.FROMClause, sql1.WHEREClause, 
						sql1.ColumnName, sql1.ParameterDataType
			FROM @parameters para
				INNER JOIN IntegrationSQL sql1 ON para.IntegrationSQLID = sql1.IntegrationSQLID
				LEFT JOIN IntegrationSQLReport sqlReport ON sqlReport.IntegrationSQLReportID = @reportID
		--SELECT DISTINCT sqlReport.IntegrationSQLReportID AS 'NameID', sql1.IntegrationSQLID AS 'SQLID', sql1.FROMClause, sql1.WHEREClause, 
		--				sql1.ColumnName, sql1.ParameterDataType
		--	FROM IntegrationSQLReport sqlReport
		--		INNER JOIN IntegrationSQLReportIntegrationSQL sqlJoin ON sqlReport.IntegrationSQLReportID = sqlJoin.IntegrationSQLReportID
		--		INNER JOIN IntegrationSQL sql1 on sqlJoin.IntegrationSQLID = sql1.IntegrationSQLID
		--	WHERE sqlReport.IntegrationSQLReportID = @reportID

	CREATE TABLE #Parameters (
		ParaIdent			int identity,
		Name nvarchar(50)	not null,
		Value nvarchar(100) not null,
		[Type] nvarchar(100) null,
		ParameterIndentifier uniqueidentifier not null)

	SET @maxCtr = (select MAX(Sequence) from #TempSQL)

	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @tempStr = FROMClause, @nameID = NameID, @SQLID = SQLID
			FROM #TempSQL
			WHERE Sequence = @ctr
		INSERT #Parameters
			SELECT Name, Value, [Type], ParameterIdentifier
				FROM @parameters 
				WHERE IntegrationSQLID = @SQLID

		IF (@tempStr IS NOT NULL)
		BEGIN
			SET @paraCtr = 1
			SET @paraMaxCtr = ISNULL((SELECT MAX(ParaIdent) FROM #Parameters), 0)
			WHILE (@paraCtr <= @paraMaxCtr)
			BEGIN
				SELECT @tempName = Name, @tempParameters = Value
					FROM #Parameters
					WHERE ParaIdent = @paraCtr

				SET @paraCtr = @paraCtr + 1
			END
			SET @SQLBase = @SQLBase + ' ' + @tempStr + ' '
		END
		SET @ctr = @ctr + 1
		TRUNCATE TABLE #Parameters
	END

	SET @SQLBase = @SQLBase + ' WHERE p.PropertyID = ' + + '''' + CAST(@propertyID AS varchar(36)) + ''''  + ' '
	
	SET @ctr = 1
	SET @paraCtr = 1

	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @tempStr = WHEREClause, @nameID = NameID, @SQLID = SQLID, @columnName = ColumnName, @columnType = ParameterDataType
			FROM #TempSQL
			WHERE Sequence = @ctr
			
		INSERT #Parameters
			SELECT Name, Value, [Type], ParameterIdentifier
				FROM @parameters 
				WHERE IntegrationSQLID = @SQLID
				ORDER BY Name, ParameterIdentifier, Value DESC

		IF ((@tempStr IS NOT NULL) OR (@columnName IS NOT NULL))
		BEGIN
			SET @paraCtr = 1
			SET @paraMaxCtr = ISNULL((SELECT MAX(ParaIdent) FROM #Parameters), 0)
			WHILE (@paraCtr <= @paraMaxCtr)
			BEGIN
				SET @conjuncture = ' AND '
				SELECT @tempParameters = Value, @tempParameterType = [Type], @thisParameterIdentifier = ParameterIndentifier
					FROM #Parameters
					WHERE ParaIdent = @paraCtr
				--IF ((@paraMaxCtr >= 2) AND (@tempParameterType NOT IN ('LTValue', 'GTValue', 'EqValue')))
				IF (@paraMaxCtr >= 2)
				BEGIN
					IF (@paraCtr = 1)
					BEGIN 
						SET @tempStr = ISNULL(@tempStr, '') + ' AND (('
						SET @conjuncture = ''
					END
					ELSE IF ((@lastParameterIdentifier IS NOT NULL) AND (@lastParameterIdentifier <> @thisParameterIdentifier))
					BEGIN
						SET @conjuncture = ') OR ('
					END
					ELSE IF (@tempParameterType = 'GTValue')
					BEGIN
						SELECT @lastValue = Value FROM #Parameters WHERE ParaIdent = 1
						IF (CAST(@tempParameters AS DECIMAL(9, 2)) > CAST(@lastValue AS DECIMAL(9, 2)))
						BEGIN
							SET @conjuncture = ') OR ('
						END
						ELSE
						BEGIN
							SET @conjuncture = ') AND ('
						END
					END
					ELSE IF (@tempParameterType = 'LTValue')
					BEGIN
						SELECT @lastValue = Value FROM #Parameters WHERE ParaIdent = 1
						IF (CAST(@tempParameters AS DECIMAL(9, 2)) < CAST(@lastValue AS DECIMAL(9, 2)))
						BEGIN
							SET @conjuncture = ') OR ('
						END
						ELSE
						BEGIN
							SET @conjuncture = ') AND ('
						END
					
					END
				END
				IF (@columnType = 'DateRangeSQLParameter')
				BEGIN
					IF (ISNUMERIC(@tempParameters) = 1)
					BEGIN
						IF (CAST(@tempParameters AS INT) < 0)
						BEGIN
							SET @endOffsetComparer = ' >= '
							SET @startComparer = ' <= '
						END
						ELSE
						BEGIN
							SET @endOffsetComparer = ' <= '
							SET @startComparer = ' >= '
						END
					END
				END
				IF (@tempParameterType = 'DRMonthEnd')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + @endOffsetComparer + ' CAST(DATEADD(s,-1,DATEADD(mm, DATEDIFF(MONTH,0,GETDATE())+' + @tempParameters + ',0)) AS [Date])'
				END
				IF (@tempParameterType = 'MonthOffset')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + @endOffsetComparer + ' CAST(DATEADD(MONTH, ' + @tempParameters + ', GETDATE()) AS [Date])'
				END				
				IF (@tempParameterType = 'YearOffset')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + @endOffsetComparer + ' CAST(DATEADD(YEAR, ' + @tempParameters + ', GETDATE()) AS [Date])'
				END
				IF (@tempParameterType = 'DayOffset')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + @endOffsetComparer + ' CAST(DATEADD(DAY, ' + @tempParameters + ', GETDATE()) AS [Date])'
				END								
				ELSE IF (@tempParameterType = 'DRStart')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + @startComparer + @tempParameters
				END
				ELSE IF (@tempParameterType = 'DREnd')
				BEGIN
					IF (@tempParameters = '32')
					BEGIN
						SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + ' <= CAST(DATEADD(s, -1, DATEADD(m, DATEDIFF(m, 0, GETDATE())+1, 0)) AS [DATE])'
					END
					ELSE
					BEGIN
						SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + @endOffsetComparer + @tempParameters
					END	
				END			
				ELSE IF (@tempParameterType = 'InMonthOffset')
				BEGIN
					SET @tempStr = 'AND DATEPART(MONTH, ' + @columnName + ') IN (' + CAST(DATEPART(MONTH, GETDATE()) AS NVARCHAR(2))
					IF (@tempParameters > 0)
					BEGIN
						SET @monthOffset = 1
						WHILE (@monthOffset <= @tempParameters)
						BEGIN
							SET @tempStr = @tempStr + ', ' + CAST(DATEPART(MONTH, DATEADD(MONTH, @monthOffset, GETDATE())) AS NVARCHAR(2))
							SET @monthOffset = @monthOffset + 1
						END
						SET @tempStr = @tempStr + ')'
					END
					ELSE
					BEGIN
						SET @monthOffset = -1
						WHILE (@monthOffset >= @tempParameters)
						BEGIN
							SET @tempStr = @tempStr + ', ' + CAST(DATEPART(MONTH, DATEADD(MONTH, @monthOffset, GETDATE())) AS NVARCHAR(2))
							SET @monthOffset = @monthOffset - 1
						END
						SET @tempStr = @tempStr + ')'					
					END
				END
				ELSE IF (@tempParameterType = 'InclusiveSQLParameter')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + ' IN ' + @tempParameters + ' '
				END
				ELSE IF (@tempParameterType = 'GTValue')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + ' > ' + @tempParameters
				END
				ELSE IF (@tempParameterType = 'LTValue')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + ' < ' + @tempParameters
				END
				ELSE IF (@tempParameterType = 'EqValue')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + ' = ' + @tempParameters
				END
				ELSE IF (@tempParameterType = 'GTEqValue')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + ' >= ' + @tempParameters
				END
				ELSE IF (@tempParameterType = 'LTEqValue')
				BEGIN
					SET @tempStr = ISNULL(@tempStr, '') + @conjuncture + @columnName + ' <= ' + @tempParameters
				END																
				--IF ((@paraMaxCtr >= 2) AND (@tempParameterType NOT IN ('LTValue', 'GTValue', 'EqValue')))
				IF (@paraMaxCtr >= 2)
				BEGIN
					IF (@paraCtr >= @paraMaxCtr)
					BEGIN
						SET @tempStr = ISNULL(@tempStr, '') + '))'
					END
					ELSE
					BEGIN
						SET @lastParameterIdentifier = @thisParameterIdentifier
					END
				END
				SET @paraCtr = @paraCtr + 1
			END
			SET @SQLBase = @SQLBase + ' ' + @tempStr + ' '
		END
		SET @ctr = @ctr + 1
		TRUNCATE TABLE #Parameters

	END

END
GO
