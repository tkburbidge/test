SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 3, 2013
-- Description:	Adds a ProcessorPayment record and determines what type it is.
--				Then it creates a payment batch and imports that batch.
-- =============================================
CREATE PROCEDURE [dbo].[ProcessAptexxTransactions]
	-- Add the parameters for the stored procedure here
	@aptexxPayments AptexxPaymentCollection READONLY, 
	@accountID bigint = 0,
	@integrationPartnerItemID int = 0,
	@propertyID uniqueidentifier = null,
	@date datetime = null,
	@description nvarchar(200) = null
AS

DECLARE @onlinePaymentLedgerItemTypeID uniqueidentifier
DECLARE @onlineDepositLedgerItemTypeID uniqueidentifier
DECLARE @defaultLedgerItemTypeID uniqueidentifier
DECLARE @integrationPartnerID int
DECLARE @paymentsToPost PostingBatchPaymentCollection
DECLARE @postingBatchID uniqueidentifier
DECLARE @settlementAmount money
DECLARE @missingAptexxPayments AptexxPaymentCollection 
DECLARE @paymentDescription nvarchar(100)
DECLARE @transactionOrigin nchar(1)
DECLARE @ctr int
DECLARE @maxCtr int
DECLARE @myPropertyID uniqueidentifier
DECLARE @missingAptexxPaymentsByProperty AptexxPaymentCollection


BEGIN

	SELECT @integrationPartnerID = IntegrationPartnerID FROM IntegrationPartnerItem WHERE IntegrationPartnerItemID = @integrationPartnerItemID
	SELECT @onlinePaymentLedgerItemTypeID = DefaultPortalPaymentLedgerItemTypeID, @onlineDepositLedgerItemTypeID = DefaultPortalDepositLedgerItemTypeID FROM Settings WHERE AccountID = @accountID	

	-- Processing an Aptexx Application Fee or Rent payment
	IF (@integrationPartnerItemID = 31 OR @integrationPartnerItemID = 32)
	BEGIN
		SET @defaultLedgerItemTypeID = @onlinePaymentLedgerItemTypeID
		SET @paymentDescription = ' Payment'
		SET @transactionOrigin = 'X'
	END
	-- Processing an Aptexx Deposit payment
	ELSE IF (@integrationPartnerItemID = 33)
	BEGIN
		SET @defaultLedgerItemTypeID = @onlineDepositLedgerItemTypeID	
		SET @paymentDescription = ' Deposit'
		SET @transactionOrigin = 'X'
	END
	ELSE IF (@integrationPartnerItemID = 29 OR @integrationPartnerItemID = 149)
	BEGIN
		SET @defaultLedgerItemTypeID = @onlinePaymentLedgerItemTypeID
		SET @paymentDescription = ' Payment'
		SET @transactionOrigin = 'S'
	END
	ELSE IF (@integrationPartnerItemID = 150)
	BEGIN
		SET @defaultLedgerItemTypeID = @onlineDepositLedgerItemTypeID	
		SET @paymentDescription = ' Deposit'
		SET @transactionOrigin = 'S'
	END
	

	CREATE TABLE #PaymentsForProcessing (
		ReferenceNumber nvarchar(50) null,		
		ExternalID nvarchar(50) null,			-- Used in AddProcessPaymentRecords but not needed - can be removed. For anyone but Aptexx, pass in NULL
		PayerID uniqueidentifier null,			-- ObjectID in Transaction.ObjectID
		[Date] datetime null,
		GAmount money null,
		NAmount money null,
		PaymentType nvarchar(50),
		LedgerItemTypeID uniqueidentifier null,
		ProcessorPaymentID uniqueidentifier null,
		PaymentID uniqueidentifier null,
		PayerPersonID uniqueidentifier null,
		AptexxPayerID nvarchar(100) null,
		Part1 uniqueidentifier null,
		Part2 uniqueidentifier null,
		PropertyID uniqueidentifier null
		)--,
		--NewAdd bit null)
		
	CREATE TABLE #AllMyProperties (
		Sequence int identity,
		PropertyID uniqueidentifier not null)
		
	-- Add all the Payments joining in the Payment table to get a PaymentID
	INSERT #PaymentsForProcessing 
		SELECT atPP.PaymentID, atPP.ExternalID, atPP.PayerID, atPP.[Date], atPP.GrossAmount, atPP.NetAmount, atPP.PaymentType, 
				atPP.LedgerItemTypeID, pp.ProcessorPaymentID, py.PaymentID, atPP.PayerPersonID, atPP.AptexxPayerID, null, null, null
			FROM @aptexxPayments atPP
				LEFT JOIN ProcessorPayment pp ON pp.ProcessorTransactionID = atPP.PaymentID
				LEFT JOIN Payment py ON pp.PaymentID = py.PaymentID
				
	UPDATE #PaymentsForProcessing SET Part1 = CAST(SUBSTRING(AptexxPayerID, 1, 36) AS uniqueidentifier), 
									  Part2 = CAST(Substring(AptexxPayerID, 38, 36) AS uniqueidentifier)
			
	-- If the payment belongs to a UnitLeaseGroup,
	-- Part1 = UnitLeaseGroupID
	-- Part2 = PersonID									  
	UPDATE #p4p SET PropertyID = ut.PropertyID
		FROM #PaymentsForProcessing #p4p
			INNER JOIN UnitLeaseGroup ulg ON #p4p.Part1 = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	
	-- For all the rest
	-- Part1 = PersonID/WOITAccountID
	-- Part2 = PropertyID		
	UPDATE #PaymentsForProcessing SET PropertyID = Part2, PayerPersonID = Part1	
		WHERE PropertyID IS NULL								
				
-- We need to do this later now!
	-- Create the collection of new payments that need to be posted			
	--INSERT @missingAptexxPayments 
	--	SELECT ReferenceNumber, ExternalID, PayerID, [Date], GAmount, NAmount, null, PaymentType, COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID), PayerPersonID, AptexxPayerID
	--		FROM #PaymentsForProcessing
	--		WHERE ProcessorPaymentID IS NULL			
	
	-- If needed, add the ProcessorPayment records
	--IF ((SELECT COUNT(*) FROM @missingAptexxPayments) > 0)
	IF ((SELECT COUNT(*) FROM #PaymentsForProcessing WHERE ProcessorPaymentID IS NULL) > 0)
	BEGIN			
		INSERT #AllMyProperties
			SELECT DISTINCT PropertyID 
				FROM #PaymentsForProcessing
				WHERE ProcessorPaymentID IS NULL
	
		SET @ctr = 1
		SET @maxCtr = (SELECT MAX(Sequence) FROM #AllMyProperties)
		
		WHILE (@ctr <= @maxCtr)
		BEGIN
			SET @myPropertyID = (SELECT PropertyID 
									FROM #AllMyProperties
									WHERE Sequence = @ctr)
									
			INSERT @missingAptexxPaymentsByProperty 
				SELECT ReferenceNumber, ExternalID, PayerID, [Date], GAmount, NAmount, null, PaymentType, COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID), PayerPersonID, AptexxPayerID
					FROM #PaymentsForProcessing
					WHERE ProcessorPaymentID IS NULL
					  AND PropertyID = @myPropertyID				
		
			--EXEC AddProcessorPaymentRecords @missingAptexxPayments, @accountID, @integrationPartnerItemID, @propertyID, @date, @description
			EXEC AddProcessorPaymentRecords @missingAptexxPaymentsByProperty, @accountID, @integrationPartnerItemID, @myPropertyID, @date, @description
					
			-- Update the ProcessorPaymentID in this settlement		
			UPDATE #pp SET #pp.ProcessorPaymentID = procPay.ProcessorPaymentID
			FROM #PaymentsForProcessing #pp 
				INNER JOIN ProcessorPayment procPay ON #pp.PayerID = procPay.ObjectID AND #pp.ReferenceNumber = procPay.ProcessorTransactionID	
					
			-- Create a Posting Batch for the payments				
			SET @postingBatchID = NEWID()
			
			INSERT PostingBatch (PostingBatchID, AccountID, IntegrationPartnerID, PostingPersonID, PropertyID, Name, [Date], PostedDate, OriginalTotalAmount,
						TransactionCount, IsPaymentBatch, IsPosted)
				VALUES (@postingBatchID, @accountID, @integrationPartnerID, null, @myPropertyID, @description, @date, null, (SELECT SUM(NetAmount) FROM @missingAptexxPaymentsByProperty),
						(SELECT COUNT(*) FROM @missingAptexxPaymentsByProperty), CAST(1 AS bit), CAST(0 AS bit))						
				--VALUES (@postingBatchID, @accountID, @integrationPartnerID, null, @propertyID, @description, @date, null, (SELECT SUM(NetAmount) FROM @missingAptexxPayments),
				--		(SELECT COUNT(*) FROM @missingAptexxPayments), CAST(1 AS bit), CAST(0 AS bit))
					
			
			-- Add the payments to post				
			INSERT @paymentsToPost 
				SELECT PayerID, null, PaymentType, ReferenceNumber, ReferenceNumber, NAmount, [Date], 
				--(CASE WHEN PaymentType = 'Check' THEN 'Payment' ELSE 'Online Payment'  END), 			
				PaymentType + @paymentDescription, null,
				COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID),
				PayerPersonID
					FROM #PaymentsForProcessing
					WHERE PaymentID IS NULL
					  AND PropertyID = @myPropertyID

			-- IntegrationPartnerItemIDs
			-- 31 = App Fee
			-- 32 = Rent
			-- 33 = Deposit
			
			-- Post the payments on the date they were actuall received
			IF ((SELECT TOP 1 [Date] FROM @paymentsToPost) IS NOT NULL)
			BEGIN			
				SET @date = (SELECT TOP 1 [Date] FROM @paymentsToPost)
			END
			
			-- Posting an application fee or rent payment
			IF (@integrationPartnerItemID = 31 OR @integrationPartnerItemID = 32 OR @integrationPartnerItemID = 29 OR @integrationPartnerItemID = 149)
			BEGIN
				-- Import and post the payments			
				--EXEC ImportPaymentBatch @accountID, @postingBatchID, @onlinePaymentLedgerItemTypeID, @propertyID, null, null, null, @transactionOrigin, @paymentsToPost	
				EXEC ImportPaymentBatch @accountID, @postingBatchID, @onlinePaymentLedgerItemTypeID, @myPropertyID, null, null, @transactionOrigin, @paymentsToPost, null, 0
				
				EXEC PostPaymentBatch @accountID, @postingBatchID, null, @date, 1
			END
			-- Posting a deposit payment
			ELSE IF (@integrationPartnerItemID = 33 OR @integrationPartnerItemID = 150)
			BEGIN
				-- Import and post the deposits			
				--EXEC ImportDepositBatch @accountID, @postingBatchID, @onlineDepositLedgerItemTypeID, @propertyID, null, null, null, @transactionOrigin, @paymentsToPost
				EXEC ImportDepositBatch @accountID, @postingBatchID, @onlineDepositLedgerItemTypeID, @myPropertyID, null, null, @transactionOrigin, @paymentsToPost, null, 0
			
				EXEC PostDepositBatch @accountID, @postingBatchID, null, @date, 1
			END		
					
			UPDATE #p4p SET PaymentID = py.PaymentID
				FROM #PaymentsForProcessing #p4p
					INNER JOIN Payment py ON #p4p.ReferenceNumber = py.ReferenceNumber AND py.PostingBatchID = @postingBatchID						
					
			UPDATE pp SET PaymentID = #p4p.PaymentID
				FROM ProcessorPayment pp				
					INNER JOIN #PaymentsForProcessing #p4p ON pp.ProcessorPaymentID = #p4p.ProcessorPaymentID
			
			
			DELETE @missingAptexxPaymentsByProperty
			DELETE @paymentsToPost
			SET @ctr = @ctr + 1	
		END				
	END				

END
GO
