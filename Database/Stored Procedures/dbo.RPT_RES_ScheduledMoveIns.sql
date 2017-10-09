SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 28, 2014
-- Description:	Populates some kind of Sheduled Move Ins Report.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_ScheduledMoveIns] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #ScheduledMoveIns (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		LeaseID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		PaddedUnitNumber nvarchar(50) null,
		IsHoldingUnit bit null,
		Residents nvarchar(500) null,
		ApplicationDate date null,
		MoveInDate date null,
		RentCharges money null,
		OtherCharges money null,
		Credits money null,
		MarketRent money null,
		ApprovalDate date null,
		LeaseSignedDate date null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		UnitType nvarchar(250))
		
	INSERT #ScheduledMoveIns
		SELECT	p.PropertyID, p.Name, l.LeaseID, u.UnitID, u.Number, u.PaddedNumber, u.IsHoldingUnit,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Residents',
				(SELECT TOP 1 ApplicationDate
					FROM PersonLease 
					WHERE LeaseID = l.LeaseID
					ORDER BY ApplicationDate),
				pl.MoveInDate,
				null,
				null,
				null,
				null,
				null,
				null,
				l.LeaseStartDate,
				l.LeaseEndDate,
				ut.Name AS 'UnitType'
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID 
										AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																	FROM PersonLease 
																		LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID 
																	WHERE LeaseID = l.LeaseID
																	  --AND MoveInDate >= @startDate
																	  --AND MoveInDate <= @endDate
																	  AND (((@accountingPeriodID IS NULL) AND (MoveInDate >= @startDate) AND (MoveInDate <= @endDate))
																	    OR ((@accountingPeriodID IS NOT NULL) AND (MoveInDate >= pap.StartDate) AND (MoveInDate <= pap.EndDate)))
																	ORDER BY MoveInDate)
			WHERE ulg.AccountID = @accountID
			  AND l.LeaseStatus NOT IN ('Cancelled', 'Denied')
			  AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
																	
	UPDATE #ScheduledMoveIns SET ApprovalDate = (SELECT TOP 1 pn.[Date]
														FROM PersonNote pn
															INNER JOIN PersonLease pl ON pn.PersonID = pl.PersonID
														WHERE pl.LeaseID = #ScheduledMoveIns.LeaseID
														  AND pn.InteractionType = 'Approved'
														  ORDER BY pn.[Date])
																				
	UPDATE #ScheduledMoveIns SET LeaseSignedDate = (SELECT TOP 1 LeaseSignedDate
													FROM PersonLease
													WHERE LeaseID = #ScheduledMoveIns.LeaseID
														AND LeaseSignedDate IS NOT NULL
													ORDER BY LeaseSignedDate)	
												
	UPDATE #ScheduledMoveIns SET RentCharges = ISNULL((SELECT SUM(lli.Amount)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
													WHERE lli.LeaseID = #ScheduledMoveIns.LeaseID
													  AND lli.StartDate <= #ScheduledMoveIns.LeaseEndDate
													  AND lit.IsRent = 1), 0)
													  
	UPDATE #ScheduledMoveIns SET Credits = ISNULL((SELECT SUM(lli.Amount)
												FROM LeaseLedgerItem lli
													INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
													INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
												WHERE lli.LeaseID = #ScheduledMoveIns.LeaseID
												  AND lli.StartDate <= #ScheduledMoveIns.LeaseEndDate
												  AND lit.IsCredit = 1), 0)													  
													  
	UPDATE #ScheduledMoveIns SET OtherCharges = ISNULL((SELECT SUM(lli.Amount)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
													WHERE lli.LeaseID = #ScheduledMoveIns.LeaseID
													  AND lli.StartDate <= #ScheduledMoveIns.LeaseEndDate
													  AND lit.IsRent = 0), 0)												  
											  	
	UPDATE #smi SET MarketRent = MarketRent.Amount
		FROM #ScheduledMoveIns #smi
			CROSS APPLY GetMarketRentByDate(#smi.UnitID, #smi.MoveInDate, 1) AS [MarketRent]	
			
	SELECT * 
		FROM #ScheduledMoveIns
		ORDER BY PropertyName, PaddedUnitNumber
																																									
END
GO
