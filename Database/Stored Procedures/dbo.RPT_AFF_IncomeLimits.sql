SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_AFF_IncomeLimits]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@effectiveDate datetime,
	@propertyIDs GuidCollection READONLY
AS

BEGIN

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null
	)

	CREATE TABLE #IncomeLimits (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		AffordableProgramTableID uniqueidentifier not null,
		[Name] nvarchar(50) not null,
		IsHud bit not null,
		EffectiveDate date not null,
		[Percent] money null,
		Value1 money null,
		Value2 money null,
		Value3 money null,
		Value4 money null,
		Value5 money null,
		Value6 money null,
		Value7 money null,
		Value8 money null,
		OrderBy tinyint not null
	)

	INSERT #Properties
		SELECT Value FROM @propertyIDs

	INSERT #IncomeLimits
		SELECT
			g.PropertyID AS 'PropertyID',
			p.[Name] AS 'PropertyName',
			t.AffordableProgramTableID AS 'AffordableProgramTableID',
			g.[Name] AS 'Name',
			g.IsHUD AS 'IsHud',
			t.EffectiveDate AS 'EffectiveDate',
			(CAST(ISNULL(r.[Percent], 0) AS MONEY) / 100) AS 'Percent',
			r.Value1 AS 'Value1',
			r.Value2 AS 'Value2',
			r.Value3 AS 'Value3',
			r.Value4 AS 'Value4',
			r.Value5 AS 'Value5',
			r.Value6 AS 'Value6',
			r.Value7 AS 'Value7',
			r.Value8 AS 'Value8',
			r.OrderBy AS 'OrderBy'
		FROM AffordableProgramTableRow r
			JOIN AffordableProgramTable t ON r.AffordableProgramTableID = t.AffordableProgramTableID
			JOIN AffordableProgramTableGroup g ON t.AffordableProgramTableGroupID = g.AffordableProgramTableGroupID
			JOIN Property p ON g.PropertyID = p.PropertyID
			JOIN #Properties #p ON p.PropertyID = #p.PropertyID
		WHERE r.AccountID = @accountID
			AND t.AffordableProgramTableID = (SELECT TOP 1 t2.AffordableProgramTableID
												FROM AffordableProgramTable t2
												WHERE t2.AffordableProgramTableGroupID = g.AffordableProgramTableGroupID
													AND t2.EffectiveDate <= @effectiveDate
													AND t2.[Type] = 'Income'
												ORDER BY t2.EffectiveDate DESC)
			
	SELECT *
		FROM #IncomeLimits
		ORDER BY PropertyName, EffectiveDate DESC, AffordableProgramTableID, OrderBy
END
GO
