SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_AFF_UtilityAllowance]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@effectiveDate datetime,
	@propertyIDs GuidCollection READONLY
AS

BEGIN

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null
	)

	CREATE TABLE #UtilityAllowances (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		UnitTypeID uniqueidentifier not null,
		UnitTypeName nvarchar(250) not null,
		Bedrooms int not null,
		Amount money not null,
		[Date] date not null
	)

	INSERT #Properties
		SELECT Value FROM @propertyIDs

	INSERT #UtilityAllowances
		SELECT
			p.PropertyID AS 'PropertyID',
			p.[Name] AS 'PropertyName',
			ut.UnitTypeID AS 'UnitTypeID',
			ut.Name AS 'UnitTypeName',
			ut.Bedrooms AS 'Bedrooms',
			ua.Amount AS 'Amount',
			ua.DateChanged AS 'Date'
		FROM UtilityAllowance ua
			JOIN UnitType ut ON ua.ObjectID = ut.UnitTypeID
			JOIN Property p ON ut.PropertyID = p.PropertyID
			JOIN #Properties #p ON ut.PropertyID = #p.PropertyID
		WHERE ua.AccountID = @accountID
			AND ua.UtilityAllowanceID = (SELECT TOP 1 ua2.UtilityAllowanceID
											FROM UtilityAllowance ua2
											WHERE ua2.ObjectID = ut.UnitTypeID
												AND ua2.ObjectType = 'UnitType'
												AND ua2.DateChanged <= @effectiveDate
											ORDER BY ua2.DateChanged DESC, ua2.DateCreated DESC)

	SELECT *
		FROM #UtilityAllowances
		ORDER BY UnitTypeName
END
GO
