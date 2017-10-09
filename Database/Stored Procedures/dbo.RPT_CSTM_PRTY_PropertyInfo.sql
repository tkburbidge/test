SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 8, 2016
-- Description:	Gets Property crap
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_PRTY_PropertyInfo]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT	p.PropertyID,
			p.Name,
			p.Abbreviation,
			adds.StreetAddress,
			adds.City,
			adds.[State],
			adds.Zip,
			perR.PreferredName + ' ' + perR.LastName AS 'RegionalName',
			perM.PreferredName + ' ' + perM.LastName AS 'ManagerName',
			vend.CompanyName AS 'CompanyName'
		FROM Property p
			INNER JOIN [Address] adds ON p.AddressID = adds.AddressID
			LEFT JOIN Person perR ON p.RegionalManagerPersonID = perR.PersonID
			LEFT JOIN Person perM ON p.ManagerPersonID = perM.PersonID
			LEFT JOIN Vendor vend ON p.ManagementCompanyVendorID = vend.VendorID
		WHERE PropertyID IN (SELECT Value FROM @propertyIDs)


END

GO
