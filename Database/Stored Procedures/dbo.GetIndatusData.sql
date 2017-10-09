SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[GetIndatusData] 
	@accountID bigint = null,
	@reportID nvarchar(50) = null,
	@parameters IntegrationSQLCollection READONLY
AS
DECLARE @propertyID uniqueidentifier
DECLARE @SQLBase nvarchar(MAX)
DECLARE @indatusCompanyID nvarchar(50)
DECLARE @indatusPropertyID nvarchar(50)
DECLARE @indatusListCode nvarchar(50)

BEGIN

	SELECT @propertyID = ipip.PropertyID, @indatusCompanyID = ipip.Value1, @indatusPropertyID = ipip.Value2, @indatusListCode = isql.Value1
		FROM IntegrationSQLReport isql
			INNER JOIN IntegrationPartnerItemProperty ipip ON isql.IntegrationPartnerItemPropertyID = ipip.IntegrationPartnerItemPropertyID
			INNER JOIN IntegrationPartnerItem ipi ON ipip.IntegrationPartnerItemID = ipi.IntegrationPartnerItemID
		WHERE IntegrationSQLReportID = @reportID
		  --AND isql.AccountID = @accountID

	SET @SQLBase = 'SELECT DISTINCT ' +
			CASE 
				WHEN (@indatusCompanyID IS NULL) THEN 'null'
				ELSE '''' + @indatusCompanyID + '''' 
				END + ' AS ''IndatusCompanyID''' + ', ' +
			CASE
				WHEN (@indatusPropertyID IS NULL) THEN 'null'
				ELSE '''' + @indatusPropertyID + ''''
				END + ' AS ''PropertyCode''' + ', ' +
			CASE
				WHEN (@indatusListCode IS NULL) THEN 'null'
				ELSE '''' + @indatusListCode + ''''
				END + ' AS ''ListCode''' + ', ' +	
			'u.Number AS ''Unit'',
			ulg.UnitLeaseGroupID AS ''UnitLeaseGroupID'',
			per.FirstName AS ''FirstName'',
			per.LastName AS ''LastName'',
			per.Email AS ''Email'',
			CASE
				WHEN (per.Phone1Type = ''Mobile'') THEN per.Phone1
				WHEN (per.Phone2Type = ''Mobile'') THEN per.Phone2
				WHEN (per.Phone3Type = ''Mobile'') THEN per.Phone3
				ELSE null END AS ''MobilePhone'',
			CASE
				WHEN (per.Phone1Type = ''Home'') THEN per.Phone1
				WHEN (per.Phone2Type = ''Home'') THEN per.Phone2
				WHEN (per.Phone3Type = ''Home'') THEN per.Phone3
				ELSE null END AS ''HomePhone'',
			CASE
				WHEN (per.Phone1Type = ''Work'') THEN per.Phone1
				WHEN (per.Phone2Type = ''Work'') THEN per.Phone2
				WHEN (per.Phone3Type = ''Work'') THEN per.Phone3
				ELSE null END AS ''OfficePhone''
	FROM Unit u
		INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON u.BuildingID = b.BuildingID
		INNER JOIN Property p ON b.PropertyID = p.PropertyID
		INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID 
		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
																					  FROM PersonLease pl2
																					  INNER JOIN Ordering o ON o.[Type] = ''ResidencyStatus'' AND Value = pl2.ResidencyStatus
																					  WHERE pl2.PersonID = pl.PersonID
																					  ORDER BY o.OrderBy)
		INNER JOIN Person per ON pl.PersonID = per.PersonID'
		
	IF (0 < (SELECT COUNT(*) FROM @parameters))
	BEGIN
		EXEC SubstituteManualIntegrationSQLParameters @accountID, @propertyID, @reportID, @parameters, @SQLBase OUTPUT
	END
	ELSE
	BEGIN
		EXEC SubstituteIntegrationSQLParameters @accountID, @propertyID, @reportID, @SQLBase OUTPUT
	END
	
	--SELECT @SQLBase
		
	EXECUTE sp_executesql @SQLBase

END
GO
