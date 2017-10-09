SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 4, 2012
-- Description:	Gets the resident register by accounting period
-- =============================================
CREATE PROCEDURE [dbo].[GetSummaryLedger] 
	-- Add the parameters for the stored procedure here
	@objectID uniqueidentifier
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @propertyIDs GuidCollection
	DECLARE @minDate DATE
	DECLARE @maxDate DATE
	DECLARE @accountID BIGINT
	
	INSERT @propertyIDs SELECT TOP 1 PropertyID FROM [Transaction] WHERE ObjectID = @objectID
	SELECT @accountID = AccountID, @minDate = MIN(TransactionDate), @maxDate = MAX(TransactionDate)
		FROM [Transaction] 
		WHERE ObjectID = @objectID
		GROUP BY ObjectID, AccountID

	CREATE TABLE #ResidentRegister (		
		PeriodEndDate date null,
		Balance money null,
		RunningBalance money null,
		Late bit null,
		DelinquentNotes nvarchar(500) null,
		PrepaidNotes nvarchar(500) null,
		AccountingPeriodID uniqueidentifier null,
		ULGAPInformationID uniqueidentifier null,
		DoNotAssessLateFees bit null,
		NSFCount tinyint null,
		StartDate date null,
		EndDate date null,
		ImportTimesLate int not null,
		ImportNSFCount int not null)
		
	INSERT INTO #ResidentRegister 
		SELECT DISTINCT 				
				ap.EndDate AS 'PeriodEndDate',
				--Bal.Balance AS 'Balance',
				0.00 AS 'Balance',
				0.00 AS 'RunningBalance',
				ulgapInfo.Late AS 'Late',
				ulgapInfo.DelinquentReason,
				ulgapInfo.PrepaidReason,				
				ap.AccountingPeriodID AS 'AccountingPeriodID',
				ulgapInfo.ULGAPInformationID AS 'ULGAPInformationID',
				ulgapInfo.DoNotAssessLateFees AS 'DoNotAssessLateFees',
				((SELECT COUNT(DISTINCT p.PaymentID) 
				FROM Payment p					
					INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
					INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
					LEFT JOIN PersonNote pn ON p.PaymentID = pn.ObjectID AND pn.InteractionType = 'Waived NSF'
				WHERE pap.StartDate <= p.[Date]
					AND pap.EndDate >= p.[Date]
					AND p.[Type] = 'NSF'
					AND pn.PersonNoteID IS NULL
					AND p.ObjectID = @objectID)) AS 'NSFCount',
				ap.StartDate AS 'StartDate',
				ap.EndDate AS 'EndDate',
				0 AS 'ImportTimesLate',
				0 AS 'ImportNSFCount'
			FROM AccountingPeriod ap 
				INNER JOIN Property p ON p.PropertyID = (SELECT Value FROM @propertyIDs)
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND ap.AccountingPeriodID = pap.AccountingPeriodID
				LEFT JOIN ULGAPInformation ulgapInfo ON ulgapInfo.ObjectID = @objectID AND ap.AccountingPeriodID = ulgapInfo.AccountingPeriodID 
				--CROSS APPLY GetObjectBalance(ap.StartDate, ap.EndDate, @objectID, 0, @propertyIDs) AS Bal
			WHERE ap.AccountID = @accountID
			  AND pap.StartDate <= @maxDate
			  AND pap.EndDate >= @minDate
			  
	UPDATE #rr SET Balance = Bal.Balance
		FROM #ResidentRegister #rr
			CROSS APPLY GetObjectBalance(StartDate, EndDate, @objectID, 0, @propertyIDs) AS Bal

	UPDATE #r1 SET RunningBalance = (SELECT ISNULL(SUM(#r2.Balance), 0) + #r1.Balance FROM #ResidentRegister #r2 WHERE #r2.PeriodEndDate < #r1.PeriodEndDate)
		FROM #ResidentRegister #r1
	
	UPDATE #r1 SET ImportTimesLate = ISNULL(ulg.ImportTimesLate, 0),
				   ImportNSFCount = ISNULL(ulg.ImportNSFCount, 0)
		FROM #ResidentRegister #r1
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = @objectID
	
	SELECT PeriodEndDate, 
		   RunningBalance AS 'Balance', 
		   ISNULL(Late, 0) AS 'Late', 
		   CASE WHEN RunningBalance >= 0 THEN DelinquentNotes
				ELSE PrepaidNotes				
		   END AS 'Notes', 
		   AccountingPeriodID, 
		   ULGAPInformationID,
		   DoNotAssessLateFees,
		   NSFCount,
		   ImportTimesLate, 
		   ImportNSFCount
		FROM #ResidentRegister ORDER BY PeriodEndDate
END


GO
