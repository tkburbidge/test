SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 27, 2013
-- Description:	Gets the next batch number for a deposit batch on a given date.
-- It doesn't worry about the accounting period this might occer in.
-- =============================================
CREATE FUNCTION [dbo].[GetNextBankDepositBatch] 
(
	-- Add the parameters for the function here
	@accountID bigint,
	@bankAccountID uniqueidentifier,
	@date date
)
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @returnVal int
	
	
	
	
	SET @returnVal = (SELECT ISNULL((SELECT CAST(MAX(Number) AS INT) + 1
										FROM Batch b
											INNER JOIN BankTransactionTransaction btt ON btt.BankTransactionID = b.BankTransactionID
											INNER JOIN [Transaction] t ON t.TransactionID = btt.TransactionID
										WHERE b.BankTransactionID IS NOT NULL				-- Exclude Invoice Batches										  
										  AND t.ObjectID = @bankAccountID					-- Deposit is tied to the bank account
										  AND b.Number LIKE SUBSTRING(CONVERT(NVARCHAR(6), @date, 112),1,7) + '%'),										  
									SUBSTRING(CONVERT(NVARCHAR(6), @date, 112),1,7) + '001'))

	RETURN @returnVal
END

GO
