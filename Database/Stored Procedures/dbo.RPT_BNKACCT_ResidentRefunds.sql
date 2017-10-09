SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 5, 2011
-- Description:	Gets a list of resident refunds
-- =============================================
CREATE PROCEDURE [dbo].[RPT_BNKACCT_ResidentRefunds]
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null, 
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT DISTINCT		
			pr.Name AS 'PropertyName',
			payr.PaymentID AS 'PaymentID',
			t.ObjectID AS 'ObjectID',
			l.LeaseID AS 'LeaseID',
			u.Number AS 'UnitNumber',
			tt.[Group] AS 'ObjectType',
			l.LeaseEndDate AS 'LeaseEndDate',
			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
				 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
				 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
				 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '') AS 'Name',
			COALESCE(payr.Amount, p.Amount) AS 'Amount',
			fa.StreetAddress + '; ' + fa.City + ' ' + fa.[State] + ' ' + fa.Zip AS 'ForwardingAddress',
			payr.[Date] AS 'CheckDate',
			payr.ReferenceNumber AS 'ReferenceNumber',
			ba.BankName AS 'BankAccount',
			payr.ReversedDate AS 'VoidDate',
			payr.ReversedReason AS 'VoidNotes'
		FROM Payment p
			INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN Property pr ON t.PropertyID = pr.PropertyID
			INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			LEFT JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
			LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
			LEFT JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID --AND tta.Name = 'Refund'
			INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND (pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																							FROM PersonLease pls
																								LEFT JOIN Person pers ON pls.PersonID = pers.PersonID
																								LEFT JOIN Payment pays ON pers.PersonID = pays.ObjectID 
																							WHERE pls.LeaseID = l.LeaseID
																							  AND ((pays.PaymentID IS NOT NULL) OR (pers.PersonID IS NOT NULL))))
			INNER JOIN Person per ON pl.PersonID = per.PersonID
			LEFT JOIN Payment payr ON per.PersonID = payr.ObjectID AND payr.ObjectType = 'Resident Person'
			LEFT JOIN PaymentTransaction payrt ON payr.PaymentID = payrt.PaymentID
			LEFT JOIN BankTransaction bt ON payrt.PaymentID = bt.ObjectID AND bt.ObjectType = 'Payment'
			LEFT JOIN [Transaction] refundt ON payrt.TransactionID = refundt.TransactionID
			LEFT JOIN BankAccount ba ON refundt.ObjectID = ba.BankAccountID
			LEFT JOIN [Address] fa ON per.PersonID = fa.ObjectID AND fa.AddressType = 'Forwarding'
		WHERE tt.Name in ('Deposit Refund', 'Payment Refund')
			AND tt.[Group] in ('Lease', 'Prospect')
			AND t.PropertyID = @propertyID
			AND (tr.TransactionID IS NULL OR tr.TransactionDate > @endDate)
			AND t.ReversesTransactionID IS NULL
			AND (((bt.CheckPrintedDate IS NULL)) OR ((payr.[Date] >= @startDate) AND (payr.[Date] <= @endDate))) 
			AND (((payr.ReversedDate IS NULL)) OR ((payr.ReversedDate >= @startDate) AND (payr.ReversedDate <= @endDate)))
			AND l.LeaseID = ((SELECT TOP 1 LeaseID
								 FROM Lease
								 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								   AND (((SELECT COUNT(*) 
												FROM Lease 
												WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
												  AND LeaseStatus NOT IN ('Cancelled')) = 0)
										OR LeaseStatus NOT IN ('Cancelled'))
								 ORDER BY LeaseEndDate DESC))
			AND ((ta.TransactionID IS NULL) OR 
				(((SELECT COUNT(transactionID) from [Transaction] ta1 where ta1.AppliesToTransactionID = refundt.TransactionID) =
			     (SELECT COUNT(transactionID) from [Transaction] tr1 where tr1.ReversesTransactionID in (SELECT transactionID
												FROM [Transaction] tr2 where tr2.AppliesToTransactionID = refundt.TransactionID)))))

	-- The above statement is added to account for voided checks.  If the count of transactions that apply to the original refund request
	-- equal the number of transactions that have reversed a transaction that applies to the original request, then we've voided everything we've
	-- attempted to apply.  Otherwise, we haven't.  Same comment applies to the query below.		
						
	ORDER BY LeaseEndDate, UnitNumber
		
	
END
GO
