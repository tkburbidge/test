SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 27, 2014
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_DepositForfeituresAndApplications]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@startDate date = null, 
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #ForfeitedDeposits (
		TransactionID uniqueidentifier not null,
		PaymentID uniqueidentifier null,
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier null,
		IsReversal bit null)

	CREATE TABLE #Applications (
		DepositPaymentID uniqueidentifier not null,
		DepositTransactionID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		AppliedAmount money null,
		TransactionID uniqueidentifier not null,
		AppliedDate date null,
		AppliedDescription nvarchar(500) null,
		ObjectID uniqueidentifier null,
		GLAccountName nvarchar(100) null,
		GLAccountNumber nvarchar(50) null,
		AppliedType nvarchar(50) null)	

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		
	INSERT #ForfeitedDeposits
		SELECT	t.TransactionID,
				pay.PaymentID,
				t.PropertyID,
				t.ObjectID,
				pay.Reversed
			FROM [Transaction] t
				--Payment pay
				LEFT JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
				LEFT JOIN Payment pay ON pay.PaymentID = pt.PaymentID
				--INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
				--LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE tt.Name IN ('Balance Transfer Deposit', 'Deposit Applied to Balance')
			  --AND t.TransactionDate >= @startDate
			  --AND t.TransactionDate <= @endDate
			  --AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
			  --  OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))

	INSERT #Applications
		SELECT	#4feitDepots.PaymentID, #4feitDepots.TransactionID, t.PropertyID, je.Amount, t.TransactionID, t.TransactionDate, t.[Description], t.ObjectID, gla.Name, gla.Number, tt.Name
			FROM [Transaction] t
				INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
				INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
				INNER JOIN #ForfeitedDeposits #4feitDepots ON pay.PaymentID = #4feitDepots.PaymentID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment', 'Credit')
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
				INNER JOIN [Transaction] origChrgT ON t.AppliesToTransactionID = origChrgT.TransactionID
				INNER JOIN JournalEntry je ON origChrgT.TransactionID = je.TransactionID AND je.Amount < 0
				INNER JOIN GLAccount gla ON je.GLAccountID = gla.GLAccountID
				LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
			WHERE t.LedgerItemTypeID IS NULL
			  AND tr.TransactionID IS NULL
			
	SELECT	#app.PropertyID AS 'PropertyID',
			prop.Name AS 'PropertyName',
			#app.AppliedDate AS 'TransactionDate',
			#app.TransactionID AS 'TransactionID',
			#app.DepositPaymentID AS 'PaymentID',
			#app.AppliedType AS 'TransactionType',
			u.Number AS 'Unit',
			u.PaddedNumber AS 'PaddedUnitNumber',
			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					FROM Person 
						INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					WHERE PersonLease.LeaseID = l.LeaseID
						AND PersonType.[Type] = 'Resident'				   
						AND PersonLease.MainContact = 1				   
					FOR XML PATH ('')), 1, 2, '') AS 'ResidentNames',
			#app.ObjectID AS 'ObjectID',
			#app.AppliedDescription AS 'Description',
			#app.GLAccountName AS 'GLAccountName',
			#app.GLAccountNumber AS 'GLAccountNumber',
			-#app.AppliedAmount AS 'Amount'
		FROM #Applications #app
			INNER JOIN Property prop ON #app.PropertyID = prop.PropertyID
			INNER JOIN UnitLeaseGroup ulg ON #app.ObjectID = ulg.UnitLeaseGroupID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
		WHERE l.LeaseID = (SELECT TOP 1 LeaseID	
							  FROM Lease l1
								  INNER JOIN Ordering ord ON l1.LeaseStatus = ord.Value AND ord.[Type] = 'Lease'
							  WHERE l1.LeaseID = l.LeaseID
							  ORDER BY ord.OrderBy)
		ORDER BY prop.Name, u.PaddedNumber

	
END



GO
