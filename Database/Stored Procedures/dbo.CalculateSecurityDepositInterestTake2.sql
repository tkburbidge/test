SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO











-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan 14, 2014
-- Description:	Calculates the interest on cetain securiy deposits
-- =============================================
CREATE PROCEDURE [dbo].[CalculateSecurityDepositInterestTake2] 
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null, 
	@objectIDs GuidCollection READONLY,
	@date date = null
AS

DECLARE @objectCtr int = 1
DECLARE @objectMax int
DECLARE @appCtr int = 1
DECLARE @appMax int
DECLARE @currentTransDate date
DECLARE @objectID uniqueidentifier
DECLARE @interestFormulaID uniqueidentifier
DECLARE @MoveInProration nvarchar(25)
DECLARE @MoveOutProration nvarchar(25)

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #ObjectIDs (
		[Sequence] int identity,
		ObjectID uniqueidentifier not null,
		MoveInDate date null,
		MoveOutDate date null, 
		DepositsHeld money null,
		TotalAmount money null,
		ConversionDepositInterestRefund money null)

	CREATE TABLE #DepositInterestsAll (
		UnitLeaseGroupID uniqueidentifier not null,
		TransactionID uniqueidentifier not null,
		LedgerItemTypeID uniqueidentifier null,
		DepositBalance money null,
		Origin nvarchar(2) null, 
		StartDate date null, 
		TimeStamp datetime null)
		
	CREATE TABLE #DepositInterests (
		[Sequence] int identity,
		UnitLeaseGroupID uniqueidentifier not null,
		TransactionID uniqueidentifier not null,
		LedgerItemTypeID uniqueidentifier null,
		DepositBalance money null,
		Origin nvarchar(2) null, 
		StartDate date null, 
		TimeStamp datetime null)

	CREATE TABLE #DepositApplicationsAll (
		Sequence int identity,
		UnitLeaseGroupID uniqueidentifier not null,
		TransactionID uniqueidentifier not null,
		AppliedTransactionID uniqueidentifier not null,
		Amount money not null,
		TransDate date not null,
		TimeStamp datetime null)
		
	CREATE TABLE #DepositApplications (
		Sequence int identity,
		UnitLeaseGroupID uniqueidentifier not null,
		TransactionID uniqueidentifier not null,
		AppliedTransactionID uniqueidentifier not null,
		Amount money not null,
		TransDate date not null,
		TimeStamp datetime null)

	CREATE TABLE #AResident (
		AResidentID				uniqueidentifier,
		ULGID					uniqueidentifier,
		ActionJackson			nvarchar(5),
		DepositBalance			money,
		BalanceStartDate		date,
		BalanceEndDate			date,
		Rate					decimal(7, 4),
		DailyRate				decimal(15, 12),
		DailyAmount				decimal(19, 17)
		)

	CREATE TABLE #AResident2 (
		[Sequence]				int identity,
		AResidentID				uniqueidentifier,
		ULGID					uniqueidentifier,
		ActionJackson			nvarchar(5),
		DepositBalance			money,
		BalanceStartDate		date,
		BalanceEndDate			date,
		Rate					decimal(7, 4),
		DailyRate				decimal(16, 12),
		DailyAmount				decimal(21, 17)
		)

	SET @interestFormulaID = (SELECT DepositInterestFormulaID FROM Property WHERE PropertyID = @propertyID)
	SET @MoveInProration = (SELECT FirstMonthProrate FROM InterestFormula WHERE InterestFormulaID = @interestFormulaID)
	SET @MoveOutProration = (SELECT LastMonthProrate FROM InterestFormula WHERE InterestFormulaID = @interestFormulaID)

	INSERT #ObjectIDs
		SELECT Value, null, null, null, null, null FROM @objectIDs ORDER BY Value
		

	INSERT #DepositInterestsAll 
		SELECT	DISTINCT
				#oids.ObjectID, t.TransactionID, t.LedgerItemTypeID, t.Amount, t.Origin, t.TransactionDate, t.TimeStamp
			FROM #ObjectIDs #oids
				INNER JOIN [Transaction] t ON #oids.ObjectID = t.ObjectID
				INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsDeposit = 1
				INNER JOIN LedgerItemTypeProperty litp ON lit.LedgerItemTypeID = litp.LedgerItemTypeID AND t.PropertyID = litp.PropertyID
										AND litp.IsInterestable = 1
				LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				INNER JOIN Lease l ON t.ObjectID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted')
			WHERE t.PropertyID = @propertyID
			  AND tr.TransactionID IS NULL
			  AND t.ReversesTransactionID IS NULL
			ORDER BY t.TransactionDate

	-- Get Balance Transfer Deposits

	INSERT #DepositInterestsAll 
		SELECT	DISTINCT
				#oids.ObjectID, t.TransactionID, t.LedgerItemTypeID, t.Amount, t.Origin, t.TransactionDate, t.TimeStamp
			FROM #ObjectIDs #oids
				INNER JOIN [Transaction] t ON #oids.ObjectID = t.ObjectID AND t.LedgerItemTypeID IS NULL
				INNER JOIN [TransactionType] tt on tt.TransactionTypeID = t.TransactionTypeID AND tt.Name = 'Balance Transfer Deposit' AND t.LedgerItemTypeID IS NULL
				INNER JOIN JournalEntry je ON je.TransactionID = t.TransactionID				
				INNER JOIN LedgerItemTypeProperty litp ON t.PropertyID = litp.PropertyID AND litp.IsInterestable = 1
				INNER JOIN LedgerItemType lit ON litp.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsDeposit = 1 AND je.GLAccountID = lit.GLAccountID
				LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				INNER JOIN Lease l ON t.ObjectID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted')
			WHERE t.PropertyID = @propertyID
			  AND tr.TransactionID IS NULL
			  AND t.ReversesTransactionID IS NULL


	UPDATE #ObjectIDs SET MoveInDate = (SELECT MIN(pl.MoveInDate)
												  FROM PersonLease pl
													  INNER JOIN Lease l ON pl.LeaseID = l.LeaseID AND l.UnitLeaseGroupID = #ObjectIDs.ObjectID
												  WHERE pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))

	-- Update move out date for people who moved out
	UPDATE #ObjectIDs SET MoveOutDate = (SELECT MAX(pl.MoveOutDate)
													FROM PersonLease pl
														INNER JOIN Lease l ON pl.LeaseID = l.LeaseID AND l.UnitLeaseGroupID = #ObjectIDs.ObjectID AND l.LeaseStatus IN ('Former', 'Evicted')
													WHERE pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))	
			
	UPDATE #ObjectIDs SET MoveOutDate = @date
		WHERE MoveOutDate IS NULL
		
	IF (@MoveInProration = 'Full')
	BEGIN
		UPDATE #ObjectIDs SET MoveInDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, MoveInDate), 0)
			WHERE DATEPART(DAY, MoveInDate) <> 1
	END
	ELSE IF (@MoveInProration = 'None')
	BEGIN
		UPDATE #ObjectIDs SET MoveInDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(MONTH, 1, MoveInDate)), 0)
			WHERE DATEPART(DAY, MoveInDate) <> 1
	END

	IF (@MoveOutProration = 'Full')
	BEGIN
		UPDATE #ObjectIDs SET MoveOutDate = DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(MONTH, 1, MoveOutDate)), 0))
			WHERE DATEPART(DAY, MoveOutDate) <> DATEPART(DAY, DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(MONTH, 1, MoveOutDate)), 0)))
	END
	ELSE IF (@MoveOutProration = 'None')
	BEGIN
		UPDATE #ObjectIDs SET MoveOutDate = DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, MoveOutDate), 0))
			WHERE DATEPART(DAY, MoveOutDate) <> DATEPART(DAY, DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(MONTH, 1, MoveOutDate)), 0)))
	END
			

	-- Update the start date of the deposit to the move in date
	-- for imported transactions
	UPDATE #DI SET StartDate = #O.MoveInDate
		FROM #DepositInterestsAll #DI
			INNER JOIN #ObjectIDs #O ON #DI.UnitLeaseGroupID = #O.ObjectID
		WHERE #DI.Origin = 'M'

	UPDATE #O SET ConversionDepositInterestRefund = ulg.ConversionDepositInterestRefund
		FROM #ObjectIDs #O
			INNER JOIN UnitLeaseGroup ulg ON #O.ObjectID = ulg.UnitLeaseGroupID

	SET @objectMax = (SELECT MAX([Sequence]) FROM #ObjectIDs)

	WHILE (@objectCtr <= @objectMax)
	BEGIN
		SELECT @objectID = ObjectID FROM #ObjectIDs WHERE [Sequence] = @objectCtr

		TRUNCATE TABLE #AResident
		TRUNCATE TABLE #AResident2
		TRUNCATE TABLE #DepositInterests
		TRUNCATE TABLE #DepositApplications

		INSERT #DepositInterests
			SELECT *
				FROM #DepositInterestsAll
				WHERE UnitLeaseGroupID = @objectID
				ORDER BY StartDate

		INSERT #DepositApplications 
			SELECT	DISTINCT
					#di.UnitLeaseGroupID, #di.TransactionID, ta.TransactionID, ta.Amount, ta.TransactionDate, ta.TimeStamp
				FROM #DepositInterests #di
					INNER JOIN [Transaction] ta ON #di.TransactionID = ta.AppliesToTransactionID
					INNER JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID AND Name in ('Deposit Applied to Balance', 'Deposit Refund', 'Balance Transfer Payment')
					LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
				WHERE tar.TransactionID IS NULL
					AND ta.ReversesTransactionID IS NULL
				ORDER BY ta.TransactionDate, ta.TimeStamp

	-- Set the application date of all applications after the move out date 
	-- to the move out date.  We stop accruing interest on the move out date
	UPDATE #da 
		SET TransDate = #O.MoveOutDate
		FROM #DepositApplications #da
			INNER JOIN #ObjectIDs #O ON #da.UnitLeaseGroupID = #O.ObjectID
		WHERE #da.TransDate > #O.MoveOutDate		

		SET @appCtr = 1
		SET @appMax = (SELECT MAX(Sequence) FROM #DepositInterests)
		SET @currentTransDate = NULL

		WHILE (@appCtr <= @appMax)
		BEGIN
			SET @currentTransDate = (SELECT StartDate FROM #DepositInterests WHERE [Sequence] = @appCtr)
		
			IF (@currentTransDate IS NOT NULL)
			BEGIN
				UPDATE #DepositInterests SET DepositBalance = (SELECT SUM(#di.DepositBalance)
																  FROM #DepositInterests #di
																  WHERE #di.[Sequence] >= @appCtr
																	AND #di.StartDate = @currentTransDate)
					WHERE [Sequence] = @appCtr
			END

			DELETE #DepositInterests 
				WHERE StartDate = @currentTransDate
				  AND [Sequence] > @appCtr

			SET @appCtr = @appCtr + 1	
		END

		SET @appCtr = 1
		SET @appMax = (SELECT MAX(Sequence) FROM #DepositApplications)
		SET @currentTransDate = NULL

		-- Sum up all of the applications of a given day, and delete the extras.
		WHILE (@appCtr <= @appMax)
		BEGIN
			SET @currentTransDate = (SELECT TransDate FROM #DepositApplications WHERE [Sequence] = @appCtr)
		
			IF (@currentTransDate IS NOT NULL)
			BEGIN
				UPDATE #DepositApplications SET Amount = (SELECT SUM(#da.Amount)
															  FROM #DepositApplications #da
															  WHERE #da.[Sequence] >= @appCtr
																AND #da.TransDate = @currentTransDate)
					WHERE [Sequence] = @appCtr
			END

			DELETE #DepositApplications 
				WHERE TransDate = @currentTransDate
				  AND [Sequence] > @appCtr

			SET @appCtr = @appCtr + 1
		END


		INSERT #AResident
			SELECT newID(),	UnitLeaseGroupID, 'D', DepositBalance, StartDate, null, null, null, null
				FROM #DepositInterests 
				WHERE UnitLeaseGroupID = @objectID
				  AND DepositBalance > 0
				ORDER BY StartDate, [TimeStamp]

		INSERT #AResident
			SELECT newid(),	UnitLeaseGroupID, 'A', Amount, TransDate, null, null, null, null
				FROM #DepositApplications
				WHERE UnitLeaseGroupID = @objectID
				  AND Amount > 0
				ORDER BY TransDate, [TimeStamp]

		UPDATE #AR1 SET #AR1.BalanceEndDate = DATEADD(DAY, -1, #AR2.BalanceStartDate)
			FROM #AResident #AR1
				LEFT JOIN #AResident #AR2 ON #AR1.ULGID = #AR2.ULGID AND #AR1.BalanceStartDate < #AR2.BalanceStartDate
				LEFT JOIN #AResident #ARSkip ON #AR1.ULGID = #ARSkip.ULGID AND #AR1.BalanceStartDate < #ARSkip.BalanceStartDate AND #ARSkip.BalanceStartDate < #AR2.BalanceStartDate
			WHERE #ARSkip.AResidentID IS NULL

		INSERT #AResident2
			SELECT * FROM #AResident ORDER BY BalanceStartDate

		DECLARE @i int = 2
		DECLARE @m int = (SELECT MAX([Sequence]) FROM #AResident2)

		UPDATE #AR2 SET BalanceEndDate = CASE WHEN (#O.MoveOutDate < @date) THEN #O.MoveOutDate ELSE @date END
			FROM #AResident2 #AR2
				INNER JOIN #ObjectIDs #O ON #AR2.ULGID = #O.ObjectID
			WHERE #AR2.[Sequence] = @m

		WHILE (@i <= @m)
		BEGIN
			UPDATE #AR2 SET DepositBalance = #AR1.DepositBalance - CASE WHEN (#AR2.ActionJackson = 'A') THEN #AR2.DepositBalance WHEN (#AR2.ActionJackson = 'D') THEN -#AR2.DepositBalance END
				FROM #AResident2 #AR2
					INNER JOIN #AResident2 #AR1 ON #AR1.[Sequence] = @i - 1
				WHERE #AR2.[Sequence] = @i

			SET @i = @i + 1
		END

		INSERT #AResident2
			SELECT NEWID(), #AR2.ULGID, 'I', #AR2.DepositBalance, ifi.StartDate, NULL, ifi.Percentage, NULL, NULL
				FROM #AResident2 #AR2
					INNER JOIN InterestFormulaItem ifi ON ifi.InterestFormulaID = @interestFormulaID AND (ifi.StartDate > #AR2.BalanceStartDate AND ifi.StartDate < #AR2.BalanceEndDate OR ifi.StartDate > #AR2.BalanceStartDate AND ifi.StartDate < #AR2.BalanceEndDate)

		UPDATE #AR1 SET BalanceStartDate = #O.MoveInDate
			FROM #AResident2 #AR1
				INNER JOIN #ObjectIDs #O ON #AR1.ULGID = #O.ObjectID
			WHERE #AR1.BalanceStartDate < #O.MoveInDate

		DELETE #AResident2
			WHERE BalanceEndDate < BalanceStartDate

		UPDATE #AR1 SET #AR1.BalanceEndDate = DATEADD(DAY, -1, #AR2.BalanceStartDate)
			FROM #AResident2 #AR1
				LEFT JOIN #AResident2 #AR2 ON #AR1.ULGID = #AR2.ULGID AND #AR1.BalanceStartDate < #AR2.BalanceStartDate
				LEFT JOIN #AResident2 #ARSkip ON #AR1.ULGID = #ARSkip.ULGID AND #AR1.BalanceStartDate < #ARSkip.BalanceStartDate AND #ARSkip.BalanceStartDate < #AR2.BalanceStartDate
			WHERE #ARSkip.AResidentID IS NULL

		--UPDATE #AResident2 SET BalanceEndDate = GETDATE() WHERE BalanceEndDate IS NULL
		UPDATE #AR2 SET BalanceEndDate = CASE WHEN (#O.MoveOutDate < @date) THEN #O.MoveOutDate ELSE @date END
			FROM #AResident2 #AR2
				INNER JOIN #ObjectIDs #O ON #AR2.ULGID = #O.ObjectID
			WHERE #AR2.BalanceEndDate IS NULL

		DELETE #AR2
			FROM #AResident2 #AR2
				INNER JOIN #ObjectIDs #O ON #AR2.ULGID = #O.ObjectID
			WHERE #AR2.BalanceStartDate > #O.MoveOutDate

		UPDATE #AR2	SET BalanceEndDate = #O.MoveOutDate
			FROM #AResident2 #AR2
				INNER JOIN #ObjectIDs #O ON #AR2.ULGID = #O.ObjectID
			WHERE #AR2.BalanceEndDate > #O.MoveOutDate

		UPDATE #AR2 SET Rate = ifi.Percentage
			FROM #AResident2 #AR2
				INNER JOIN InterestFormulaItem ifi ON ifi.InterestFormulaID = @interestFormulaID AND #AR2.BalanceEndDate >= ifi.StartDate AND #AR2.BalanceEndDate <= ifi.EndDate

		UPDATE #AResident2 SET DailyRate = Rate / 36500.00

		UPDATE #AResident2 SET DailyAmount = CAST(DATEDIFF(DAY, BalanceStartDate, BalanceEndDate) + 1 AS DECIMAL(15, 10)) * DailyRate * DepositBalance

		UPDATE #ObjectIDs SET TotalAmount = (SELECT CAST(SUM(DailyAmount) AS MONEY) 
												FROM #AResident2
												WHERE #AResident2.ULGID = #ObjectIDs.ObjectID)
		WHERE #ObjectIDs.ObjectID = @objectID

		-- Get the last Deposit Held amount
		UPDATE #ObjectIDs SET DepositsHeld = (SELECT TOP 1 DepositBalance
												FROM #AResident2
												WHERE #AResident2.ULGID = #ObjectIDs.ObjectID
													AND #AResident2.ULGID = @objectID
												ORDER BY BalanceEndDate DESC, [Sequence] DESC)
												  --AND [Sequence] = (SELECT MAX([Sequence]) FROM #AResident2 WHERE #AResident2.ULGID = @objectID))
			WHERE #ObjectIDs.ObjectID = @objectID


		SET @objectCtr = @objectCtr + 1
--SELECT * FROM #AResident
--SELECT * FROM #AResident2 order by BalanceStartDate
--SELECT * FROM #ObjectIDs

	END


	SELECT ObjectID, ROUND(ISNULL(TotalAmount, 0), 2) AS 'TotalInterestDue', ROUND(ISNULL(DepositsHeld, 0), 2) AS 'DepositsHeld', ROUND(ISNULL(ConversionDepositInterestRefund, 0),2) AS 'ConversionDepositInterestRefund'
		FROM #ObjectIDs
		
END




GO
