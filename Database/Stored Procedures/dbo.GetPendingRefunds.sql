SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 5, 2011
-- Description:	Gets a list of resident refunds
-- =============================================
CREATE PROCEDURE [dbo].[GetPendingRefunds]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@objectID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs (Value UNIQUEIDENTIFIER NOT NULL);
		
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs

	SELECT DISTINCT pro.Name AS 'Property', p.PaymentID AS 'ID', t.ObjectID, tt.[Group] AS 'ObjectType', l.LeaseID, u.Number AS 'UnitNumber',
				p.[Description] AS 'Description', p.[Date] AS 'Date', p.[Notes] AS 'Note',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1				   
						 FOR XML PATH ('')), 1, 2, '') AS 'PersonNames',
				l.LeaseEndDate AS 'LeaseEndDate', p.Amount,
				tt.[Name] AS [Type],
				pn.PersonID,
				CASE 
					WHEN (pn.InteractionType = 'Pending FAS') THEN 'Pending'
					WHEN (pn.InteractionType = 'Approved FAS') THEN 'Approved'
					WHEN (pn.InteractionType = 'Denied FAS') THEN 'Denied'
					WHEN (pn.InteractionType = 'Resubmitted FAS') THEN 'Resubmitted'
					ELSE null
				END AS 'Status'
		FROM Payment p
			INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Property pro ON pro.PropertyID = t.PropertyID
			LEFT JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
			LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
			LEFT JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name = 'Refund'
			LEFT JOIN PersonNote pn ON pn.ObjectID = t.ObjectID AND pn.PersonNoteID = (SELECT TOP 1 PersonNoteID	
																					   FROM PersonNote 
																					   WHERE ObjectID = t.ObjectID
																						AND InteractionType IN ('Pending FAS', 'Approved FAS', 'Denied FAS', 'Resubmitted FAS')
																					   ORDER BY DateCreated DESC)
		WHERE tt.Name in ('Deposit Refund', 'Payment Refund')
			AND tt.[Group] in ('Lease')
			AND t.PropertyID IN (SELECT Value FROM #PropertyIDs)
			AND tr.TransactionID IS NULL
			AND t.ReversesTransactionID IS NULL
			AND ((@objectID IS NULL) OR (t.ObjectID = @objectID))
			AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
							FROM Lease  
							INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
							WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
							ORDER BY Ordering.OrderBy)
			AND ((ta.TransactionID IS NULL) OR 
				(((SELECT COUNT(TransactionID) from [Transaction] ta1 where ta1.AppliesToTransactionID = t.TransactionID) =
			     (SELECT COUNT(TransactionID) from [Transaction] tr1 where tr1.ReversesTransactionID in (SELECT TransactionID
												FROM [Transaction] tr2 where tr2.AppliesToTransactionID = t.TransactionID)))))

	-- The above statement is added to account for voided checks.  If the count of transactions that apply to the original refund request
	-- equal the number of transactions that have reversed a transaction that applies to the original request, then we've voided everything we've
	-- attempted to apply.  Otherwise, we haven't.  Same comment applies to the query below.		
			
	UNION
	
	SELECT DISTINCT pro.Name AS 'Property', p.PaymentID AS 'ID', t.ObjectID, tt.[Group] AS 'ObjectType', null AS 'LeaseID', null AS 'UnitNumber',
				p.[Description] AS 'Description', p.[Date] AS 'Date', p.[Notes] AS 'Note',
				pr.FirstName + ' ' + pr.LastName AS 'PersonNames',
				null AS 'LeaseEndDate', p.Amount,
				tt.[Name] AS [Type],
				pn.PersonID,
				CASE 
					WHEN (pn.InteractionType = 'Pending FAS') THEN 'Pending'
					WHEN (pn.InteractionType = 'Approved FAS') THEN 'Approved'
					WHEN (pn.InteractionType = 'Denied FAS') THEN 'Denied'
					WHEN (pn.InteractionType = 'Resubmitted FAS') THEN 'Resubmitted'
					ELSE null
				END AS 'Status'	
		FROM Payment p
			INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN Person pr ON t.ObjectID = pr.PersonID
			INNER JOIN Property pro ON pro.PropertyID = t.PropertyID
			LEFT JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
			LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
			LEFT JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name = 'Refund'
			LEFT JOIN PersonNote pn ON pn.ObjectID = t.ObjectID AND pn.PersonNoteID = (SELECT TOP 1 PersonNoteID	
																					   FROM PersonNote 
																					   WHERE ObjectID = t.ObjectID
																						AND InteractionType IN ('Pending FAS', 'Approved FAS', 'Denied FAS', 'Resubmitted FAS')
																					   ORDER BY DateCreated DESC)
		WHERE tt.Name in ('Deposit Refund', 'Payment Refund')
			AND tt.[Group] in ('Prospect', 'Non-Resident Account')
			AND t.PropertyID IN (SELECT Value FROM #PropertyIDs)
			AND tr.TransactionID IS NULL
			AND t.ReversesTransactionID IS NULL
			AND ((@objectID IS NULL) OR (t.ObjectID = @objectID))
			AND ((ta.TransactionID IS NULL) OR 
				(((SELECT COUNT(TransactionID) from [Transaction] ta1 where ta1.AppliesToTransactionID = t.TransactionID) =
			     (SELECT COUNT(TransactionID) from [Transaction] tr1 where tr1.ReversesTransactionID in (SELECT TransactionID
												FROM [Transaction] tr2 where tr2.AppliesToTransactionID = t.TransactionID)))))

				
	ORDER BY LeaseEndDate, UnitNumber
		
	
END
GO
