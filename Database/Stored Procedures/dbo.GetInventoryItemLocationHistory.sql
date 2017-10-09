SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 29, 2013
-- Description:	Gets the InventoryItemLocation History for a given InventoryItem.
-- =============================================
CREATE PROCEDURE [dbo].[GetInventoryItemLocationHistory] 
	-- Add the parameters for the stored procedure here
	@inventoryItemID uniqueidentifier = null
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SELECT * FROM 

	((SELECT	DISTINCT
			u.UnitID AS 'ObjectID',
			u.Number AS 'ObjectName',
			'Unit' AS 'ObjectType',
			iil.StartDate AS 'StartDate',
			iil.EndDate AS 'EndDate',
			iil.Notes AS 'Notes',
			per.PreferredName + ' ' + per.LastName AS 'TransferredByPersonName',
			ii.PropertyID AS 'PropertyID'
		FROM Unit u
			INNER JOIN InventoryItemLocation iil ON u.UnitID = iil.ObjectID
			INNER JOIN InventoryItem ii ON iil.InventoryItemID = ii.InventoryItemID
			INNER JOIN Person per ON iil.TransferredByPersonID = per.PersonID
		WHERE iil.InventoryItemID = @inventoryItemID
			
	UNION
	
	SELECT	DISTINCT
			b.BuildingID AS 'ObjectID',
			b.Name AS 'ObjectName',
			'Building' AS 'ObjectType',
			iil.StartDate AS 'StartDate',
			iil.EndDate AS 'EndDate',
			iil.Notes AS 'Notes',
			per.PreferredName + ' ' + per.LastName AS 'TransferredByPersonName',
			ii.PropertyID AS 'PropertyID'
		FROM Building b
			INNER JOIN InventoryItemLocation iil ON b.BuildingID = iil.ObjectID
			INNER JOIN InventoryItem ii ON iil.InventoryItemID = ii.InventoryItemID
			INNER JOIN Person per ON iil.TransferredByPersonID = per.PersonID
		WHERE iil.InventoryItemID = @inventoryItemID			
			
	UNION
	
	SELECT	DISTINCT
			woit.WOITAccountID AS 'ObjectID',
			woit.Name AS 'ObjectName',
			'WOIT Account' AS 'ObjectType',
			iil.StartDate AS 'StartDate',
			iil.EndDate AS 'EndDate',
			iil.Notes AS 'Notes',
			per.PreferredName + ' ' + per.LastName AS 'TransferredByPersonName',
			ii.PropertyID AS 'PropertyID'
		FROM WOITAccount woit
			INNER JOIN InventoryItemLocation iil ON woit.WOITAccountID = iil.ObjectID
			INNER JOIN InventoryItem ii ON iil.InventoryItemID = ii.InventoryItemID
			INNER JOIN Person per ON iil.TransferredByPersonID = per.PersonID	
		WHERE iil.InventoryItemID = @inventoryItemID			
			
	UNION

	SELECT	DISTINCT
			iil.ObjectID AS 'ObjectID',
			li.[Description] AS 'ObjectName',
			'Rentable Item' AS 'ObjectType',
			iil.StartDate AS 'StartDate',
			iil.EndDate AS 'EndDate',
			iil.Notes AS 'Notes',
			per.PreferredName + ' ' + per.LastName AS 'TransferredByPersonName',
			ii.PropertyID AS 'PropertyID'
		FROM InventoryItemLocation iil
			INNER JOIN LedgerItem li ON iil.ObjectID = li.LedgerItemID
			INNER JOIN InventoryItem ii ON iil.InventoryItemID = ii.InventoryItemID			
			INNER JOIN Person per ON iil.TransferredByPersonID = per.PersonID	
		WHERE iil.InventoryItemID = @inventoryItemID)) t
	ORDER BY [StartDate] DESC, ISNULL([EndDate],'2999-12-31') DESC 
	
END
GO
