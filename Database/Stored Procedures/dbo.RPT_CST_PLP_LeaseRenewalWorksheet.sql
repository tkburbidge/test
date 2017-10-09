SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 9, 2014
-- Description:	Gets the data for PLPs Renewal Lease Worksheet
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_PLP_LeaseRenewalWorksheet] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
     
        
    CREATE TABLE #WorkSheetInfo (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		UnitID uniqueidentifier not null,		
		UnitNumber nvarchar(50) not null,
		PaddedUnitNumber nvarchar(50) not null,
		UnitType nvarchar(50) not null,
		LeaseEndDate date not null,
		LeaseID uniqueidentifier not null,
		CurrentRent money null,
		MarketRent money null, 
		MonthToMonthFee money null,
		MoveOutDate date null,
		RenewalSigned bit null,
		RenewalStartDate date null,
		RenewalEndDate date null,
		RenewalRent money null,
		RenewalLeaseID uniqueidentifier null,
		LeaseTerm nvarchar(20) null,
		MonthToMonthRent money null)
		
	INSERT INTO #WorkSheetInfo
		SELECT	DISTINCT
				p.PropertyID,
				p.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				ut.Name,
				l.LeaseEndDate,
				l.LeaseID,
				null,
				null, 
				p.MonthToMonthFee,
				null,
				0,
				null,
				null,
				null,
				null,
				null,
				null
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID	= ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
			WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
			  AND l.LeaseEndDate <= @endDate
			  --AND l.LeaseEndDate >= @startDate
		
	UPDATE #WorkSheetInfo SET CurrentRent = (SELECT SUM(lli.Amount)
												FROM LeaseLedgerItem lli
													INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
													INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
												WHERE lli.StartDate <= #WorkSheetInfo.LeaseEndDate
												  AND lli.LeaseID = #WorkSheetInfo.LeaseID
												  AND lit.IsRent = 1)
												  
	--UPDATE #WorkSheetInfo SET CurrentRent = CurrentRent - (SELECT ISNULL(SUM(lli.Amount), 0)
	--															FROM LeaseLedgerItem lli
	--																INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
	--																INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
	--															WHERE lli.EndDate <= #WorkSheetInfo.LeaseEndDate
	--															  AND lli.LeaseID = #WorkSheetInfo.LeaseID
	--															  AND lit.IsRecurringMonthlyRentConcession = 1)												  
			
	UPDATE #WorkSheetInfo SET MarketRent = (SELECT MarRent.Amount
												FROM GetMarketRentByDate(#WorkSheetInfo.UnitID, @endDate, 1) AS [MarRent])
									
	UPDATE #WorkSheetInfo SET MoveOutDate = (SELECT TOP 1 pl.MoveOutDate
												FROM PersonLease pl
													LEFT JOIN PersonLease plMONull ON #WorkSheetInfo.LeaseID = plMONull.LeaseID
																		AND plMONull.MoveOutDate IS NULL
												WHERE pl.LeaseID = #WorkSheetInfo.LeaseID
												  AND plMONull.PersonLeaseID IS NULL
												ORDER BY pl.MoveOutDate DESC)
												
	UPDATE #WorkSheetInfo SET
		RenewalLeaseID = (SELECT TOP 1 newL.LeaseID
							  FROM Lease newL
								  INNER JOIN UnitLeaseGroup ulg ON newL.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								  INNER JOIN Lease oldL ON ulg.UnitLeaseGroupID = oldL.UnitLeaseGroupID
								  LEFT JOIN PersonLease newPLSigned ON newL.LeaseID = newPLSigned.LeaseID 
																				AND newPLSigned.LeaseSignedDate IS NOT NULL
							  WHERE oldL.LeaseID = #WorkSheetInfo.LeaseID		
							    AND newL.LeaseStatus IN ('Pending Renewal')
							    AND newPLSigned.PersonLeaseID IS NOT NULL)
							    
	UPDATE #wsi SET RenewalStartDate = newL.LeaseStartDate, RenewalEndDate = newL.LeaseEndDate, RenewalSigned = 1
		FROM #WorkSheetInfo #wsi 
			INNER JOIN Lease newL ON #wsi.RenewalLeaseID = newL.LeaseID
		WHERE #wsi.RenewalLeaseID IS NOT NULL
			
		
	UPDATE #WorkSheetInfo SET RenewalRent = (SELECT SUM(lli.Amount)
												FROM LeaseLedgerItem lli
													INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
													INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
												WHERE lli.StartDate <= #WorkSheetInfo.RenewalEndDate
												  AND lli.LeaseID = #WorkSheetInfo.RenewalLeaseID
												  AND lit.IsRent = 1)
												  
	--UPDATE #WorkSheetInfo SET RenewalRent = RenewalRent - (SELECT ISNULL(SUM(lli.Amount), 0)
	--															FROM LeaseLedgerItem lli
	--																INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
	--																INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
	--															WHERE lli.EndDate <= #WorkSheetInfo.RenewalEndDate
	--															  AND lli.LeaseID = #WorkSheetInfo.RenewalLeaseID
	--															  AND lit.IsRecurringMonthlyRentConcession = 1)												  
			

	UPDATE #WorkSheetInfo SET MonthToMonthRent = (SELECT ISNULL(SUM(ISNULL(lli.Amount, 0)), 0)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
														INNER JOIN Settings s ON s.AccountID = lli.AccountID
													WHERE lli.StartDate > #WorkSheetInfo.LeaseEndDate
													  AND lli.LeaseID = #WorkSheetInfo.LeaseID
													  AND (lit.IsRent = 1 OR lit.LedgerItemTypeID = s.MonthToMonthFeeLedgerItemTypeID))
	
	UPDATE #WorkSheetInfo SET LeaseTerm = CASE WHEN (#WorkSheetInfo.LeaseEndDate >= @startDate AND #WorkSheetInfo.MoveOutDate IS NOT NULL)
													THEN 'Move Out'
											   WHEN ((#WorkSheetInfo.LeaseEndDate < @startDate AND #WorkSheetInfo.RenewalLeaseID IS NULL)
														OR (#WorkSheetInfo.RenewalLeaseID IS NOT NULL AND #WorkSheetInfo.RenewalSigned = 0))
													THEN 'MTM'
											   WHEN (#WorkSheetInfo.RenewalSigned = 1)
													THEN 'Lease Term Months'
											   ELSE '' END

	
	SELECT * FROM #WorkSheetInfo
		ORDER BY PropertyName, PaddedUnitNumber

END
GO
