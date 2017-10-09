SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 6, 2011
-- Description:	Finds all InvoiceableObjects
-- =============================================
CREATE PROCEDURE [dbo].[GetWOIAccounts]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@partialName nvarchar(20) = null,
	@WOable bit = 0,
	@invoiceable bit = 0,
	@includeInventoryItems bit = 1,
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SELECT [Unit].UnitID AS ObjectID, 'Unit' AS ObjectType, [Unit].Number AS NAME, [Unit].PetsPermitted as AllowsPets, [Unit].PaddedNumber AS 'PaddedName'
		FROM [Unit]
			INNER JOIN [Building] on [Unit].BuildingID = [Building].BuildingID
		WHERE 
				[Building].PropertyID = @propertyID
			AND [Unit].Number like @partialName
			AND [Unit].IsHoldingUnit = 0
			AND ([Unit].DateRemoved IS NULL OR [Unit].DateRemoved > @date)
			
	UNION
	
	SELECT [Building].BuildingID AS ObjectID, 'Building' AS ObjectType, [Building].Name AS Name, CAST(0 as bit) as AllowsPets, [Building].Name AS 'PaddedName'
		FROM [Building] 
		WHERE 
				[Building].PropertyID = @propertyID
			AND [Building].Name like @partialName
			
	UNION
	
	SELECT [LedgerItem].[LedgerItemID] AS ObjectID, 'Rentable Item' AS ObjectType, [LedgerItem].Description AS Name, CAST(0 as bit) as AllowsPets, [LedgerItem].Description AS 'PaddedName'
		FROM [LedgerItem] 
			INNER JOIN [LedgerItemPool] on [LedgerItem].LedgerItemPoolID = [LedgerItemPool].LedgerItemPoolID
		WHERE 
				[LedgerItemPool].PropertyID = @propertyID
			AND [LedgerItem].[Description] like @partialName
			
	UNION
	
	SELECT [WOITAccount].WOITAccountID AS ObjectID, 'WOIT Account' AS ObjectType, [WOITAccount].[Name] AS Name, CAST(0 as bit) as AllowsPets, [WOITAccount].[Name] AS 'PaddedName'
		FROM [WOITAccount]
		WHERE
				[WOITAccount].PropertyID = @propertyID
			AND [WOITAccount].Name like @partialName
			AND ((@WOable = 1 AND [WOITAccount].IsWorkorderable = 1)
				OR
				((@invoiceable = 1 AND [WOITAccount].IsInvoiceable = 1)))
		
	UNION
	
-- 	We're looking for a WorkOrder-able, but not Invoiceable, list of inventory items.  Those should not be attached to a location.
	SELECT [InventoryItem].InventoryItemID AS [ObjectID], 'Inventory Item' AS [ObjectType], [InventoryItem].[Name] AS [Name], CAST(0 as bit) as AllowsPets, [InventoryItem].[Name] AS 'PaddedName'
		FROM [InventoryItem]
			LEFT JOIN [InventoryItemLocation] ON [InventoryItem].InventoryItemID = [InventoryItemLocation].InventoryItemID
														AND [InventoryItemLocation].EndDate IS NULL
		WHERE 
				[InventoryItem].PropertyID = @propertyID
			AND [InventoryItem].Name like @partialName
			AND [InventoryItem].RetiredDate IS NULL
			AND (((@WOable = 1) AND (@invoiceable = 0) AND (@includeInventoryItems = 1)) AND ([InventoryItem].RetiredDate IS NULL) 
						AND ([InventoryItemLocation].InventoryItemLocationID IS NULL))
						
	UNION
	
-- 	We're looking for a Invoiceable, but NOT WorkOrderable list of inventory items.  It doesn't matter if the item is attached or not.
	SELECT [InventoryItem].InventoryItemID AS [ObjectID], 'Inventory Item' AS [ObjectType], [InventoryItem].[Name] AS [Name], CAST(0 as bit) as AllowsPets, [InventoryItem].[Name] AS 'PaddedName'
		FROM [InventoryItem]
		WHERE 
				[InventoryItem].PropertyID = @propertyID
			AND [InventoryItem].Name like @partialName
			AND [InventoryItem].RetiredDate IS NULL
			AND (((@WOable = 0) AND (@invoiceable = 1) AND (@includeInventoryItems = 1)) AND ([InventoryItem].RetiredDate IS NULL))


END
GO
