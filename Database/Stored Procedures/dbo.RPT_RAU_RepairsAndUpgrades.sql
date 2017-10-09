SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Jordan Betteridge
-- Create date: February 13, 2014
-- Description:	Gets detailed information about
--              Repairs and Upgrades within a given date range
-- =============================================	
CREATE PROCEDURE [dbo].[RPT_RAU_RepairsAndUpgrades]
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
	
	CREATE TABLE #RepairsAndUpgrades
	(
		RepairAndUpgradeID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		[Type] nvarchar(50) not null,
		ObjectType nvarchar(20) not null,
		ObjectLocation nvarchar(200) null,
		[Date] date null,
		UnitTypeOrRentableItemTypeName nvarchar(250) null,
		Make nvarchar(50) null,
		Model nvarchar(50) null,
		WarrantyExpiration date null,
		LifeExpectancy int null,
		Notes nvarchar(max) null,
		Areas nvarchar(max) null,
		Vendor nvarchar(200) null,
		GLAccount nvarchar(100) null,
		Cost money null,
		Supervisor nvarchar(250) null,
		Color nvarchar(50) null,
		PadHeight nvarchar(50) null,
		PadWeight nvarchar (50) null
	)
	
	INSERT INTO #RepairsAndUpgrades
	
		-- Buildings
		SELECT DISTINCT
			ru.RepairAndUpgradeID AS 'RepairAndUpgradeID',
			p.Name AS 'PropertyName',
			pli.Name AS 'Type',
			ru.ObjectType AS 'ObjectType',
			b.Name AS 'ObjectLocation',
			ru.[Date] AS 'Date',
			null,
			ru.Make AS 'Make',
			ru.Model AS 'Model',
			ru.WarrantyExpirationDate AS 'WarrantyExpiration',
			ru.LifeExpectancy AS 'LifeExpectancy',
			ru.Notes AS 'Notes',
			(SELECT STUFF((SELECT ', ' + pli.Name
				FROM PickListItem pli
					INNER JOIN RepairAndUpgradeArea rua ON ru.RepairAndUpgradeID = rua.RepairAndUpgradeID
				WHERE rua.AreaPickListItemID = pli.PickListItemID
				FOR XML PATH ('')), 1, 2, '')) AS 'Areas',
			v.CompanyName AS 'Vendor',
			gla.Number + ' - ' + gla.Name AS 'GLAccount',
			ru.Cost AS 'Cost',
			per.PreferredName + ' ' + per.LastName AS 'Supervisor',
			ru.Color AS 'Color',
			ru.PadHeight AS 'PadHeight',
			ru.PadWeight AS 'PadWeight'
			FROM RepairAndUpgrade ru
				INNER JOIN Property p ON ru.PropertyID = p.PropertyID
				INNER JOIN PickListItem pli ON ru.TypePickListItemID = pli.PickListItemID
				INNER JOIN Building b ON ru.ObjectID = b.BuildingID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				LEFT JOIN Vendor v on ru.VendorID = v.VendorID
				LEFT JOIN GLAccount gla on ru.GLAccountID = gla.GLAccountID
				LEFT JOIN Person per on ru.SupervisorPersonID = per.PersonID
			WHERE ru.PropertyID IN (SELECT Value FROM @propertyIDs)
				--AND (ru.[Date] >= @startDate AND ru.[Date] <= @endDate)
				AND (((@accountingPeriodID IS NULL) AND (ru.[Date] >= @startDate) AND (ru.[Date] <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (ru.[Date] >= pap.StartDate) AND (ru.[Date] <= pap.EndDate)))
				AND ru.ObjectType = 'Building'
				
		UNION ALL
		
		-- Rentable Items
		SELECT DISTINCT
			ru.RepairAndUpgradeID AS 'RepairAndUpgradeID',
			p.Name AS 'PropertyName',
			pli.Name AS 'Type',
			ru.ObjectType AS 'ObjectType',
			li.[Description] AS 'ObjectLocation',
			ru.[Date] AS 'Date',
			lip.Name AS 'UnitTypeOrRentableItemTypeName',
			ru.Make AS 'Make',
			ru.Model AS 'Model',
			ru.WarrantyExpirationDate AS 'WarrantyExpiration',
			ru.LifeExpectancy AS 'LifeExpectancy',
			ru.Notes AS 'Notes',
			(SELECT STUFF((SELECT ', ' + pli.Name
				FROM PickListItem pli
					INNER JOIN RepairAndUpgradeArea rua ON ru.RepairAndUpgradeID = rua.RepairAndUpgradeID
				WHERE rua.AreaPickListItemID = pli.PickListItemID
				FOR XML PATH ('')), 1, 2, '')) AS 'Areas',
			v.CompanyName AS 'Vendor',
			gla.Number + ' - ' + gla.Name AS 'GLAccount',
			ru.Cost AS 'Cost',
			per.PreferredName + ' ' + per.LastName AS 'Supervisor',
			ru.Color AS 'Color',
			ru.PadHeight AS 'PadHeight',
			ru.PadWeight AS 'PadWeight'
			FROM RepairAndUpgrade ru
				INNER JOIN Property p ON ru.PropertyID = p.PropertyID
				INNER JOIN PickListItem pli ON ru.TypePickListItemID = pli.PickListItemID
				INNER JOIN LedgerItem li ON ru.ObjectID = li.LedgerItemID
				INNER JOIN LedgerItemPool lip ON li.LedgerItemPoolID = lip.LedgerItemPoolID
				LEFT JOIN Vendor v on ru.VendorID = v.VendorID
				LEFT JOIN GLAccount gla on ru.GLAccountID = gla.GLAccountID
				LEFT JOIN Person per on ru.SupervisorPersonID = per.PersonID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE ru.PropertyID IN (SELECT Value FROM @propertyIDs)
				--AND (ru.[Date] >= @startDate AND ru.[Date] <= @endDate)
				AND (((@accountingPeriodID IS NULL) AND (ru.[Date] >= @startDate) AND (ru.[Date] <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (ru.[Date] >= pap.StartDate) AND (ru.[Date] <= pap.EndDate)))				
				AND ru.ObjectType = 'RentableItem'
					
		UNION ALL
		
		-- Units
		SELECT DISTINCT
			ru.RepairAndUpgradeID AS 'RepairAndUpgradeID',
			p.Name AS 'PropertyName',
			pli.Name AS 'Type',
			ru.ObjectType AS 'ObjectType',
			u.Number AS 'ObjectLocation',
			ru.[Date] AS 'Date',
			ut.Name AS 'UnitTypeOrRentableItemTypeName',
			ru.Make AS 'Make',
			ru.Model AS 'Model',
			ru.WarrantyExpirationDate AS 'WarrantyExpiration',
			ru.LifeExpectancy AS 'LifeExpectancy',
			ru.Notes AS 'Notes',
			(SELECT STUFF((SELECT ', ' + pli.Name
				FROM PickListItem pli
					INNER JOIN RepairAndUpgradeArea rua ON ru.RepairAndUpgradeID = rua.RepairAndUpgradeID
				WHERE rua.AreaPickListItemID = pli.PickListItemID
				FOR XML PATH ('')), 1, 2, '')) AS 'Areas',
			v.CompanyName AS 'Vendor',
			gla.Number + ' - ' + gla.Name AS 'GLAccount',
			ru.Cost AS 'Cost',
			per.PreferredName + ' ' + per.LastName AS 'Supervisor',
			ru.Color AS 'Color',
			ru.PadHeight AS 'PadHeight',
			ru.PadWeight AS 'PadWeight'
			FROM RepairAndUpgrade ru
				INNER JOIN Property p ON ru.PropertyID = p.PropertyID
				INNER JOIN PickListItem pli ON ru.TypePickListItemID = pli.PickListItemID
				INNER JOIN Unit u ON ru.ObjectID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				LEFT JOIN Vendor v on ru.VendorID = v.VendorID
				LEFT JOIN GLAccount gla on ru.GLAccountID = gla.GLAccountID
				LEFT JOIN Person per on ru.SupervisorPersonID = per.PersonID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE ru.PropertyID IN (SELECT Value FROM @propertyIDs)
				--AND (ru.[Date] >= @startDate AND ru.[Date] <= @endDate)
				AND (((@accountingPeriodID IS NULL) AND (ru.[Date] >= @startDate) AND (ru.[Date] <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (ru.[Date] >= pap.StartDate) AND (ru.[Date] <= pap.EndDate)))				
				AND ru.ObjectType = 'Unit'
					
		UNION ALL
		
		-- WOIT Accounts
		SELECT DISTINCT
			ru.RepairAndUpgradeID AS 'RepairAndUpgradeID',
			p.Name AS 'PropertyName',
			pli.Name AS 'Type',
			ru.ObjectType AS 'ObjectType',
			wa.Name AS 'ObjectLocation',
			ru.[Date] AS 'Date',
			null,
			ru.Make AS 'Make',
			ru.Model AS 'Model',
			ru.WarrantyExpirationDate AS 'WarrantyExpiration',
			ru.LifeExpectancy AS 'LifeExpectancy',
			ru.Notes AS 'Notes',
			(SELECT STUFF((SELECT ', ' + pli.Name
				FROM PickListItem pli
					INNER JOIN RepairAndUpgradeArea rua ON ru.RepairAndUpgradeID = rua.RepairAndUpgradeID
				WHERE rua.AreaPickListItemID = pli.PickListItemID
				FOR XML PATH ('')), 1, 2, '')) AS 'Areas',
			v.CompanyName AS 'Vendor',
			gla.Number + ' - ' + gla.Name AS 'GLAccount',
			ru.Cost AS 'Cost',
			per.PreferredName + ' ' + per.LastName AS 'Supervisor',
			ru.Color AS 'Color',
			ru.PadHeight AS 'PadHeight',
			ru.PadWeight AS 'PadWeight'
			FROM RepairAndUpgrade ru
				INNER JOIN Property p ON ru.PropertyID = p.PropertyID
				INNER JOIN PickListItem pli ON ru.TypePickListItemID = pli.PickListItemID
				INNER JOIN WOITAccount wa ON ru.ObjectID = wa.WOITAccountID
				LEFT JOIN Vendor v on ru.VendorID = v.VendorID
				LEFT JOIN GLAccount gla on ru.GLAccountID = gla.GLAccountID
				LEFT JOIN Person per on ru.SupervisorPersonID = per.PersonID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE ru.PropertyID IN (SELECT Value FROM @propertyIDs)
				--AND (ru.[Date] >= @startDate AND ru.[Date] <= @endDate)
				AND (((@accountingPeriodID IS NULL) AND (ru.[Date] >= @startDate) AND (ru.[Date] <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (ru.[Date] >= pap.StartDate) AND (ru.[Date] <= pap.EndDate)))				
				AND ru.ObjectType = 'WOITAccount'
	
	SELECT * FROM #RepairsAndUpgrades
	
END



GO
