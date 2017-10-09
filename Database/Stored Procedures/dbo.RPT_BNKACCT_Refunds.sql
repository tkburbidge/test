SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 5, 2011
-- Description:	Gets a list of resident refunds
-- =============================================
CREATE PROCEDURE [dbo].[RPT_BNKACCT_Refunds]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection readonly, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS

DECLARE @accountID bigint = null

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #RefundMeSomeMoney (
		PropertyName nvarchar(200) null,
		PropertyAbbreviation nvarchar(50) null,
		PaymentID uniqueidentifier null,
		ObjectID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		UnitNumber nvarchar(50) null,
		PaddedNumber nvarchar(50) null,
		ObjectType nvarchar(50) null,
		LeaseEndDate date null,
		Name nvarchar(500) null,
		RefundDate date null,
		Amount money null,
		ForwardingAddress nvarchar(500) null,
		CheckDate date null,
		ReferenceNumber nvarchar(100) null,
		BankAccount nvarchar(100) null,
		VoidDate date null,
		VoidNotes nvarchar(500) null,
		TransactionTypeName nvarchar(50) null)

	CREATE TABLE #MyTransactions (
		TransactionID uniqueidentifier not null,
		TransactionTypeID uniqueidentifier not null,
		TransactionDate date not null,
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ReversesTransactionID uniqueidentifier null,
		AppliesToTransactionID uniqueidentifier null,
		Name nvarchar(50) null,
		[Group] nvarchar(50) null)

	CREATE TABLE #MyTransactionTypes (
		TransactionTypeID uniqueidentifier not null,
		Name nvarchar(50) null,
		[Group] nvarchar(50) null)

	CREATE TABLE #PropertyAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL)
		
	INSERT #PropertyAndDates
		SELECT pids.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pids
				LEFT JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PropertyAndDates))

	INSERT #MyTransactionTypes
		SELECT TransactionTypeID, Name, [Group]
			FROM TransactionType
			WHERE AccountID = @accountID
			  AND [Name] IN ('Refund', 'Deposit Refund', 'Payment Refund')
			  AND [Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'Bank')

	INSERT #MyTransactions
		SELECT	t.TransactionID, 
				tt.TransactionTypeID,
				t.TransactionDate,
				t.PropertyID,
				t.ObjectID,
				t.ReversesTransactionID,
				t.AppliesToTransactionID,
				tt.Name,
				tt.[Group]
			FROM [Transaction] t
				INNER JOIN #MyTransactionTypes tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN #PropertyAndDates #pad ON t.PropertyID = #pad.PropertyID

	/***** Start Resident Refunds *****/
	
	INSERT #RefundMeSomeMoney
		-- Pending refunds
		SELECT DISTINCT		
				pr.Name AS 'PropertyName',
				pr.Abbreviation AS 'PropertyAbbreviation',
				p.PaymentID AS 'PaymentID',
				t.ObjectID AS 'ObjectID',
				l.LeaseID AS 'LeaseID',
				u.Number AS 'UnitNumber',
				u.PaddedNumber,
				t.[Group] AS 'ObjectType',
				l.LeaseEndDate AS 'LeaseEndDate',
				null AS 'Name',
				p.[Date] AS 'RefundDate',
				p.Amount AS 'Amount',
				ISNULL(fa.StreetAddress, '') + '; ' + ISNULL(fa.City, '') + ' ' + ISNULL(fa.[State], '') + ' ' + ISNULL(fa.Zip, '') AS 'ForwardingAddress',
				NULL AS 'CheckDate',
				NULL AS 'ReferenceNumber',
				NULL AS 'BankAccount',			
				NULL AS 'VoidDate',
				NULL AS 'VoidNotes',
				t.Name AS 'TransactionTypeName'
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN #MyTransactions t ON pt.TransactionID = t.TransactionID
				--INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN Property pr ON t.PropertyID = pr.PropertyID
				INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN Person per ON per.PersonID = pl.PersonID
				LEFT JOIN [Address] fa ON per.PersonID = fa.ObjectID AND fa.AddressType = 'Forwarding'
				LEFT JOIN #MyTransactions ta ON t.TransactionID = ta.AppliesToTransactionID AND ta.TransactionDate <= #pad.EndDate
				LEFT JOIN #MyTransactions tr ON t.TransactionID = tr.ReversesTransactionID
				LEFT JOIN #MyTransactions tar ON ta.TransactionID = tar.ReversesTransactionID
				LEFT JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID	
				INNER JOIN #PropertyAndDates #pad ON t.PropertyID = #pad.PropertyID		
			WHERE t.Name in ('Deposit Refund', 'Payment Refund')
				AND t.[Group] in ('Lease')
				--AND p.[Date] >= @startDate
				AND p.[Date] <= #pad.EndDate
				AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
				AND t.ReversesTransactionID IS NULL			
				AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2
								 INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l2.LeaseStatus
								 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 ORDER BY o.OrderBy)
				AND pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
										FROM PersonLease pl2
										WHERE pl2.LeaseID = l.LeaseID
										ORDER BY pl2.OrderBy)
				AND ((ta.TransactionID IS NULL) OR (ta.TransactionDate > #pad.EndDate) OR
					(((SELECT COUNT(TransactionID) from [Transaction] ta1 where ta1.AppliesToTransactionID = t.TransactionID and ta1.TransactionDate <= #pad.EndDate) =
					 (SELECT COUNT(TransactionID) from [Transaction] tr1 where tr1.TransactionDate <= #pad.EndDate and tr1.ReversesTransactionID in (SELECT TransactionID
													FROM [Transaction] tr2 where tr2.AppliesToTransactionID = t.TransactionID)))))
		
			-- Scenario 1
			-- 7/15 - Refund started
			-- 8/1 - Complete the refund
			-- 8/15 - Void the refund		

			-- Today is 8/16, no matter what date I run it, it shows up as Pending
			-- Want it to show
			-- 7/15 - Pending
			-- 8/1 - Completed
			-- 8/5 - Completed
			-- 8/15 - Pending

			-- Scenario 2
			-- 7/15 - Refund started
			-- 8/15 - Refund completed
			-- 8/10 - Refund voided
			-- 8/20 - Completed

			-- Want to show
			-- 7/15 - Pending
			-- 8/10 - Pending
			-- 8/15 - Pending
			-- 8/20 - Completed





			-- The above statement is added to account for voided checks.  If the count of transactions that apply to the original refund request
			-- equal the number of transactions that have reversed a transaction that applies to the original request, then we've voided everything we've
			-- attempted to apply.  Otherwise, we haven't.
		UNION
		-- Completed Refunds
		SELECT DISTINCT		
				pr.Name AS 'PropertyName',
				pr.Abbreviation AS 'PropertyAbbreviation',
				p.PaymentID AS 'PaymentID',
				t.ObjectID AS 'ObjectID',
				l.LeaseID AS 'LeaseID',
				u.Number AS 'UnitNumber',
				u.PaddedNumber,
				tatt.[Group] AS 'ObjectType',
				l.LeaseEndDate AS 'LeaseEndDate',
				null AS 'Name',
				null AS 'RefundDate',
				p.Amount AS 'Amount',
				ISNULL(fa.StreetAddress, '') + '; ' + ISNULL(fa.City, '') + ' ' + ISNULL(fa.[State], '') + ' ' + ISNULL(fa.Zip, '') AS 'ForwardingAddress',
				p.[Date] AS 'CheckDate',
				p.ReferenceNumber AS 'ReferenceNumber',
				ba.AccountName AS 'BankAccount',			
				NULL AS 'VoidDate',
				NULL AS 'VoidNotes',
				NULL AS 'TransactionTypeName'
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN #MyTransactions t ON pt.TransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			
				--INNER JOIN [Transaction] ta ON ta.TransactionID = t.AppliesToTransactionID
				INNER JOIN #MyTransactions ta ON ta.TransactionID = t.AppliesToTransactionID
				INNER JOIN [TransactionType] tatt ON tatt.TransactionTypeID = ta.TransactionTypeID
			
				INNER JOIN Property pr ON ta.PropertyID = pr.PropertyID
				INNER JOIN UnitLeaseGroup ulg ON ta.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID			
			
			
				LEFT JOIN #MyTransactions tr ON t.TransactionID = tr.ReversesTransactionID	
				LEFT JOIN [Address] fa ON p.ObjectID = fa.ObjectID AND fa.AddressType = 'Forwarding'
				LEFT JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID	
				INNER JOIN #PropertyAndDates #pad ON t.PropertyID = #pad.PropertyID
			WHERE tt.Name in ('Refund')
				AND p.[Date] >= #pad.StartDate AND p.[Date] <= #pad.EndDate
				AND tatt.[Group] in ('Lease')			
				AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
				AND t.ReversesTransactionID IS NULL									
				AND l.LeaseID = (SELECT TOP 1 LeaseID
								 FROM Lease l
								 INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l.LeaseStatus
								 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 ORDER BY o.OrderBy)
				--AND ((ta.TransactionID IS NULL) OR 
				--	(((SELECT COUNT(TransactionID) from [Transaction] ta1 where ta1.AppliesToTransactionID = refundt.TransactionID) =
				--     (SELECT COUNT(TransactionID) from [Transaction] tr1 where tr1.ReversesTransactionID in (SELECT TransactionID
				--									FROM [Transaction] tr2 where tr2.AppliesToTransactionID = refundt.TransactionID)))))
	
		UNION
		-- Voided refunds
		SELECT DISTINCT		
				pr.Name AS 'PropertyName',
				pr.Abbreviation AS 'PropertyAbbreviation',
				p.PaymentID AS 'PaymentID',
				t.TransactionID AS 'ObjectID',
				l.LeaseID AS 'LeaseID',
				u.Number AS 'UnitNumber',
				u.PaddedNumber,
				OriginalRefundTransactionType.[Group] AS 'ObjectType',
				l.LeaseEndDate AS 'LeaseEndDate',
				null AS 'Name',
				null AS 'RefundDate',
				p.Amount AS 'Amount',
				NULL AS 'ForwardingAddress',
				p.[Date] AS 'CheckDate',
				p.ReferenceNumber AS 'ReferenceNumber',
				ba.AccountName AS 'BankAccount',
				p.ReversedDate AS 'VoidDate',
				p.VoidNotes AS 'VoidNotes',
				NULL AS 'TransactionTypeName'
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN #MyTransactions t ON pt.TransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			
				-- Join in the refund payment that was revesred
				INNER JOIN #MyTransactions ReversedTransaction ON ReversedTransaction.TransactionID = t.ReversesTransactionID
				-- Join in the original refund that was paid
				INNER JOIN #MyTransactions OriginalRefundTransaction ON OriginalRefundTransaction.TransactionID = ReversedTransaction.AppliesToTransactionID
				INNER JOIN TransactionType OriginalRefundTransactionType ON OriginalRefundTransaction.TransactionTypeID = OriginalRefundTransactionType.TransactionTypeID			
				INNER JOIN Property pr ON OriginalRefundTransaction.PropertyID = pr.PropertyID
				INNER JOIN UnitLeaseGroup ulg ON OriginalRefundTransaction.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
				LEFT JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID	
				INNER JOIN #PropertyAndDates #pad ON t.PropertyID = #pad.PropertyID		
			WHERE tt.Name in ('Refund')
				AND OriginalRefundTransactionType.[Group] in ('Lease')
				AND t.ReversesTransactionID IS NOT NULL					
				AND ((p.ReversedDate >= #pad.StartDate) AND (p.ReversedDate <= #pad.EndDate)) 	
				AND l.LeaseID = (SELECT TOP 1 LeaseID
								 FROM Lease l
								 INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l.LeaseStatus
								 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 ORDER BY o.OrderBy)											
	
		/***** End Resident Refunds *****/	
	
		UNION
	
		/***** Start Prospect and Non-Resident Refunds *****/
	
		-- Pending refunds
		SELECT DISTINCT		
				pr.Name AS 'PropertyName',
				pr.Abbreviation AS 'PropertyAbbreviation',
				p.PaymentID AS 'PaymentID',
				t.ObjectID AS 'ObjectID',
				NULL AS 'LeaseID',
				NULL AS 'UnitNumber',
				NULL AS 'PaddedNumber',
				t.[Group] AS 'ObjectType',
				NULL AS 'LeaseEndDate',
				(per.PreferredName + ' ' + per.LastName) AS 'Name',
				p.[Date] AS 'RefundDate',
				p.Amount AS 'Amount',
				ISNULL(fa.StreetAddress, '') + '; ' + ISNULL(fa.City, '') + ' ' + ISNULL(fa.[State], '') + ' ' + ISNULL(fa.Zip, '') AS 'ForwardingAddress',
				NULL AS 'CheckDate',
				NULL AS 'ReferenceNumber',
				NULL AS 'BankAccount',			
				NULL AS 'VoidDate',
				NULL AS 'VoidNotes',
				t.Name AS 'TransactionTypeName'
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN #MyTransactions t ON pt.TransactionID = t.TransactionID
				--INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN Property pr ON t.PropertyID = pr.PropertyID
				--INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
				--INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				--INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				--INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN Person per ON per.PersonID = t.ObjectID
				LEFT JOIN [Address] fa ON per.PersonID = fa.ObjectID AND fa.AddressType IN ('Prospect', 'Non-Resident Account')
				LEFT JOIN #MyTransactions ta ON t.TransactionID = ta.AppliesToTransactionID
				LEFT JOIN #MyTransactions tr ON t.TransactionID = tr.ReversesTransactionID
				LEFT JOIN #MyTransactions tar ON ta.TransactionID = tar.ReversesTransactionID


				LEFT JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID
				INNER JOIN #PropertyAndDates #pad ON t.PropertyID = #pad.PropertyID			
			WHERE t.Name in ('Deposit Refund', 'Payment Refund')
				AND t.[Group] in ('Prospect', 'Non-Resident Account')

			
				AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
				AND t.ReversesTransactionID IS NULL
				--AND p.[Date] >= @startDate 
				AND p.[Date] <= #pad.EndDate
				AND ((ta.TransactionID IS NULL) OR (ta.TransactionDate > #pad.EndDate) OR
					(((SELECT COUNT(TransactionID) from [Transaction] ta1 where ta1.AppliesToTransactionID = t.TransactionID and ta1.TransactionDate <= #pad.EndDate) =
					 (SELECT COUNT(TransactionID) from [Transaction] tr1 where tr1.TransactionDate <= #pad.EndDate and tr1.ReversesTransactionID in (SELECT TransactionID
													FROM [Transaction] tr2 where tr2.AppliesToTransactionID = t.TransactionID)))))

		
			-- The above statement is added to account for voided checks.  If the count of transactions that apply to the original refund request
			-- equal the number of transactions that have reversed a transaction that applies to the original request, then we've voided everything we've
			-- attempted to apply.  Otherwise, we haven't.
		UNION
		-- Completed Refunds
		SELECT DISTINCT		
				pr.Name AS 'PropertyName',
				pr.Abbreviation AS 'PropertyAbbreviation',
				p.PaymentID AS 'PaymentID',
				t.ObjectID AS 'ObjectID',
				NULL AS 'LeaseID',
				NULL AS 'UnitNumber',
				NULL AS 'PaddedNumber',
				tatt.[Group] AS 'ObjectType',
				NULL AS 'LeaseEndDate',
				(per.PreferredName + ' ' + per.LastName) AS 'Name',
				null AS 'RefundDate',
				p.Amount AS 'Amount',
				ISNULL(fa.StreetAddress, '') + '; ' + ISNULL(fa.City, '') + ' ' + ISNULL(fa.[State], '') + ' ' + ISNULL(fa.Zip, '') AS 'ForwardingAddress',
				p.[Date] AS 'CheckDate',
				p.ReferenceNumber AS 'ReferenceNumber',
				ba.AccountName AS 'BankAccount',			
				NULL AS 'VoidDate',
				NULL AS 'VoidNotes',
				NULL AS 'TransactionTypeName'
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN #MyTransactions t ON pt.TransactionID = t.TransactionID
				--INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			
				INNER JOIN #MyTransactions ta ON ta.TransactionID = t.AppliesToTransactionID
				INNER JOIN [TransactionType] tatt ON tatt.TransactionTypeID = ta.TransactionTypeID
			
				INNER JOIN Property pr ON ta.PropertyID = pr.PropertyID
				INNER JOIN Person per ON per.PersonID = ta.ObjectID	
						
				LEFT JOIN #MyTransactions tr ON t.TransactionID = tr.ReversesTransactionID	
				LEFT JOIN [Address] fa ON p.ObjectID = fa.ObjectID AND fa.AddressType IN ('Prospect', 'Non-Resident Account')
				LEFT JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID		
				INNER JOIN #PropertyAndDates #pad ON t.PropertyID = #pad.PropertyID
			WHERE t.Name in ('Refund')
				AND p.[Date] >= #pad.StartDate AND p.[Date] <= #pad.EndDate
				AND tatt.[Group] in ('Prospect', 'Non-Resident Account')
				AND ta.PropertyID IN (SELECT Value FROM @propertyIDs)
				AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
				AND t.ReversesTransactionID IS NULL		
	
		UNION
		-- Voided refunds
		SELECT DISTINCT		
				pr.Name AS 'PropertyName',
				pr.Abbreviation AS 'PropertyAbbreviation',
				p.PaymentID AS 'PaymentID',
				t.ObjectID AS 'ObjectID',
				NULL AS 'LeaseID',
				NULL AS 'UnitNumber',
				NULL AS 'PaddedNumber',
				OriginalRefundTransactionType.[Group] AS 'ObjectType',
				NULL AS 'LeaseEndDate',
				(per.PreferredName + ' ' + per.LastName) AS 'Name',
				null AS 'RefundDate',
				p.Amount AS 'Amount',
				NULL AS 'ForwardingAddress',
				p.[Date] AS 'CheckDate',
				p.ReferenceNumber AS 'ReferenceNumber',
				ba.AccountName AS 'BankAccount',
				p.ReversedDate AS 'VoidDate',
				p.VoidNotes AS 'VoidNotes',
				NULL AS 'TransactionTypeName'
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN #MyTransactions t ON pt.TransactionID = t.TransactionID
				--INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			
				-- Join in the refund payment that was revesred
				INNER JOIN #MyTransactions ReversedTransaction ON ReversedTransaction.TransactionID = t.ReversesTransactionID
				-- Join in the original refund that was paid
				INNER JOIN #MyTransactions OriginalRefundTransaction ON OriginalRefundTransaction.TransactionID = ReversedTransaction.AppliesToTransactionID
				INNER JOIN TransactionType OriginalRefundTransactionType ON OriginalRefundTransaction.TransactionTypeID = OriginalRefundTransactionType.TransactionTypeID			
				INNER JOIN Property pr ON OriginalRefundTransaction.PropertyID = pr.PropertyID
			
				INNER JOIN Person per ON per.PersonID = OriginalRefundTransaction.ObjectID
			
				LEFT JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID	
				INNER JOIN #PropertyAndDates #pad ON t.PropertyID = #pad.PropertyID		
			WHERE t.Name in ('Refund')
				AND OriginalRefundTransactionType.[Group] in ('Prospect', 'Non-Resident Account')			
				AND OriginalRefundTransaction.PropertyID IN (SELECT Value FROM @propertyIDs)
				AND t.ReversesTransactionID IS NOT NULL					
				AND ((p.ReversedDate >= #pad.StartDate) AND (p.ReversedDate <= #pad.EndDate)) 
	
		/***** End Prospect and Non-Resident Refunds *****/
	
	

	UPDATE #RefundMeSomeMoney SET Name = (SELECT STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
											 FROM Person 
												INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
												INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
												INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
											 WHERE PersonLease.LeaseID = #RefundMeSomeMoney.LeaseID
											   AND PersonType.[Type] = 'Resident'				   
											   AND PersonLease.MainContact = 1	
											 FOR XML PATH ('')), 1, 2, ''))
		WHERE ObjectType = 'Lease'



	SELECT *
		FROM #RefundMeSomeMoney
		ORDER BY ObjectType, PaddedNumber, Name	


END
GO
