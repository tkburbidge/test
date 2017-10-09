SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: April 22, 2016
-- Description: Gets the adjustments needed for the GPR to Cash Rec report
-- =============================================
CREATE PROCEDURE [dbo].[GetGPRToCashReconciliationAdjustments]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier,
	@startDate date,
	@endDate date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Adjustment (
		[Type] nvarchar(100) null,
		[Amount] money
	)
   
	INSERT INTO #Adjustment
		SELECT
			'OutsideMonthPayment',
			SUM(Amount)
		FROM 
			(SELECT DISTINCT	
				p.PaymentID,
				t.PropertyID,				
				b.[Date] AS 'BatchDate', 		
				p.[Date] AS 'PaymentDate', 
				b.BankTransactionID, 
				p.Amount
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
				INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
				INNER JOIN Batch b ON b.BatchID = p.BatchID		
			WHERE (p.[Date] < @startDate OR p.[Date] > @endDate)
				AND t.PropertyID = @propertyID
				AND (b.[Date] >= @startDate AND b.[Date] <= @endDate)) t
	
	
	INSERT INTO #Adjustment
		SELECT
			'OutsideMonthDeposit',
			-SUM(Amount)
		FROM 
			(SELECT DISTINCT
				p.PaymentID,
				t.PropertyID,
				'OutsideMonthDeposit' AS 'Type',
				b.[Date] AS 'BatchDate',		 
				p.[Date] AS 'PaymentDate', 
				b.BankTransactionID, 
				p.Amount
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
				INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
				INNER JOIN Batch b ON b.BatchID = p.BatchID		
			WHERE p.[Date] >= @startDate
				AND p.[Date] <= @endDate
				AND t.PropertyID = @propertyID
				AND (b.[Date] < @startDate OR b.[Date] > @endDate)
				-- Get payments made out side the month or reversals if the reversal
				-- was a Posting Error or Other
				AND (p.Amount > 0 OR p.[Type] IN ('Posting Error', 'Other'))
				) t

	INSERT INTO #Adjustment
		SELECT
			'UndepositedPayment',
			-SUM(Amount)
		FROM
			(SELECT DISTINCT
				p.PaymentID,
				t.PropertyID,							
				p.Amount
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
				INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID	
				INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
			WHERE p.[Date] >= @startDate
				AND p.[Date] <= @endDate
				AND tt.Name IN ('Payment', 'Deposit')
				AND tt.[Group] IN ('Lease', 'Non-Resident Account', 'WOIT Account', 'Prospect')
				AND t.PropertyID = @propertyID
				AND p.BatchID IS NULL) t

	SELECT 
		[Type],
		ISNULL(Amount, 0) AS 'Amount'	
	FROM #Adjustment

END
GO
