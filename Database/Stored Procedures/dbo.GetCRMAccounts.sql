SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetCRMAccounts] 
	-- Add the parameters for the stored procedure here
	@appInfoDateLastRun datetime = null 
AS
BEGIN
	
	SELECT s.AccountID,
		s.CompanyName,
		s.CompanyEmailAddress,
		s.Subdomain,
		d.Uri AS 'LogoUrl',
		DB_NAME() AS 'Database',
		@@SERVERNAME AS 'Server'
	FROM Settings s
	LEFT JOIN Document d ON d.AccountID = s.AccountID AND [Type] = 'CompanyLogo'

	SELECT 
		p.PropertyID,
		p.AccountID,
		p.Name,
		p.Abbreviation,
		p.PropertyType,
		(SELECT COUNT(*) 
		 FROM Unit u 
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
		 WHERE b.PropertyID = p.PropertyID
			AND u.IsHoldingUnit = 0) AS 'UnitCount',
		(SELECT COUNT(*) 
		 FROM Unit u 
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
		 WHERE b.PropertyID = p.PropertyID
			AND u.IsHoldingUnit = 1) AS 'HoldingUnitCount',
		(SELECT COUNT(*) 
		 FROM Unit u 
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
		 WHERE b.PropertyID = p.PropertyID
			AND u.ExcludedFromOccupancy = 1) AS 'ExcludedFromOccupancyUnitCount',
		(SELECT TOP 1 t.Timestamp
		 FROM [Transaction] t
		 WHERE t.PropertyID = p.PropertyID
		 	AND t.Origin <> 'R'
		 ORDER BY t.Timestamp Desc) AS 'LastTransactionTimestamp',
		 a.[StreetAddress],
		 a.City,
		 a.Zip,
		 a.[State],
		 p.InternalPropertyID,
		 p.IsArchived
	FROM Property p
	LEFT JOIN [Address] a ON a.AddressID = p.AddressID
		--LEFT JOIN IntegrationPartnerItemProperty ipipGT ON ipipGT.PropertyID = p.PropertyID and ipipGT.IntegrationPartnerItemID =	139	-- Google Translate Integrated
		--LEFT JOIN IntegrationPartnerItemProperty ipipT ON ipipT.PropertyID = p.PropertyID and ipipT.IntegrationPartnerItemID =	123	-- Twilio Integrated

	SELECT DISTINCT
		ipip.PropertyID,
		ipi.IntegrationPartnerID
	FROM IntegrationPartnerItemProperty ipip
	INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID
	INNER JOIN IntegrationPartner ip ON ip.IntegrationPartnerID = ipi.IntegrationPartnerID
	WHERE ip.IntegrationPartnerID < 4000

	SELECT
		ai.AccountID,
		ai.PropertyID,
		ai.ApplicantInformationID,
		ai.DateCreated,
		ai.CurrentStep,
		ai.LeaseEnvelopeID
	FROM ApplicantInformation ai
	WHERE ai.DateCreated > @appInfoDateLastRun
	  AND ai.CurrentStep IS NOT NULL

END

GO
