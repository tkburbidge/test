SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 6, 2012
-- Description:	Generates the data for the Deposit Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_DepositSummary] 
	-- Add the parameters for the stored procedure here
	@objectTypes StringCollection READONLY,
	@leaseStatuses StringCollection READONLY,
	@propertyIDs GuidCollection READONLY,
	@date date = null,
	@objectID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #DepositSummary (
		PropertyName nvarchar(50) not null,
		ObjectID uniqueidentifier not null,
		TObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		ObjectType nvarchar(50) not null,
		Unit nvarchar(50) null,
		PaddedNumber nvarchar(50) null,
		Names nvarchar(4000) null,
		LeaseStatus nvarchar(50) null,
		MoveInDate date null,
		LeaseEndDate date null,
		NoticeToVacateDate date null,
		MoveOutDate date null,
		UnitRequiredDeposit money null,
		LeaseRequiredDeposit money null,
		DepositsPaidIn money null,
		DepositsPaidOut money null)
		
	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier
	)

	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs		
			
	CREATE TABLE #LeaseStatuses (
		[Status] nvarchar(100)
	)

	INSERT INTO #LeaseStatuses
		SELECT Value FROM @leaseStatuses

	CREATE TABLE #ObjectTypes (
		[Type] nvarchar(100)
	)

	INSERT INTO #ObjectTypes
		SELECT Value FROM @objectTypes
		WHERE Value <> 'Lease'


	IF ((SELECT COUNT(*) FROM @objectTypes WHERE Value = 'Lease') > 0)
	BEGIN
		INSERT INTO #DepositSummary 
			SELECT DISTINCT
					p.Name AS 'PropertyName', 
					l.LeaseID AS 'ObjectID',
					ulg.UnitLeaseGroupID AS 'TObjectID',
					p.PropertyID AS 'PropertyID',
					'Lease' AS 'ObjectType',
					u.Number AS 'Unit',
					u.PaddedNumber AS 'PaddedNumber',
					STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1				   
						 FOR XML PATH ('')), 1, 2, '') AS 'Names',	
					l.LeaseStatus AS 'LeaseStatus',
					(SELECT MIN(pl.MoveInDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
					l.LeaseEndDate AS 'LeaseEndDate',
					(SELECT MIN(pl.NoticeGivenDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'NoticeToVacateDate',					
					(SELECT MAX(pl.MoveOutDate)
					FROM PersonLease pl
						LEFT JOIN PersonLease pl2 ON pl2.LeaseID = l.LeaseID AND pl2.MoveOutDate IS NULL
					WHERE pl.LeaseID = l.LeaseID
					  AND pl2.PersonLeaseID IS NULL) AS 'MoveOutDate',	
					ut.RequiredDeposit AS 'UnitRequiredDeposit',
					null AS 'LeaseRequiredDeposit',
					null AS 'DepositsPaidIn',
					null AS 'DepositsPaidOut'		
				FROM UnitLeaseGroup ulg
					INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
					--INNER JOIN LedgerItemType lit ON lit.IsDeposit = 1
					--INNER JOIN LedgerItem li ON li.LedgerItemTypeID = lit.LedgerItemTypeID
					--INNER JOIN LeaseLedgerItem lli ON li.LedgerItemID = lli.LedgerItemID AND l.LeaseID = lli.LeaseID
					INNER JOIN Property p ON ut.PropertyID = p.PropertyID
					INNER JOIN #LeaseStatuses #ls ON #ls.[Status] = l.LeaseStatus
					INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = p.PropertyID
				WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
				  --AND l.LeaseStatus IN (SELECT Value FROM @leaseStatuses)			  
				  AND ((@objectID IS NULL) OR (ulg.UnitLeaseGroupID = @objectID))
				  --AND 'Lease' IN (SELECT Value FROM @objectTypes)
				  AND l.LeaseID = ((SELECT TOP 1 LeaseID
									FROM Lease 
									INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
									WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
									ORDER BY o.OrderBy))	  
	END

	IF ((SELECT COUNT(*) FROM @objectTypes WHERE Value <> 'Lease') > 0)
	BEGIN
	INSERT INTO #DepositSummary 			

		SELECT DISTINCT p.Name AS 'PropertyName', 
				t.ObjectID AS 'ObjectID',
				t.ObjectID AS 'TObjectID',
				p.PropertyID AS 'PropertyID',
				tt.[Group] AS 'ObjectType',
				null AS 'Unit',
				null AS 'PaddedNumber',
				pr.PreferredName + ' ' + pr.LastName AS 'Names',	
				null AS 'LeaseStatus',
				null AS 'MoveInDate',
				null AS 'LeaseEndDate',
				null AS 'NoticeToVacateDate',
				null AS 'MoveOutDate',
				null AS 'UnitRequiredDeposit',
				null AS 'LeaseRequiredDeposit',
				null AS 'DepositsPaidIn',
				null AS 'DepositsPaidOut'		
			FROM [Transaction] t 
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN Person pr ON t.ObjectID = pr.PersonID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = p.PropertyID
				INNER JOIN #ObjectTypes #ot ON #ot.[Type] = tt.[Group]
			WHERE ((@objectID IS NULL) OR (t.ObjectID = @objectID))
			  AND tt.Name IN ('Deposit')
			  AND tr.TransactionID IS NULL
	END
		
	UPDATE #DepositSummary SET DepositsPaidIn = (SELECT ISNULL(SUM(t.Amount), 0)
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID 
			--LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
		WHERE t.ObjectID = #DepositSummary.TObjectID
		  AND t.TransactionDate <= @date
		  AND tt.Name IN ('Deposit', 'Balance Transfer Deposit'/*, 'Deposit Interest Payment'*/)) -- Now we have a Deposit Interest Summary report so no need to report it here
		  --AND tr.TransactionID IS NULL)		 	

	UPDATE #DepositSummary SET DepositsPaidOut = (SELECT ISNULL(SUM(t.Amount), 0)
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			--LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			-- Not a refund or application of deposit interest
			LEFT JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
			LEFT JOIN TransactionType att ON att.TransactionTypeID = at.TransactionTypeID
			-- Not a reversal of a refund or application of deposit interest
			LEFT JOIN [Transaction] rt ON rt.TransactionID = t.ReversesTransactionID
			LEFT JOIN [Transaction] rtat ON rt.AppliesToTransactionID = rtat.TransactionID
			LEFT JOIN [TransactionType] rtattt  ON rtattt.TransactionTypeID = rtat.TransactionTypeID
		WHERE t.ObjectID =  #DepositSummary.TObjectID
		  AND t.TransactionDate <= @date
		  AND tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance')
		  AND (att.Name IS NULL OR att.Name <> 'Deposit Interest Payment')
		  AND (rtattt.Name IS NULL OR rtattt.Name <> 'Deposit Interest Payment')
		  )
		  --AND tr.TransactionID IS NULL)
		  
	UPDATE #DepositSummary SET LeaseRequiredDeposit = (SELECT ISNULL(SUM(lli.Amount), 0)
		FROM UnitLeaseGroup ulg 
			INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID
			INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
			INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
		WHERE ulg.UnitLeaseGroupID = #DepositSummary.TObjectID
		  AND lit.IsDeposit = 1)
		  
	SELECT PropertyName, ObjectID, PropertyID, ObjectType, Unit, Names, LeaseStatus, MoveInDate, LeaseEndDate, NoticeToVacateDate,
			MoveOutDate, ISNULL(UnitRequiredDeposit, 0) AS 'UnitRequiredDeposit', ISNULL(LeaseRequiredDeposit, 0) AS 'LeaseRequiredDeposit', 
			ISNULL(DepositsPaidIn, 0) AS 'DepositsPaidIn', ISNULL(DepositsPaidOut, 0) AS 'DepositsPaidOut'
		FROM #DepositSummary 
		ORDER BY PaddedNumber, Names

END
GO
