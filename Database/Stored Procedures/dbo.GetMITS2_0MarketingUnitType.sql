SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 12, 2013
-- Description:	Gets the MITS V2.0 UnitTypes
-- =============================================
CREATE PROCEDURE [dbo].[GetMITS2_0MarketingUnitType] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@date date = null,
	@filterForOnlineMarketing bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	ut.UnitTypeID AS 'UnitTypeID',
			ut.Name AS 'Name',
			ut.[Description] AS 'Description',
			ut.SquareFootage AS 'SquareFootage',
			ut.Bedrooms AS 'Bedrooms',
			ut.Bathrooms AS 'Bathrooms',
			ut.RequiredDeposit AS 'RequiredDeposit',
			lit.Name AS 'RequiredDepositLedgerItemTypeName',			
			ISNULL((SELECT TOP 1 ISNULL(Amount, 0) FROM GetLatestMarketRentByUnitTypeID(ut.UnitTypeID, @date) ORDER BY DateEntered DESC), 0) AS 'MarketRent',
			d.Uri AS 'FloorplanImageUri',
			d.Name AS 'FloorplanImageName',
			ut.MarketingDescription AS 'MarketingDescription'		
		FROM UnitType ut
			INNER JOIN LedgerItemType lit ON ut.DepositLedgerItemTypeID = lit.LedgerItemTypeID		
			LEFT JOIN Document d ON d.ObjectID = ut.UnitTypeID AND d.[Type] = 'MainMarketingImage'
		WHERE ut.PropertyID = @propertyID
			AND ((@filterForOnlineMarketing = 0) OR (@filterForOnlineMarketing = 1 AND  ut.AvailableForOnlineMarketing = 1))
		 
END
GO
