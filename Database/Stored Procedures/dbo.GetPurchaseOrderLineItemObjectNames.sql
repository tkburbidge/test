SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: July 26, 2012
-- Description:	Get the object names for line items on a purchase order
-- =============================================
CREATE PROCEDURE [dbo].[GetPurchaseOrderLineItemObjectNames]	
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@poID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT 
	   poli.PurchaseOrderLineItemID AS 'LineItemID',
	   CASE
			WHEN poli.ObjectID IS NULL THEN NULL
			WHEN poli.ObjectType = 'Unit' THEN u.Number
			WHEN poli.ObjectType = 'Rentable Item' THEN li.Description
			WHEN poli.ObjectType = 'Building' THEN bld.Name
			WHEN poli.ObjectType = 'WOIT Account' THEN woit.Name
			WHEN poli.ObjectType = 'Inventory Item' THEN ii.Name
	  END AS 'ObjectName'
	FROM PurchaseOrderLineItem poli
	LEFT JOIN [Unit] u on u.UnitID = poli.ObjectID
	LEFT JOIN [Building] bld on bld.BuildingID = poli.ObjectID
	LEFT JOIN [LedgerItem] li ON li.LedgerItemID = poli.ObjectID
	LEFT JOIN [WOITAccount] woit ON woit.WOITAccountID = poli.ObjectID
	LEFT JOIN [InventoryItem] ii ON ii.InventoryItemID = poli.ObjectID
	WHERE poli.AccountID = @accountID
		AND poli.PurchaseOrderID = @poID
	END
GO
