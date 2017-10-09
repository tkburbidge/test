SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: December 23, 2011
-- Description:	Gets the balance for a given bank account
-- =============================================
CREATE PROCEDURE [dbo].[GetBankAccountBalance]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@bankAccountID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @transactions TABLE
	(
		ObjectID uniqueidentifier,
		BankTransactionID uniqueidentifier,
		--PropertyID uniqueidentifier,
		--PropertyAbbreviation nvarchar(50),
		[Date] date,
		[Type] nvarchar(50),
		[Group] nvarchar(50),
		TransactionType nvarchar(50),
		Reference nvarchar(50),
		ClearedDate date NULL,
		BankReconciliationID uniqueidentifier NULL,
		[Description] nvarchar(500),
		Amount money,
		CheckVoidedDate date NULL, 
		IsAddition bit NOT NULL,
		BTimeStamp datetime NOT NULL,
		Category nvarchar(200),
		BankFileID nvarchar(100) NULL,
		IsVoidingTransaction bit null
	)

	INSERT INTO @transactions
	EXEC GetBankTransactionLedger @accountID, @bankAccountID, @startDate, @endDate, null

	SELECT ISNULL(SUM(
			CASE WHEN IsAddition = 0 AND Amount > 0 THEN -Amount
				ELSE Amount END)			
			, 0) FROM @transactions
END
GO
