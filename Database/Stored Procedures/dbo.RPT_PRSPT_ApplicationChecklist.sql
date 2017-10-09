SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 17, 2014
-- Description:	Gets the information for the Application Checklist Report.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_ApplicationChecklist] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@employeeIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #CzechList (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		LeaseID uniqueidentifier not null,
		UnitLeaseGroupID uniqueidentifier not null,
		MoveInDate date null,
		UnitNumber nvarchar(20) null,
		PaddedNumber nvarchar(20) null,
		ApplicationDate date null,
		ApplicationFeePaidDate date null,
		SecurityDepositPaidDate date null,
		RecurringRentCharge money null,
		Special money null,
		ConcessionPeriod int null,
		LeaseEndDate date null,
		RecurringConcessionEndDate date null,
		ScreenResidentDate date null,
		ApprovedDate date null,		
		LeaseSent date null,
		LeaseSignedDate date null,
		RentersInsuranceExpDate date null,
		DeniedPersonsOnLease int null,
		ApprovedPersonsOnLease int null,
		Residents nvarchar(500) null)
		
	INSERT #CzechList
		SELECT	p.PropertyID,
				p.Name AS 'PropertyName',
				l.LeaseID, 
				l.UnitLeaseGroupID, 
				(SELECT TOP 1 MoveInDate FROM PersonLease WHERE LeaseID = l.LeaseID ORDER BY MoveInDate), 
				u.Number, 
				u.PaddedNumber,
				(SELECT TOP 1 ApplicationDate FROM PersonLease WHERE LeaseID = l.LeaseID ORDER BY ApplicationDate DESC), 
				null, 
				null, 
				null, 
				null, 
				null, 
				l.LeaseEndDate, 
				null, 
				null, 
				null,
				null, 
				null, 
				null, 
				0, 
				0,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Residents'				
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b on u.BuildingID = b.BuildingID
				INNER JOIN Property p on b.PropertyID = p.PropertyID
			WHERE b.PropertyID IN (SELECT Value FROM @propertyIDs)
				AND l.LeaseStatus IN ('Pending')
				AND ((SELECT COUNT(*) FROM @employeeIDs) = 0
				  OR (l.LeasingAgentPersonID IN (SELECT Value FROM @employeeIDs)))
			
	UPDATE #CzechList SET ApplicationFeePaidDate = (SELECT TOP 1 pay.[Date]
														FROM [Transaction] ta
															INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
															INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
															INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
															INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
															INNER JOIN ApplicantType at ON at.PropertyID = #CzechList.PropertyID
															INNER JOIN ApplicantTypeApplicationFee ataf ON lit.LedgerItemTypeID = ataf.LedgerItemTypeID
																								AND at.ApplicantTypeID = ataf.ApplicantTypeID
															LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
														WHERE t.ObjectID = #CzechList.UnitLeaseGroupID
														  AND tar.TransactionID IS NULL
														ORDER BY pay.[Date])



	UPDATE #CzechList SET SecurityDepositPaidDate = (SELECT TOP 1 pay.[Date]
														FROM [Transaction] t 
															INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
															INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
															INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
															INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
															LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
														WHERE t.ObjectID = #CzechList.UnitLeaseGroupID
														  AND tt.Name = 'Deposit' AND tt.[Group] = 'Lease'
														  AND lit.IsDeposit = 1
														  AND tr.TransactionID IS NULL
														ORDER BY pay.[Date])
														
	UPDATE #CzechList SET RecurringRentCharge = (SELECT SUM(lli.Amount)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
													WHERE lli.LeaseID = #CzechList.LeaseID
													  AND lli.StartDate <= #CzechList.LeaseEndDate
													  AND lit.IsRent = 1)
													  
	UPDATE #CzechList SET Special = (SELECT SUM(lli.Amount)
										FROM LeaseLedgerItem lli
											INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
											INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
										WHERE lli.LeaseID = #CzechList.LeaseID
										  AND lli.StartDate <= #CzechList.LeaseEndDate
										  AND lit.IsRecurringMonthlyRentConcession = 1)		
										  
	--UPDATE #CzechList SET RecurringConcessionEndDate = (SELECT TOP 1 lli.EndDate
	--														FROM LeaseLedgerItem lli
	--															INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
	--															INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
	--														WHERE lli.LeaseID = #CzechList.LeaseID
	--														  AND lli.EndDate >= GETDATE()
	--														  AND lit.IsRecurringMonthlyRentConcession = 1
	--														ORDER BY lli.EndDate DESC)
										  										  
	--UPDATE #CzechList SET ConcessionPeriod = 99
	--	WHERE RecurringConcessionEndDate = LeaseEndDate
		
	--UPDATE #CzechList SET ConcessionPeriod = (DATEDIFF(MONTH, GETDATE(), RecurringConcessionEndDate) + 1)
	--	WHERE RecurringConcessionEndDate <> LeaseEndDate									  

	UPDATE #CzechList SET ScreenResidentDate = (SELECT TOP 1 DateRequested
													FROM ApplicantScreening
													WHERE LeaseID = #CzechList.LeaseID
													ORDER BY DateRequested)
													  
	UPDATE #CzechList SET ApprovedDate = (SELECT TOP 1 pn.[Date]
														FROM PersonNote pn
															INNER JOIN PersonLease pl ON pn.PersonID = pl.PersonID
														WHERE pl.LeaseID = #CzechList.LeaseID
														  AND pn.InteractionType = 'Approved'
														  ORDER BY pn.[Date])
														
	--UPDATE #CzechList SET PersonsOnLease = (SELECT COUNT(pl.PersonLeaseID)
	--											FROM PersonLease pl
	--											WHERE pl.LeaseID = #CzechList.LeaseID)													
		
	UPDATE #CzechList SET LeaseSent = (SELECT TOP 1 env.SentDate
										   FROM Envelope env											  
										   WHERE env.ObjectID = #CzechList.UnitLeaseGroupID
										   ORDER BY env.SentDate)
										   
	UPDATE #CzechList SET LeaseSignedDate = (SELECT TOP 1 LeaseSignedDate
												FROM PersonLease
												WHERE LeaseID = #CzechList.LeaseID
												ORDER BY LeaseSignedDate)
												  
	UPDATE #CzechList SET RentersInsuranceExpDate = (SELECT TOP 1 ExpirationDate
														 FROM RentersInsurance
														 WHERE UnitLeaseGroupID = #CzechList.UnitLeaseGroupID
														 ORDER BY ExpirationDate DESC)

	SELECT * FROM #CzechList											  

END


GO
