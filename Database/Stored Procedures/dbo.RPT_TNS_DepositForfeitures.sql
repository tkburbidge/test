SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 27, 2014
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_DepositForfeitures] 
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

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs

	CREATE TABLE #ForfeitedDeposits (
		TransactionID uniqueidentifier not null,
		PaymentID uniqueidentifier null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		ForeitureType nvarchar(50) null,
		ObjectID uniqueidentifier null,
		TransactionTypeGroup nvarchar(50) null,
		UnitNumber nvarchar(50) null,
		PaddedUnitNumber nvarchar(50) null,
		TransactionDate date null,
		Reference nvarchar(50) null,
		[Description] nvarchar(500) null,
		Residents nvarchar(500) null,
		OriginalAmount money null,
		Amount money null,
		IsReversal bit null)
		
	INSERT #ForfeitedDeposits
		SELECT	t.TransactionID,
				pay.PaymentID,
				t.PropertyID,
				null,
				tt.Name,
				t.ObjectID,
				tt.[Group],
				null,
				null,
				t.TransactionDate,
				pay.ReferenceNumber,
				COALESCE(pay.[Description], t.[Description]),
				null,
				null,
				t.Amount,
				pay.Reversed
			FROM [Transaction] t
				--Payment pay
				LEFT JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
				LEFT JOIN Payment pay ON pay.PaymentID = pt.PaymentID
				--INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN #PropertyIDs #pids ON t.PropertyID = #pids.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE tt.Name IN ('Balance Transfer Deposit', 'Deposit Applied to Balance')
			  --AND t.TransactionDate >= @startDate
			  --AND t.TransactionDate <= @endDate
			  AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))
			  
	
	SELECT	#4feitDepots.TransactionID,
			#4feitDepots.PaymentID,
			p.Name AS 'PropertyName',
			(CASE WHEN #4feitDepots.ForeitureType = 'Balance Transfer Deposit' THEN 'Balance Transfer'
				  ELSE 'Deposit Applied to Balance'
			 END) AS 'Type',
			#4feitDepots.ObjectID AS 'ObjectID',
			#4feitDepots.TransactionTypeGroup AS 'TransactionTypeGroup',
			CASE 
				WHEN (u.UnitID IS NOT NULL) THEN u.Number
				ELSE null END AS 'UnitNumber',
			CASE
				WHEN (u.UnitID IS NOT NULL) THEN u.PaddedNumber
				ELSE null END AS 'PaddedUnitNumber',
			#4feitDepots.TransactionDate AS 'TransactionDate',
			#4feitDepots.Reference AS 'Reference',
			#4feitDepots.[Description] AS 'Description',
			CASE 
				WHEN (#4feitDepots.TransactionTypeGroup = 'Lease') THEN
					STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN Lease l ON l.LeaseID = PersonLease.LeaseID
							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1
							   AND l.LeaseID = ((SELECT TOP 1 LeaseID
												FROM Lease 
												INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
												WHERE UnitLeaseGroupID = #4feitDepots.ObjectID
												ORDER BY o.OrderBy))
						 ORDER BY PersonLease.OrderBy, PersonLease.PersonLeaseID							   				   
						 FOR XML PATH ('')), 1, 2, '')				
				ELSE (SELECT per.PreferredName + ' ' + per.LastName
						  FROM Person per
						  WHERE per.PersonID = #4feitDepots.ObjectID) END AS 'Residents',
			#4feitDepots.Amount AS 'Amount',
			#4feitDepots.IsReversal AS 'IsReversal'
		FROM #ForfeitedDeposits #4feitDepots
			INNER JOIN Property p ON #4feitDepots.PropertyID = p.PropertyID
			LEFT JOIN UnitLeaseGroup ulg ON #4feitDepots.ObjectID = ulg.UnitLeaseGroupID
			LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
			--LEFT JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID

	
END
GO
