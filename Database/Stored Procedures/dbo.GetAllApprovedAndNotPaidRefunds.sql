SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 2, 2015
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[GetAllApprovedAndNotPaidRefunds] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier 
	)

	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	SELECT DISTINCT
				tt.[Group] AS 'ObjectType',
				t.ObjectID,
				ulg.UnitLeaseGroupID,
				u.Number AS 'UnitNumber',
				p.[Date],
				p.[Description],
				p.Amount,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1				   
						 FOR XML PATH ('')), 1, 2, '') AS 'Residents',
				(SELECT TOP 1 Person.PersonID
					FROM Person
					INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					WHERE PersonLease.LeaseID = l.LeaseID
						AND PersonType.[Type] = 'Resident'				   
						AND PersonLease.MainContact = 1) AS 'PersonID',
				(SELECT TOP 1 adder.StreetAddress + char(13) + adder.City + char(13) + adder.[State] + char(13) + adder.Zip + char(13) + ISNULL(adder.Country, 'USA') + char(13)
					FROM [Address] adder
						INNER JOIN PersonLease plAdder ON adder.ObjectID = plAdder.PersonID AND adder.AddressType = 'Forwarding'
											AND plAdder.MainContact = 1 AND plAdder.LeaseID = l.LeaseID) AS 'Address',
				(SELECT TOP 1 adder.AddressID
					FROM [Address] adder
						INNER JOIN PersonLease plAdder ON adder.ObjectID = plAdder.PersonID AND adder.AddressType = 'Forwarding'
											AND plAdder.MainContact = 1 AND plAdder.LeaseID = l.LeaseID) AS 'AddressID',
				pro.PropertyID,
				p.PaymentID,
				tt.[Name] AS 'Type'
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
			AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
			AND tr.TransactionID IS NULL
			AND t.ReversesTransactionID IS NULL
			AND (pn.PersonNoteID IS NULL OR pn.InteractionType = 'Approved FAS')
			AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
							FROM Lease  
							INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
							WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
							ORDER BY Ordering.OrderBy)
			AND ((ta.TransactionID IS NULL) OR 
				(((SELECT COUNT(transactionID) from [Transaction] ta1 where ta1.AppliesToTransactionID = t.TransactionID) =
			     (SELECT COUNT(transactionID) from [Transaction] tr1 where tr1.ReversesTransactionID in (SELECT transactionID
												FROM [Transaction] tr2 where tr2.AppliesToTransactionID = t.TransactionID)))))

	-- The above statement is added to account for voided checks.  If the count of transactions that apply to the original refund request
	-- equal the number of transactions that have reversed a transaction that applies to the original request, then we've voided everything we've
	-- attempted to apply.  Otherwise, we haven't.  Same comment applies to the query below.		

				
	ORDER BY UnitNumber

END
GO
