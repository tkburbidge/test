SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 12, 2013
-- Description:	Gets the Final Account Statement Lists
-- =============================================
CREATE PROCEDURE [dbo].[GetFinalAccountStatementLists] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@approvalOnly bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	pn.PersonID,
			u.Number AS 'Unit', 
			ulg.UnitLeaseGroupID AS 'ObjectID', 
			'Resident' AS 'ObjectType',
			l.LeaseID AS 'LeaseID',
			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '') AS 'Residents',
			pEmp.PreferredName + ' ' + pEmp.LastName AS 'Employee',
			l.LeaseEndDate AS 'LeaseEndDate',
			(SELECT MAX(pl1.MoveOutDate) 
				FROM PersonLease pl1
					LEFT JOIN PersonLease plmo ON l.LeaseID = plmo.LeaseID AND plmo.MoveOutDate IS NULL
				WHERE pl1.ResidencyStatus IN ('Former', 'Evicted')
				  AND pl1.LeaseID = l.LeaseID
				  AND plmo.PersonLeaseID IS NULL) AS 'MoveOutDate',
			[CurBal].Balance AS 'Balance',
			(SELECT ISNULL(SUM(ISNULL(cd.Amount, 0)), 0)
				FROM CollectionDetail cd 
				WHERE cd.ObjectID = pn.ObjectID) AS 'CollectionsBalance',
			(SELECT ISNULL(SUM(
					ISNULL(CASE WHEN tt.Name = 'Payment Refund' THEN -t.Amount
						 ELSE t.Amount
					END, 0)			
			), 0)
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Name] IN ('Payment Refund', 'Deposit Refund')
					LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
					LEFT JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
				WHERE t.ObjectID = ulg.UnitLeaseGroupID
				  AND ta.TransactionID IS NULL
				  AND tr.TransactionID IS NULL
				  AND t.ReversesTransactionID IS NULL
				  )

					AS 'RefundBalance', 
			CASE 
				WHEN (pn.InteractionType = 'Pending FAS') THEN 'Pending'
				WHEN (pn.InteractionType = 'Approved FAS') THEN 'Approved'
				WHEN (pn.InteractionType = 'Denied FAS') THEN 'Denied'
				WHEN (pn.InteractionType = 'Resubmitted FAS') THEN 'Resubmitted'
				END AS 'Status',
			pn.[Date] AS 'LastNoteDate',
			--ptp.PropertyID AS 'PropertyID' 
			pn.PropertyID AS 'PropertyID'
		FROM PersonNote pn
			INNER JOIN UnitLeaseGroup ulg ON pn.ObjectID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseID = (SELECT TOP 1 LeaseID 
																								FROM Lease 
																								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																								  AND LeaseStatus NOT IN ('Cancelled')
																								ORDER BY LeaseEndDate DESC)
			--INNER JOIN PersonTypeProperty ptp ON pn.CreatedByPersonTypePropertyID = ptp.PersonTypePropertyID
			--INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
			--INNER JOIN Person pEmp ON pt.PersonID = pEmp.PersonID
			INNER JOIN Person pEmp ON pn.CreatedByPersonID = pEmp.PersonID
			CROSS APPLY GetObjectBalance(null, DATEADD(YEAR, 1, GETDATE()), ulg.UnitLeaseGroupID, 0, @propertyIDs) AS [CurBal]
		WHERE pn.PropertyID IN (SELECT Value FROM @propertyIDs)
		  -- Get the last note
		  AND pn.PersonNoteID = (SELECT TOP 1 PersonNoteID FROM PersonNote
									WHERE ObjectID = ulg.UnitLeaseGroupID 									
									ORDER BY DateCreated DESC)
		  AND (((@approvalOnly = 0) AND (InteractionType IN ('Pending FAS', 'Denied FAS', 'Resubmitted FAS')))
			OR ((@approvalOnly = 1) AND (InteractionType IN ('Approved FAS')) AND (pn.[Date] >= @startDate AND pn.[Date] <= [Date])))

	UNION
	
	
	SELECT	pn.PersonID,
			null AS 'Unit', 
			p.PersonID AS 'ObjectID', 
			pn.PersonType AS 'ObjectType',
			null AS 'LeaseID',
			p.PreferredName + ' ' + p.LastName AS 'Residents',
			pEmp.PreferredName + ' ' + pEmp.LastName AS 'Employee',
			null AS 'LeaseEndDate',
			null AS 'MoveOutDate',
			[CurBal].Balance AS 'Balance',
			(SELECT ISNULL(SUM(ISNULL(cd.Amount, 0)), 0)
				FROM CollectionDetail cd 
				WHERE cd.ObjectID = pn.ObjectID) AS 'CollectionsBalance',
			(SELECT ISNULL(SUM(ISNULL(t.Amount, 0)), 0)
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Name] IN ('Payment Refund', 'Deposit Refund')
					LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
					LEFT JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
				WHERE t.ObjectID = p.PersonID
				  AND ta.TransactionID IS NULL
				  AND tr.TransactionID IS NULL
				  AND t.ReversesTransactionID IS NULL)
					AS 'RefundBalance', 
			CASE 
				WHEN (pn.InteractionType = 'Pending FAS') THEN 'Pending'
				WHEN (pn.InteractionType = 'Approved FAS') THEN 'Approved'
				WHEN (pn.InteractionType = 'Denied FAS') THEN 'Denied'
				WHEN (pn.InteractionType = 'Resubmitted FAS') THEN 'Resubmitted'
				END AS 'Status',
			pn.[Date] AS 'LastNoteDate',
			--ptp.PropertyID AS 'PropertyID' 
			pn.PropertyID AS 'PropertyID'
		FROM PersonNote pn
			INNER JOIN Person p ON pn.PersonID = p.PersonID AND pn.PersonType NOT IN ('Resident')
			--INNER JOIN PersonTypeProperty ptp ON pn.CreatedByPersonTypePropertyID = ptp.PersonTypePropertyID
			--INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
			--INNER JOIN Person pEmp ON pt.PersonID = pEmp.PersonID
			INNER JOIN Person pEmp ON pn.CreatedByPersonID = pEmp.PersonID
			CROSS APPLY GetObjectBalance(null, DATEADD(YEAR, 1, GETDATE()), p.PersonID, 0, @propertyIDs) AS [CurBal]
		WHERE pn.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND pn.PersonNoteID = (SELECT TOP 1 PersonNoteID FROM PersonNote 
									WHERE ObjectID = p.PersonID 
									ORDER BY DateCreated DESC)
			-- Get the last note
		  AND (((@approvalOnly = 0) AND (InteractionType IN ('Pending FAS', 'Denied FAS', 'Resubmitted FAS')))
			OR ((@approvalOnly = 1) AND (InteractionType IN ('Approved FAS')) AND (pn.[Date] >= @startDate AND pn.[Date] <= @endDate)))
	
	
	
END
GO
