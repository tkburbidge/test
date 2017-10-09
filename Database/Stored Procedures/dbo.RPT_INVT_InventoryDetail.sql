SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Jordan Betteridge
-- Create date: April 3, 2014
-- Description:	
-- =============================================	
CREATE PROCEDURE [dbo].[RPT_INVT_InventoryDetail]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@startDate datetime = null,
	@endDate datetime = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #InventoryDetail
	(
		PropertyName nvarchar(50) not null,
		Category nvarchar(50) not null,
		InventoryItemID uniqueidentifier not null,
		Name nvarchar(50) null,
		ObjectType nvarchar(20) not null,
		ObjectLocation nvarchar(200) not null,
		[Description] nvarchar(200) null,
		Make nvarchar(50) null,
		Model nvarchar(50) null,
		SerialNumber nvarchar(100) null,
		ColorFinish nvarchar(50) null,
		Size nvarchar(30) null,
		WarrantyExpiration date null,
		PurchaseDate date null,
		Vendor nvarchar(200) null,
		GLAccount nvarchar(100) null,
		Cost money null
	)
	
	INSERT INTO #InventoryDetail
	
		SELECT DISTINCT
			p.Name AS 'PropertyName',
			pli.Name AS 'Category',
			ii.InventoryItemID AS 'InventoryItemID',
			ii.Name AS 'Name',
			CASE WHEN iil.ObjectType IS NOT NULL THEN iil.ObjectType
				 ELSE ''
				 END AS 'ObjectType',
			CASE WHEN iil.ObjectType = 'Building' THEN b.Name
				 WHEN iil.ObjectType = 'Rentable Item' THEN li.[Description]
				 WHEN iil.ObjectType = 'Unit' THEN u.Number
				 WHEN iil.ObjectType = 'WOIT Account' THEN wa.Name
				 ELSE ''
				 END AS 'ObjectLocation',
			ii.[Description] AS 'Description',
			ii.Make AS 'Make',
			ii.Model AS 'Model',
			ii.SerialNumber AS 'SerialNumber',
			ii.ColorFinish AS 'ColorFinish',
			ii.Size AS 'Size',
			ii.WarrantyExpirationDate AS 'WarrantyExpiration',
			ii.PuchaseDate AS 'PurchaseDate',
			v.CompanyName AS 'Vendor',
			gla.Number + ' - ' + gla.Name AS 'GLAccount',
			ii.Cost AS 'Cost'
			FROM InventoryItem ii
				INNER JOIN Property p ON ii.PropertyID = p.PropertyID
				INNER JOIN PickListItem pli ON ii.CategoryPickListItemID = pli.PickListItemID
				LEFT JOIN InventoryItemLocation iil ON ii.InventoryItemID = iil.InventoryItemID
				LEFT JOIN Building b ON iil.ObjectID = b.BuildingID
				LEFT JOIN LedgerItem li ON iil.ObjectID = li.LedgerItemID
				LEFT JOIN Unit u ON iil.ObjectID = u.UnitID
				LEFT JOIN WOITAccount wa ON iil.ObjectID = wa.WOITAccountID
				LEFT JOIN Vendor v on ii.VendorID = v.VendorID
				LEFT JOIN GLAccount gla on ii.GLAccountID = gla.GLAccountID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE ii.PropertyID IN (SELECT Value FROM @propertyIDs)
				--AND (ii.PuchaseDate >= @startDate AND ii.PuchaseDate <= @endDate)
				AND (((@accountingPeriodID IS NULL) AND (ii.PuchaseDate >= @startDate) AND (ii.PuchaseDate <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (ii.PuchaseDate >= pap.StartDate) AND (ii.PuchaseDate <= pap.EndDate)))
				AND iil.EndDate IS NULL
				AND ii.RetiredDate IS NULL

	
	SELECT * FROM #InventoryDetail
	
END
GO
