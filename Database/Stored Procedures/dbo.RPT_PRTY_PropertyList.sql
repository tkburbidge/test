SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 21, 2015
-- Description:	Gets some property data
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRTY_PropertyList] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	DISTINCT
			p.PropertyID,
			p.Name,
			p.Abbreviation,
			per.PreferredName + ' ' + per.LastName AS 'ManagerName',
			rper.PreferredName + ' ' + rper.LastName AS 'RegionalManagerName',
			(SELECT COUNT(u.UnitID)
				FROM Unit u
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = p.PropertyID
				WHERE u.ExcludedFromOccupancy = 0
				  AND u.DateRemoved IS NULL) AS 'UnitCount',
			(SELECT COUNT(u.UnitID)
				FROM Unit u
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = p.PropertyID
					CROSS APPLY GetUnitStatusByUnitID(u.UnitID, GETDATE()) [UStatus]
				WHERE [UStatus].[Status] IN ('Model')) AS 'AdminModelUnitCount',
			p.LegalName,
			adder.StreetAddress AS 'Address',
			adder.City AS 'City',
			adder.[State] AS 'State',
			adder.Zip AS 'Zip',
			p.PhoneNumber AS 'Phone',
			p.Fax,
			p.Email,
			p.Website,
			p.TaxID,
			p.Market,
			p.YearBuilt,
			p.DateAcquired,
			p.PurchasePrice,
			p.DateSold,
			p.SellingPrice
		FROM Property p 
			LEFT JOIN Person per ON p.ManagerPersonID = per.PersonID
			LEFT JOIN Person rper ON p.RegionalManagerPersonID = rper.PersonID
			LEFT JOIN [Address] adder ON p.AddressID = adder.AddressID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND p.AccountID = @accountID

END

GO
