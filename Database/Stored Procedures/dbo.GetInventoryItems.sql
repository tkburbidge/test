SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 29, 2013
-- Description:	Populates the InventoryItem Index Page.
-- =============================================
CREATE PROCEDURE [dbo].[GetInventoryItems] 
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null, 
	@vendorOrGroupID uniqueidentifier = null,
	@objectID uniqueidentifier = null,
	@types GuidCollection READONLY,
	@includeRetired bit = 0,
	@totalCount int OUTPUT,
	@sortBy nvarchar(50) = null,
	@sortOrderIsAsc bit = 1,
	@page int = 0,
	@pageSize int = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #InventoryItems (
		InventoryItemID uniqueidentifier not null,
		Name nvarchar(50) null,
		Category nvarchar(500) null,
		LocationName nvarchar(50) null,
		LocationID uniqueidentifier null,
		LocationObjectType nvarchar(50) null,
		Make nvarchar(50) null,
		Model nvarchar(50) null,
		SerialNumber nvarchar(100) null,
		VendorName nvarchar(100) null,
		VendorID uniqueidentifier null)
		
	CREATE TABLE #InventoryItems2 (
		ID int identity,
		InventoryItemID uniqueidentifier not null,
		Name nvarchar(50) null,
		Category nvarchar(500) null,
		LocationName nvarchar(50) null,
		LocationID uniqueidentifier null,
		LocationObjectType nvarchar(50) null,
		Make nvarchar(50) null,
		Model nvarchar(50) null,
		SerialNumber nvarchar(100) null,
		VendorName nvarchar(100) null,
		VendorID uniqueidentifier null)		

	INSERT #InventoryItems
		SELECT	DISTINCT
				ii.InventoryItemID AS 'InventoryItemID',
				ii.Name AS 'Name',
				pli.Name AS 'Category',
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN u.Number
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
					WHEN (li.LedgerItemID IS NOT NULL) THEN li.[Description]
					ELSE b.Name END AS 'LocationName',
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN u.UnitID
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.WOITAccountID
					WHEN (li.LedgerItemID IS NOT NULL) THEN li.LedgerItemID
					ELSE b.BuildingID END AS 'LocationID',
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN 'Unit'
					WHEN (woit.WOITAccountID IS NOT NULL) THEN 'WOIT Account'
					WHEN (li.LedgerItemID IS NOT NULL) THEN 'Rentable Item'
					WHEN (b.BuildingID IS NOT NULL) THEN 'Building'
					ELSE '' END AS 'LocationObjectType',					
				ii.Make AS 'Make',
				ii.Model AS 'Model',
				ii.SerialNumber AS 'SerialNumber',
				ISNULL(v.CompanyName, vv.CompanyName) AS 'VendorName',
				ISNULL(v.VendorID, vv.VendorID) AS 'VendorID'
			FROM InventoryItem ii
				LEFT JOIN InventoryItemLocation iil ON ii.InventoryItemID = iil.InventoryItemID AND iil.EndDate IS NULL
				INNER JOIN PickListItem pli ON ii.CategoryPickListItemID = pli.PickListItemID
				LEFT JOIN VendorGroupVendor vgv ON ii.VendorID = vgv.VendorID
				LEFT JOIN Vendor v ON vgv.VendorID = v.VendorID
				LEFT JOIN Vendor vv on ii.VendorID = vv.VendorID
				LEFT JOIN Unit u ON iil.ObjectID = u.UnitID AND iil.ObjectType = 'Unit'
				LEFT JOIN Building b ON iil.ObjectID = b.BuildingID AND iil.ObjectType = 'Building'
				LEFT JOIN WOITAccount woit ON iil.ObjectID = woit.WOITAccountID
				LEFT JOIN LedgerItem li ON iil.ObjectID = li.LedgerItemID
			WHERE ii.PropertyID = @propertyID
			  AND (((SELECT COUNT(*) FROM @types) = 0) OR (pli.PickListItemID IN (SELECT Value FROM @types)))
			  AND (@vendorOrGroupID IS NULL OR @vendorOrGroupID = ii.VendorID OR (@vendorOrGroupID = vgv.VendorGroupID AND ii.VendorID = vgv.VendorID))
			  AND ((@objectID IS NULL) OR (iil.ObjectID = @objectID))
			  AND ((ii.RetiredDate IS NULL) OR (@includeRetired = 1))

	INSERT INTO #InventoryItems2
		SELECT * 
			FROM #InventoryItems
		ORDER BY
			CASE WHEN @sortBy = 'Name' AND @sortOrderIsAsc = 1 THEN [Name] END ASC,
			CASE WHEN @sortBy = 'Name' AND @sortOrderIsAsc = 0 THEN [Name] END DESC,
			CASE WHEN @sortBy = 'Category' AND @sortOrderIsAsc = 1 THEN [Category] END ASC,
			CASE WHEN @sortBy = 'Category' AND @sortOrderIsAsc = 0 THEN [Category] END DESC,
			CASE WHEN @sortBy = 'Model' AND @sortOrderIsAsc = 1 THEN [Model] END ASC,
			CASE WHEN @sortBy = 'Model' AND @sortOrderIsAsc = 0 THEN [Model] END DESC,	
			CASE WHEN @sortBy = 'Make' AND @sortOrderIsAsc = 1 THEN [Make] END ASC,
			CASE WHEN @sortBy = 'Make' AND @sortOrderIsAsc = 0 THEN [Make] END DESC,	
			CASE WHEN @sortBy = 'Location' AND @sortOrderIsAsc = 1 THEN [LocationName] END ASC,
			CASE WHEN @sortBy = 'Location' AND @sortOrderIsAsc = 0 THEN [LocationName] END DESC,
			CASE WHEN @sortBy = 'Vendor' AND @sortOrderIsAsc = 1 THEN [VendorName] END ASC,
			CASE WHEN @sortBy = 'Vendor' AND @sortOrderIsAsc = 0 THEN [VendorName] END DESC,
			CASE WHEN @sortBy IS NULL AND @sortOrderIsAsc = 1 THEN [Name] END ASC,
			CASE WHEN @sortBy IS NULL AND @sortOrderIsAsc = 0 THEN [Name] END DESC							 
		  
	SET @totalCount = (SELECT COUNT(*) FROM #InventoryItems)

	SELECT TOP (@pageSize) * FROM 
	(SELECT *, row_number() OVER (ORDER BY ID) AS [rownumber] 
	 FROM #InventoryItems2) AS PagedProspects	 
	WHERE PagedProspects.rownumber > (((@page - 1) * @pageSize))

END
GO
