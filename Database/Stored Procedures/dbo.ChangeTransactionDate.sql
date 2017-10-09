SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






-- =============================================
-- Author:		Nick Olsen
-- Create date: August 5, 2016
-- Description:	Changes the date of a payment along with any related transactions
-- =============================================
CREATE PROCEDURE [dbo].[ChangeTransactionDate]
	-- Add the parameters for the stored procedure here
	@accountID bigint,	
	@transactionID uniqueidentifier,
	@date date,
	@canPostInPast bit,
	@canPostInFuture bit
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    	  
	CREATE TABLE #Dates ( [Date] date )
	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )

	IF ((SELECT Amount FROM [Transaction] WHERE TransactionID = @transactionID AND AccountID = @accountID) < 0)
	BEGIN
		 /*
		   Changing a reversal
		   To do
		   1. Transaction.TransactionDate of the transaction being changed
		   2. Update Payment.ReversedDate of the payment we are reversing
		   3. Update all Transactions associated with the reversal payment to the new date
		   4. Update all the Transactions of the associated payment that have a date greater than new reversal date to the reversal date
		 */		 

		INSERT INTO #Dates SELECT @date
		INSERT INTO #Dates SELECT TransactionDate FROM [Transaction] WHERE TransactionID = @transactionID
		INSERT INTO #Dates SELECT TransactionDate FROM [Transaction] WHERE AppliesToTransactionID IN (SELECT TransactionID FROM [Transaction] WHERE TransactionID IN (SELECT ReversesTransactionID FROM [Transaction] WHERE TransactionID = @transactionID))  AND TransactionDate > @date
		INSERT INTO #Dates SELECT TransactionDate FROM [Transaction] WHERE ReversesTransactionID IN (SELECT TransactionID FROM [Transaction] WHERE AppliesToTransactionID in (SELECT TransactionID FROM [Transaction] WHERE TransactionID IN (SELECT ReversesTransactionID FROM [Transaction] WHERE TransactionID = @transactionID))) AND TransactionDate > @date
		INSERT INTO #PropertyIDs SELECT DISTINCT PropertyID FROM [Transaction] WHERE TransactionID = @transactionID

		IF (EXISTS (
			SELECT *
			FROM PropertyAccountingPeriod pap
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = pap.PropertyID
				INNER JOIN #Dates #d ON pap.StartDate <= #d.[Date] AND pap.EndDate >= #d.[Date]
				INNER JOIN Property p ON p.PropertyID = #pids.PropertyID
				INNER JOIN PropertyAccountingPeriod cpap ON cpap.PropertyAccountingPeriodID = p.CurrentPropertyAccountingPeriodID
				-- Check that the period isn't closed
			WHERE pap.Closed = 1
				-- Can't post in the past or future
				OR (@canPostInPast = 0 AND cpap.StartDate > #d.[Date])
				OR (@canPostInFuture = 0 AND cpap.EndDate < #d.[Date])
		))
		BEGIN
			SELECT 0
			RETURN
		END
		
		UPDATE [Transaction] set TransactionDate = @date WHERE TransactionID IN  (
			SELECT @transactionID
			UNION
			SELECT TransactionID FROM [Transaction] WHERE AppliesToTransactionID IN (SELECT TransactionID FROM [Transaction] WHERE TransactionID IN (SELECT ReversesTransactionID FROM [Transaction] WHERE TransactionID = @transactionID))  AND TransactionDate > @date
			UNION
			SELECT TransactionID FROM [Transaction] WHERE ReversesTransactionID IN (SELECT TransactionID FROM [Transaction] WHERE AppliesToTransactionID in (SELECT TransactionID FROM [Transaction] WHERE TransactionID IN (SELECT ReversesTransactionID FROM [Transaction] WHERE TransactionID = @transactionID))) AND TransactionDate > @date
		)



		SELECT 1
	END
	ELSE
	BEGIN
		/* Changing a chaarge
		   To do
		   1. Update Payment.Date of the Payment
		   2. Update all the Transactions associated with the payment and set the TransactionDate 
		 */

		 -- Not doing this yet

		 SELECT 0
	END
END


GO
