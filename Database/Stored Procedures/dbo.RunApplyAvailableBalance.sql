SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: March 3, 2015
-- Description:	Runs ApplyAvailableBalance for all accounts with
--              outstanding payments
-- =============================================
CREATE PROCEDURE [dbo].[RunApplyAvailableBalance]
	@accountID bigint,
	@date date = null,
	@propertyID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF (@date IS NULL)
	BEGIN
		SET @date = GetDate()
	END

	DECLARE @properties TABLE 
	(
		ID int IDENTITY,
		AccountID bigint,
		PropertyID uniqueidentifier,
		Name nvarchar(100)
	)
	
	INSERT INTO @properties 
		SELECT DISTINCT p.AccountID, p.PropertyID, p.Name 
		FROM Property p
		-- Make sure the period is not closed and that we aren't running this for the last day of the month
		INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = p.PropertyID AND pap.StartDate <= @date AND pap.EndDate > @date
		WHERE p.AccountID = @accountID
			AND pap.AccountID = @accountID
			AND p.IsArchived = 0
			AND pap.Closed = 0
			AND (@propertyID IS NULL OR p.PropertyID = @propertyID)

	DECLARE @maxCtr int = (SELECT MAX(ID) FROM @properties)
	DECLARE @ctr int = 1

	WHILE @ctr <= @maxCtr
	BEGIN
		BEGIN TRAN
		BEGIN
			
			DECLARE @currentPropertyID uniqueidentifier
			DECLARE @name nvarchar(100)
			DECLARE @objectIDs GuidCollection
	
	
			SELECT @accountID = AccountID,
				   @currentPropertyID = PropertyID,
				   @name = Name
			FROM @properties
			WHERE ID = @ctr		   		
	
			DECLARE @personID uniqueidentifier = (SELECT TOP 1 PersonID FROM Person WHERE AccountID = @accountID and FirstName = 'Admin')	

			CREATE TABLE #TempPayments2 (
					CurrentPayment		int identity,
					ObjectID			uniqueidentifier		NOT NULL,
					TransactionID		uniqueidentifier		NOT NULL,
					PaymentID			uniqueidentifier		NOT NULL,
					TTName				nvarchar(25)			NOT NULL,
					TransactionTypeID	uniqueidentifier		NOT NULL,
					Amount				money					NOT NULL,
					Reference			nvarchar(50)			NULL,
					LedgerItemTypeID	uniqueidentifier		NULL,
					[Description]		nvarchar(1000)			NULL,
					Origin				nvarchar(50)			NULL,
					PaymentDate			date					NULL,
					PostingBatchID		uniqueidentifier		NULL,
					Allocated			bit						NOT NULL,
					AppliesToLedgerItemTypeID uniqueidentifier	NULL,
					LedgerItemTypeAbbreviation	nvarchar(50)	NULL,
					GLNumber			nvarchar(50)			NULL,
					GLAccountID			uniqueidentifier		NULL,
					TaxRateID			uniqueidentifier	    NULL)
			
			INSERT INTO #TempPayments2 EXEC GetUnappliedPayments @accountID, @currentPropertyID, null, 'Lease', null
			DELETE FROM @objectIDs
			INSERT INTO @objectIDs select distinct ObjectID FROM #TempPayments2	

			DROP TABLE #TempPayments2
			
			EXEC ApplyAvailableBalance @objectIDs, @personID, @date					   		
			SET @ctr = @ctr + 1

			END
		IF @@ERROR <> 0
		BEGIN
			ROLLBACK
		END
		ELSE
		BEGIN
			COMMIT
		END	


	END

			   					   


END
GO
