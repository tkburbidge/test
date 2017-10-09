SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 1, 2016
-- Description:	Gets the data to populate the Project Unit Expense Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_UNT_ProjectExpense] 
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null, 
	@projectID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #ProjectExpenses (
		PropertyID uniqueidentifier null,
		PropertyName nvarchar(50) null,
		UnitID uniqueidentifier null,
		UnitNumber nvarchar(25) null,
		StartDate date null,								-- I believe this is calculated based on the earliest reported date of the work orders associated with this unit and project
		EndDate date null,									-- I believe this is ProjectLocation.CompletedDate
		PreviousMarketRent money null,						-- the market rent charge in effect as of the start date of the project location, 
		PreviousRent money null,							-- Get the last lease where the lease start date is less than the project location start date and the lease status is Current, Under Eviction, Former, or Evicted and sum the rent charges that were in effect on the start date of the lease
		NewRent money null,									-- Get the first lease that starts after the project location end date, and same as above
		NewMarketRent money null,							-- Market rent in effect on the project end date
		SquareFeet int null,								-- Unit Square Feet
		Expenses money null,								-- The sum of the invoices tied to this project and unit.  You will need to use the InvoiceAssociation table where the ObjectID is the ProjectID
		OldLeaseID uniqueidentifier null,
		NewLeaseID uniqueidentifier null,
		PaddedUnitNumber nvarchar(100) null,
		)

	CREATE TABLE #UnitsAndLeases (
		UnitID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		LeaseStartDate date null)

	INSERT #ProjectExpenses
		SELECT	prop.PropertyID,
				prop.Name,
				u.UnitID,
				u.Number,
				null,
				pl.CompletedDate,
				null,
				null,
				null,
				null,
				COALESCE(u.SquareFootage, ut.SquareFootage),
				null,
				null,
				null,
				u.PaddedNumber as 'PaddedUnitNumber'
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property prop ON ut.PropertyID = prop.PropertyID AND prop.PropertyID = @propertyID
				INNER JOIN ProjectLocation pl ON u.UnitID = pl.ObjectID
			WHERE pl.ProjectID = @projectID
			  AND pl.PropertyID = @propertyID

	UPDATE #ProjectExpenses SET StartDate = (SELECT MIN(wo.ReportedDate)
												FROM WorkOrder wo 
													INNER JOIN WorkOrderAssociation woAss ON wo.WorkOrderID = woAss.WorkOrderID AND woAss.ObjectID = @projectID
												WHERE wo.PropertyID = @propertyID
												  AND wo.ObjectID = #ProjectExpenses.UnitID)
	UPDATE #ProjectExpenses SET StartDate = (SELECT p.StartDate
											 FROM Project p 
											 WHERE p.ProjectID = @projectID)
	WHERE StartDate IS NULL
	--UPDATE #ProjectExpenses SET EndDate = (SELECT pl.CompletedDate
	--										   FROM ProjectLocation pl
	--										   WHERE pl.ProjectID = @projectID
	--										     AND pl.ObjectID = #ProjectExpenses.UnitID)


	INSERT #UnitsAndLeases
		SELECT #pe.UnitID, [LeaseGarbage].UnitLeaseGroupID, [LeaseGarbage].LeaseID, [LeaseGarbage].LeaseStartDate
			FROM #ProjectExpenses #pe
				LEFT JOIN	(SELECT ulg.UnitID, ulg.UnitLeaseGroupID, l.LeaseID, l.LeaseStartDate
								FROM UnitLeaseGroup ulg
									INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
								WHERE l.LeaseStatus IN ('Current', 'Renewed', 'Under Eviction', 'Evicted', 'Former')) [LeaseGarbage] ON #pe.UnitID = [LeaseGarbage].UnitID

	UPDATE #ProjectExpenses SET OldLeaseID = (SELECT TOP 1 LeaseID
												  FROM #UnitsAndLeases 
												  WHERE UnitID = #ProjectExpenses.UnitID
													AND LeaseStartDate < #ProjectExpenses.StartDate
												  ORDER BY LeaseStartDate DESC)

	UPDATE #ProjectExpenses SET NewLeaseID = (SELECT TOP 1 LeaseID
												  FROM #UnitsAndLeases 
												  WHERE UnitID = #ProjectExpenses.UnitID
													AND LeaseStartDate > #ProjectExpenses.EndDate
												  ORDER BY LeaseStartDate)

	UPDATE #ProjectExpenses SET PreviousRent = (SELECT SUM(lli.Amount)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
														INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
													WHERE lli.LeaseID = #ProjectExpenses.OldLeaseID
														AND lli.StartDate <= l.LeaseStartDate
														AND lli.EndDate >= l.LeaseStartDate)

	UPDATE #ProjectExpenses SET NewRent = (SELECT SUM(lli.Amount)
												FROM LeaseLedgerItem lli
													INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
													INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
													INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
												WHERE lli.LeaseID = #ProjectExpenses.NewLeaseID
														AND lli.StartDate <= l.LeaseStartDate
														AND lli.EndDate >= l.LeaseStartDate)

	UPDATE #ProjectExpenses SET PreviousMarketRent = (SELECT [MarketStart].Amount
														  FROM dbo.GetMarketRentByDate(#ProjectExpenses.UnitID, #ProjectExpenses.StartDate, 1) [MarketStart])

	UPDATE #ProjectExpenses SET NewMarketRent = (SELECT [MarketEnd].Amount
													  FROM dbo.GetMarketRentByDate(#ProjectExpenses.UnitID, #ProjectExpenses.EndDate, 1) [MarketEnd])

	UPDATE #ProjectExpenses SET Expenses = (SELECT COALESCE(SUM(t.Amount), 0.00)
												FROM [Transaction] t
													INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID
													INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID
													INNER JOIN InvoiceAssociation ia ON i.InvoiceID = ia.InvoiceID AND ia.ObjectID = @projectID
													LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
												WHERE tr.TransactionID IS NULL
												  AND ili.ObjectID = UnitID)											

	SELECT *
		FROM #ProjectExpenses
		ORDER BY PaddedUnitNumber

END
GO
