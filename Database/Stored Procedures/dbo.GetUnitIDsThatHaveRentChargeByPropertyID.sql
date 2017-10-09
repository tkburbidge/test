SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 10, 2012
-- Description:	Gets a list of UnitIDs that have had a rent charge in a given period
-- =============================================
CREATE PROCEDURE [dbo].[GetUnitIDsThatHaveRentChargeByPropertyID] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Get Vacant UnitIDs
	SELECT DISTINCT t.ObjectID AS 'UnitID'
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
		WHERE t.TransactionDate >= @startDate
		  AND t.TransactionDate <= @endDate
		  AND t.AccountID = @accountID
		  AND t.PropertyID = @propertyID
		  AND tt.[Group] = 'Unit'
		  AND tt.[Name] = 'Charge'
		  AND t.LedgerItemTypeID in (SELECT DISTINCT ut.RentLedgerItemTypeID FROM UnitType ut
											INNER JOIN Unit u ON u.UnitTypeID = ut.UnitTypeID
											INNER JOIN Building b ON u.BuildingID = b.BuildingID
										WHERE b.PropertyID = @propertyID AND b.AccountID = @accountID)
										
	UNION
	
	SELECT DISTINCT ulg.UnitID
		FROM [Transaction] t 
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN [UnitLeaseGroup] ulg ON t.ObjectID = ulg.UnitLeaseGroupID
		WHERE t.TransactionDate >= @startDate
		  AND t.TransactionDate <= @endDate
		  AND t.AccountID = @accountID
		  AND t.PropertyID = @propertyID
		  AND tt.[Group] = 'Lease'
		  AND tt.[Name] = 'Charge'
		  AND t.LedgerItemTypeID in (SELECT DISTINCT ut.RentLedgerItemTypeID FROM UnitType ut
											INNER JOIN Unit u ON u.UnitTypeID = ut.UnitTypeID
											INNER JOIN Building b ON u.BuildingID = b.BuildingID
										WHERE b.PropertyID = @propertyID AND b.AccountID = @accountID)		  
		  
		  
END
GO
