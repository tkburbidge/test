SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetPaymentReceipt] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@id uniqueidentifier = null,
	@type nvarchar(50) = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PaymentInfo(
		PaymentID uniqueidentifier,
		PropertyName nvarchar(50),
		Reference nvarchar(25),
		[Date] date,
		Amount money,
		ConvenienceFee money,
		Account nvarchar(250),
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		PaymentType nvarchar(50),
		Payer nvarchar(250),
		[Description] nvarchar(100)
	)

	IF @type = 'ProcessorPayment'
	BEGIN
		INSERT #PaymentInfo
			SELECT DISTINCT 
					pp.ProcessorPaymentID AS 'PaymentID', 
					prop.Name as 'PropertyName', 
					pp.ProcessorTransactionID as 'Reference',					
					pp.DateProcessed AS 'Date',
					pp.Amount, 
					pp.Fee as 'ConvenienceFee', 
					CASE WHEN u.UnitID IS NOT NULL THEN u.Number + ' - '
						 ELSE '' END + pp.Payer AS 'Account',					
					prop.PropertyID,
					ulg.UnitID,
					pp.PaymentType,
					pp.Payer,
					NULL					
			FROM ProcessorPayment pp				
				INNER JOIN [Property] prop on pp.PropertyID = prop.PropertyID		
				LEFT JOIN [UnitLeaseGroup] ulg on pp.ObjectID = ulg.UnitLeaseGroupID
				LEFT JOIN [Unit] u ON u.UnitID = ulg.UnitID
			WHERE pp.AccountID = @accountID AND pp.ProcessorPaymentID = @id
	END
	ELSE IF @type = 'Payment'
	BEGIN
		INSERT #PaymentInfo
			SELECT DISTINCT p.PaymentID, 
				prop.Name as 'PropertyName', 
				p.ReferenceNumber as 'Reference', 
				p.[Date], 
				p.Amount,
				NULL, --ConvenienceFee
				--pp.Fee as 'ConvenienceFee', 
				--0 AS 'ConvenienceFee',
				p.ReceivedFromPaidTo as 'Account',
				prop.PropertyID,
				ulg.UnitID,
				p.[Type] AS 'PaymentType',
				p.ReceivedFromPaidTo AS 'Payer',
				p.[Description]
				--CASE
					--	WHEN (pp.ProcessorPaymentID IS NOT NULL) THEN pp.PaymentType
					--	ELSE p.[Type]
					--	END AS 'PaymentType',
					--CASE
					--	WHEN (pp.ProcessorPaymentID IS NOT NULL) THEN pp.Payer
					--	ELSE p.ReceivedFromPaidTo
					--	END AS 'Payer'
		FROM Payment p
			INNER JOIN [PaymentTransaction] pt on p.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t on pt.TransactionID = t.TransactionID
			INNER JOIN [Property] prop on t.PropertyID = prop.PropertyID
			--LEFT JOIN [ProcessorPayment] pp on p.PaymentID = pp.PaymentID
			LEFT JOIN [UnitLeaseGroup] ulg on t.ObjectID = ulg.UnitLeaseGroupID
		WHERE p.AccountID = @accountID AND p.PaymentID = @id
	END

	--Get Payment Receipt Info
	SELECT * FROM #PaymentInfo

	--Get ApplieD to Charges Info
	--based on linq query in PaymentService.GetDisplayablePaymentWithCharges
	SELECT DISTINCT
		att.TransactionDate AS 'Date',
		att.[Description] AS 'Description',
		att.Amount AS 'ChargeAmount',
		t.Amount AS 'AmountApplied'
	FROM PaymentTransaction pt
		INNER JOIN #PaymentInfo #pi ON pt.PaymentID = #pi.PaymentID
		INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
		INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name NOT IN('Balance Transfer Deposit', 'Balance Transfer Payment', 'Deposit Applied to Deposit', 'Deposit Applied to Balance')
		INNER JOIN [Transaction] att ON t.AppliesToTransactionID = att.TransactionID AND att.Origin <> 'T'
		LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
	WHERE pt.AccountID = @accountID
	  AND t.ReversesTransactionID IS NULL
	  AND tr.TransactionID IS NULL

END
GO
