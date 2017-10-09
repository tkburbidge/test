SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






--/****** Object:  StoredProcedure [dbo].[ProcessAptexxSettlement]    Script Date: 04/20/2015 15:30:48 ******/
--IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProcessAptexxSettlement]') AND type in (N'P', N'PC'))
--DROP PROCEDURE [dbo].[ProcessAptexxSettlement]
--GO
--/****** Object:  StoredProcedure [dbo].[ProcessAptexxTransactions]    Script Date: 04/20/2015 15:30:48 ******/
--IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProcessAptexxTransactions]') AND type in (N'P', N'PC'))
--DROP PROCEDURE [dbo].[ProcessAptexxTransactions]
--GO
--/****** Object:  StoredProcedure [dbo].[AddProcessorPaymentRecords]    Script Date: 04/20/2015 15:30:48 ******/
--IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AddProcessorPaymentRecords]') AND type in (N'P', N'PC'))
--DROP PROCEDURE [dbo].[AddProcessorPaymentRecords]
--GO
--/****** Object:  UserDefinedTableType [dbo].[AptexxPaymentCollection]    Script Date: 04/20/2015 15:30:48 ******/
--IF  EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = N'AptexxPaymentCollection' AND ss.name = N'dbo')
--DROP TYPE [dbo].[AptexxPaymentCollection]
--GO
--/****** Object:  UserDefinedTableType [dbo].[AptexxPaymentCollection]    Script Date: 04/20/2015 15:30:48 ******/
--IF NOT EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = N'AptexxPaymentCollection' AND ss.name = N'dbo')
--CREATE TYPE [dbo].[AptexxPaymentCollection] AS TABLE(
--	[PaymentID] [nvarchar](50) NULL,
--	[ExternalID] [nvarchar](50) NULL,
--	[PayerID] [uniqueidentifier] NULL,
--	[Date] [datetime] NULL,
--	[GrossAmount] [money] NULL,
--	[NetAmount] [money] NULL,
--	[DepositAmount] [money] NULL,
--	[PaymentType] [nvarchar](50) NULL,
--	[LedgerItemTypeID] [uniqueidentifier] NULL,
--	[PayerPersonID] [uniqueidentifier] NULL,
--	[AptexxPayerID] [nvarchar](100) NULL
--)
--GO
--/****** Object:  StoredProcedure [dbo].[AddProcessorPaymentRecords]    Script Date: 04/20/2015 15:30:48 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
--IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AddProcessorPaymentRecords]') AND type in (N'P', N'PC'))
--BEGIN
--EXEC dbo.sp_executesql @statement = N'

---- =============================================
---- Author:		Rick Bertelsen
---- Create date: April 10, 2013
---- Description:	Adds a ProcessorPayment record and determines what type it is.
---- =============================================
--CREATE PROCEDURE [dbo].[AddProcessorPaymentRecords] 
--	-- Add the parameters for the stored procedure here
--	@aptexxPayments AptexxPaymentCollection READONLY, 
--	@accountID bigint = 0,
--	@integrationPartnerItemID int = 0,
--	@propertyID uniqueidentifier = null,
--	@date datetime = null,
--	@description nvarchar(200) = null
--AS

--DECLARE @TTGLAccountID uniqueidentifier

--BEGIN
--	-- SET NOCOUNT ON added to prevent extra result sets from
--	-- interfering with SELECT statements.
--	SET NOCOUNT ON;
	
--	CREATE TABLE #PaymentsAndTransactions (
--		TransactionID uniqueidentifier null,
--		PayerID uniqueidentifier null,
--		PaymentID uniqueidentifier null)

--	INSERT ProcessorPayment (ProcessorPaymentID, AccountID, IntegrationPartnerItemID, ProcessorTransactionID, WalletItemID, PaymentID, PropertyID, ObjectID, ObjectType,
--							 Amount, Fee, DateCreated, PaymentType, Payer, RefundDate, DateProcessed, DateSettled, LedgerItemTypeID)
--		SELECT 	NEWID(), @accountID, @integrationPartnerItemID, aptx.PaymentID, null, null, @propertyID, aptx.PayerID, ''Lease'', aptx.NetAmount, (aptx.GrossAmount-aptx.NetAmount),
--				GETUTCDATE(), aptx.PaymentType, 
--				LEFT(STUFF((SELECT '', '' + (PreferredName + '' '' + LastName)
--						 FROM Person 
--							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
--							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
--							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
--						 WHERE PersonLease.LeaseID = l.LeaseID
--							   AND PersonType.[Type] = ''Resident''				   
--							   AND PersonLease.MainContact = 1				   
--						 FOR XML PATH ('''')), 1, 2, ''''), 50) AS ''Payer'',
--				null, aptx.[Date], null, aptx.LedgerItemTypeID
--			FROM @aptexxPayments aptx
--				INNER JOIN UnitLeaseGroup ulg ON aptx.PayerID = ulg.UnitLeaseGroupID AND ulg.AccountID = @accountID
--				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseID = (SELECT TOP 1 LeaseID 
--																									FROM Lease
--																									WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
--																									ORDER BY LeaseStartDate DESC)
--				INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.IntegrationPartnerItemID = @integrationPartnerItemID
--																	AND ipip.Value1 = aptx.ExternalID
		
--		UNION
		
--		SELECT	NEWID(), @accountID, @integrationPartnerItemID, aptx.PaymentID, null, null, @propertyID, aptx.PayerID, ''Prospect'', aptx.NetAmount, (aptx.GrossAmount-aptx.NetAmount),
--				GETUTCDATE(), aptx.PaymentType, 
--				per.PreferredName + '' '' + per.LastName, 
--				null, aptx.[Date], null, aptx.LedgerItemTypeID
--			FROM @aptexxPayments aptx
--				INNER JOIN Person per ON aptx.PayerID = per.PersonID AND per.AccountID = @accountID
--				INNER JOIN PersonType perType ON perType.PersonID = per.PersonID  AND perType.[Type] = ''Prospect''
--				INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.IntegrationPartnerItemID = @integrationPartnerItemID
--																AND ipip.Value1 = aptx.ExternalID
			
--		UNION
		
--		SELECT	NEWID(), @accountID, @integrationPartnerItemID, aptx.PaymentID, null, null, @propertyID, aptx.PayerID, ''Non-Resident Account'', aptx.NetAmount, (aptx.GrossAmount-aptx.NetAmount),
--				GETUTCDATE(), aptx.PaymentType, 
--				per.PreferredName + '' '' + per.LastName, 
--				null, aptx.[Date], null, aptx.LedgerItemTypeID
--			FROM @aptexxPayments aptx
--				INNER JOIN Person per ON aptx.PayerID = per.PersonID AND per.AccountID = @accountID
--				INNER JOIN PersonType perType ON perType.PersonID = per.PersonID  AND perType.[Type] = ''Non-Resident Account''
--				INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.IntegrationPartnerItemID = @integrationPartnerItemID
--																AND ipip.Value1 = aptx.ExternalID		
				
--END







--' 
--END
--GO
--/****** Object:  StoredProcedure [dbo].[ProcessAptexxTransactions]    Script Date: 04/20/2015 15:30:48 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
--IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProcessAptexxTransactions]') AND type in (N'P', N'PC'))
--BEGIN
--EXEC dbo.sp_executesql @statement = N'-- =============================================
---- Author:		Rick Bertelsen
---- Create date: Sept. 3, 2013
---- Description:	Adds a ProcessorPayment record and determines what type it is.
----				Then it creates a payment batch and imports that batch.
---- =============================================
--CREATE PROCEDURE [dbo].[ProcessAptexxTransactions]
--	-- Add the parameters for the stored procedure here
--	@aptexxPayments AptexxPaymentCollection READONLY, 
--	@accountID bigint = 0,
--	@integrationPartnerItemID int = 0,
--	@propertyID uniqueidentifier = null,
--	@date datetime = null,
--	@description nvarchar(200) = null
--AS

--DECLARE @onlinePaymentLedgerItemTypeID uniqueidentifier
--DECLARE @onlineDepositLedgerItemTypeID uniqueidentifier
--DECLARE @defaultLedgerItemTypeID uniqueidentifier
--DECLARE @integrationPartnerID int
--DECLARE @paymentsToPost PostingBatchPaymentCollection
--DECLARE @postingBatchID uniqueidentifier
--DECLARE @settlementAmount money
--DECLARE @missingAptexxPayments AptexxPaymentCollection 
--DECLARE @paymentDescription nvarchar(100)
--DECLARE @transactionOrigin nchar(1)
--DECLARE @ctr int
--DECLARE @maxCtr int
--DECLARE @myPropertyID uniqueidentifier
--DECLARE @missingAptexxPaymentsByProperty AptexxPaymentCollection


--BEGIN

--	SELECT @integrationPartnerID = IntegrationPartnerID FROM IntegrationPartnerItem WHERE IntegrationPartnerItemID = @integrationPartnerItemID
--	SELECT @onlinePaymentLedgerItemTypeID = DefaultPortalPaymentLedgerItemTypeID, @onlineDepositLedgerItemTypeID = DefaultPortalDepositLedgerItemTypeID FROM Settings WHERE AccountID = @accountID	

--	-- Processing an Aptexx Application Fee or Rent payment
--	IF (@integrationPartnerItemID = 31 OR @integrationPartnerItemID = 32)
--	BEGIN
--		SET @defaultLedgerItemTypeID = @onlinePaymentLedgerItemTypeID
--		SET @paymentDescription = '' Payment''
--		SET @transactionOrigin = ''X''
--	END
--	-- Processing an Aptexx Deposit payment
--	ELSE IF (@integrationPartnerItemID = 33)
--	BEGIN
--		SET @defaultLedgerItemTypeID = @onlineDepositLedgerItemTypeID	
--		SET @paymentDescription = '' Deposit''
--		SET @transactionOrigin = ''X''
--	END
--	ELSE IF (@integrationPartnerItemID = 29 OR @integrationPartnerItemID = 149)
--	BEGIN
--		SET @defaultLedgerItemTypeID = @onlinePaymentLedgerItemTypeID
--		SET @paymentDescription = '' Payment''
--		SET @transactionOrigin = ''S''
--	END
--	ELSE IF (@integrationPartnerItemID = 150)
--	BEGIN
--		SET @defaultLedgerItemTypeID = @onlineDepositLedgerItemTypeID	
--		SET @paymentDescription = '' Deposit''
--		SET @transactionOrigin = ''S''
--	END
	

--	CREATE TABLE #PaymentsForProcessing (
--		ReferenceNumber nvarchar(50) null,		
--		ExternalID nvarchar(50) null,			-- Used in AddProcessPaymentRecords but not needed - can be removed. For anyone but Aptexx, pass in NULL
--		PayerID uniqueidentifier null,			-- ObjectID in Transaction.ObjectID
--		[Date] datetime null,
--		GAmount money null,
--		NAmount money null,
--		PaymentType nvarchar(50),
--		LedgerItemTypeID uniqueidentifier null,
--		ProcessorPaymentID uniqueidentifier null,
--		PaymentID uniqueidentifier null,
--		PayerPersonID uniqueidentifier null,
--		AptexxPayerID nvarchar(100) null,
--		Part1 uniqueidentifier null,
--		Part2 uniqueidentifier null,
--		PropertyID uniqueidentifier null
--		)--,
--		--NewAdd bit null)
		
--	CREATE TABLE #AllMyProperties (
--		Sequence int identity,
--		PropertyID uniqueidentifier not null)
		
--	-- Add all the Payments joining in the Payment table to get a PaymentID
--	INSERT #PaymentsForProcessing 
--		SELECT atPP.PaymentID, atPP.ExternalID, atPP.PayerID, atPP.[Date], atPP.GrossAmount, atPP.NetAmount, atPP.PaymentType, 
--				atPP.LedgerItemTypeID, pp.ProcessorPaymentID, py.PaymentID, atPP.PayerPersonID, atPP.AptexxPayerID, null, null, null
--			FROM @aptexxPayments atPP
--				LEFT JOIN ProcessorPayment pp ON pp.ProcessorTransactionID = atPP.PaymentID
--				LEFT JOIN Payment py ON pp.PaymentID = py.PaymentID
				
--	UPDATE #PaymentsForProcessing SET Part1 = CAST(SUBSTRING(AptexxPayerID, 1, 36) AS uniqueidentifier), 
--									  Part2 = CAST(Substring(AptexxPayerID, 38, 36) AS uniqueidentifier)
									  
--	UPDATE #p4p SET PropertyID = ut.PropertyID
--		FROM #PaymentsForProcessing #p4p
--			INNER JOIN UnitLeaseGroup ulg ON #p4p.Part1 = ulg.UnitLeaseGroupID
--			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
--			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			
--	UPDATE #PaymentsForProcessing SET PropertyID = Part1	
--		WHERE PropertyID IS NULL								
				
---- We need to do this later now!
--	-- Create the collection of new payments that need to be posted			
--	--INSERT @missingAptexxPayments 
--	--	SELECT ReferenceNumber, ExternalID, PayerID, [Date], GAmount, NAmount, null, PaymentType, COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID), PayerPersonID, AptexxPayerID
--	--		FROM #PaymentsForProcessing
--	--		WHERE ProcessorPaymentID IS NULL			
	
--	-- If needed, add the ProcessorPayment records
--	--IF ((SELECT COUNT(*) FROM @missingAptexxPayments) > 0)
--	IF ((SELECT COUNT(*) FROM #PaymentsForProcessing WHERE ProcessorPaymentID IS NULL) > 0)
--	BEGIN			
--		INSERT #AllMyProperties
--			SELECT DISTINCT PropertyID 
--				FROM #PaymentsForProcessing
--				WHERE ProcessorPaymentID IS NULL
	
--		SET @ctr = 1
--		SET @maxCtr = (SELECT MAX(Sequence) FROM #AllMyProperties)
		
--		WHILE (@ctr <= @maxCtr)
--		BEGIN
--			SET @myPropertyID = (SELECT PropertyID 
--									FROM #AllMyProperties
--									WHERE Sequence = @ctr)
									
--			INSERT @missingAptexxPaymentsByProperty 
--				SELECT ReferenceNumber, ExternalID, PayerID, [Date], GAmount, NAmount, null, PaymentType, COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID), PayerPersonID, AptexxPayerID
--					FROM #PaymentsForProcessing
--					WHERE ProcessorPaymentID IS NULL
--					  AND PropertyID = @myPropertyID				
		
--			--EXEC AddProcessorPaymentRecords @missingAptexxPayments, @accountID, @integrationPartnerItemID, @propertyID, @date, @description
--			EXEC AddProcessorPaymentRecords @missingAptexxPaymentsByProperty, @accountID, @integrationPartnerItemID, @myPropertyID, @date, @description
					
--			-- Update the ProcessorPaymentID in this settlement		
--			UPDATE #pp SET #pp.ProcessorPaymentID = procPay.ProcessorPaymentID
--			FROM #PaymentsForProcessing #pp 
--				INNER JOIN ProcessorPayment procPay ON #pp.PayerID = procPay.ObjectID AND #pp.ReferenceNumber = procPay.ProcessorTransactionID	
					
--			-- Create a Posting Batch for the payments				
--			SET @postingBatchID = NEWID()
			
--			INSERT PostingBatch (PostingBatchID, AccountID, IntegrationPartnerID, PostingPersonID, PropertyID, Name, [Date], PostedDate, OriginalTotalAmount,
--						TransactionCount, IsPaymentBatch, IsPosted)
--				VALUES (@postingBatchID, @accountID, @integrationPartnerID, null, @myPropertyID, @description, @date, null, (SELECT SUM(NetAmount) FROM @missingAptexxPaymentsByProperty),
--						(SELECT COUNT(*) FROM @missingAptexxPaymentsByProperty), CAST(1 AS bit), CAST(0 AS bit))						
--				--VALUES (@postingBatchID, @accountID, @integrationPartnerID, null, @propertyID, @description, @date, null, (SELECT SUM(NetAmount) FROM @missingAptexxPayments),
--				--		(SELECT COUNT(*) FROM @missingAptexxPayments), CAST(1 AS bit), CAST(0 AS bit))
					
			
--			-- Add the payments to post				
--			INSERT @paymentsToPost 
--				SELECT PayerID, null, PaymentType, ReferenceNumber, NAmount, [Date], 
--				--(CASE WHEN PaymentType = ''Check'' THEN ''Payment'' ELSE ''Online Payment''  END), 			
--				PaymentType + @paymentDescription,
--				COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID),
--				PayerPersonID
--					FROM #PaymentsForProcessing
--					WHERE PaymentID IS NULL
--					  AND PropertyID = @myPropertyID

--			-- IntegrationPartnerItemIDs
--			-- 31 = App Fee
--			-- 32 = Rent
--			-- 33 = Deposit
			
--			-- Post the payments on the date they were actuall received
--			IF ((SELECT TOP 1 [Date] FROM @paymentsToPost) IS NOT NULL)
--			BEGIN			
--				SET @date = (SELECT TOP 1 [Date] FROM @paymentsToPost)
--			END
			
--			-- Posting an application fee or rent payment
--			IF (@integrationPartnerItemID = 31 OR @integrationPartnerItemID = 32)
--			BEGIN
--				-- Import and post the payments			
--				--EXEC ImportPaymentBatch @accountID, @postingBatchID, @onlinePaymentLedgerItemTypeID, @propertyID, null, null, null, @transactionOrigin, @paymentsToPost	
--				EXEC ImportPaymentBatch @accountID, @postingBatchID, @onlinePaymentLedgerItemTypeID, @myPropertyID, null, null, null, @transactionOrigin, @paymentsToPost				
				
--				EXEC PostPaymentBatch @accountID, @postingBatchID, null, @date		
--			END
--			-- Posting a deposit payment
--			ELSE IF (@integrationPartnerItemID = 33)
--			BEGIN
--				-- Import and post the deposits			
--				--EXEC ImportDepositBatch @accountID, @postingBatchID, @onlineDepositLedgerItemTypeID, @propertyID, null, null, null, @transactionOrigin, @paymentsToPost
--				EXEC ImportDepositBatch @accountID, @postingBatchID, @onlineDepositLedgerItemTypeID, @myPropertyID, null, null, null, @transactionOrigin, @paymentsToPost
			
--				EXEC PostDepositBatch @accountID, @postingBatchID, null, @date		
--			END		
					
--			UPDATE #p4p SET PaymentID = py.PaymentID
--				FROM #PaymentsForProcessing #p4p
--					INNER JOIN Payment py ON #p4p.ReferenceNumber = py.ReferenceNumber AND py.PostingBatchID = @postingBatchID						
					
--			UPDATE pp SET PaymentID = #p4p.PaymentID
--				FROM ProcessorPayment pp				
--					INNER JOIN #PaymentsForProcessing #p4p ON pp.ProcessorPaymentID = #p4p.ProcessorPaymentID
			
			
--			DELETE @missingAptexxPaymentsByProperty
--			DELETE @paymentsToPost
--			SET @ctr = @ctr + 1	
--		END				
--	END				

--END








--' 
--END
--GO
--/****** Object:  StoredProcedure [dbo].[ProcessAptexxSettlement]    Script Date: 04/20/2015 15:30:48 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
--IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProcessAptexxSettlement]') AND type in (N'P', N'PC'))
--BEGIN
--EXEC dbo.sp_executesql @statement = N'-- =============================================
---- Author:		Rick Bertelsen
---- Create date: March 28, 2013
---- Description:	Deals with Aptexx payment settlement
---- =============================================
--CREATE PROCEDURE [dbo].[ProcessAptexxSettlement] 
--	-- Add the parameters for the stored procedure here
--	@aptexxPayment AptexxPaymentCollection READONLY, 
--	@bankAccountID uniqueidentifier = null,
--	@propertyID uniqueidentifier = null,
--	@integrationPartnerItemID int = null,
--	@accountID bigint = null,
--	@settlementAmount money = null,
--	@date date = null,
--	@description nvarchar(500) = null
--AS

--DECLARE @paymentsToPost PostingBatchPaymentCollection
--DECLARE @newAptexxPayments AptexxPaymentCollection 
--DECLARE @postingBatchID uniqueidentifier
--DECLARE @newTransactionID uniqueidentifier
--DECLARE @newBatchID uniqueidentifier
--DECLARE @bankDepositTransactionTypeID uniqueidentifier
--DECLARE @bankDepositGLAccountID uniqueidentifier
--DECLARE @bankTransactionCategoryID uniqueidentifier
--DECLARE @onlinePaymentLedgerItemTypeID uniqueidentifier
--DECLARE @onlineDepositLedgerItemTypeID uniqueidentifier
--DECLARE @defaultLedgerItemTypeID uniqueidentifier
--DECLARE @batchNumber int
--DECLARE @integrationPartnerID int
--DECLARE @ctr int
--DECLARE @maxCtr int
--DECLARE @myPropertyID uniqueidentifier
--DECLARE @transSum money 

--BEGIN
--	-- SET NOCOUNT ON added to prevent extra result sets from
--	-- interfering with SELECT statements.
--	SET NOCOUNT ON;
	
--	IF (@date IS NULL)
--	BEGIN
--		SET @date = GETDATE()
--	END
	
--	SELECT @integrationPartnerID = IntegrationPartnerID FROM IntegrationPartnerItem WHERE IntegrationPartnerItemID = @integrationPartnerItemID	
--	SELECT @onlinePaymentLedgerItemTypeID = DefaultPortalPaymentLedgerItemTypeID, @onlineDepositLedgerItemTypeID = DefaultPortalDepositLedgerItemTypeID FROM Settings WHERE AccountID = @accountID	
	
--	IF (@integrationPartnerItemID = 31 OR @integrationPartnerItemID = 32)
--	BEGIN
--		SET @defaultLedgerItemTypeID = @onlinePaymentLedgerItemTypeID
--	END
--	ELSE IF (@integrationPartnerItemID = 33)
--	BEGIN
--		SET @defaultLedgerItemTypeID = @onlineDepositLedgerItemTypeID	
--	END
	
--	CREATE TABLE #SettlementPaymentsForProcessing (
--		ReferenceNumber nvarchar(50) null,
--		ExternalID nvarchar(50) null,
--		PayerID uniqueidentifier null,
--		[Date] datetime null,
--		GAmount money null,
--		NAmount money null,
--		PaymentType nvarchar(50),
--		LedgerItemTypeID uniqueidentifier null,
--		ProcessorPaymentID uniqueidentifier null,
--		PaymentID uniqueidentifier null,
--		PayerPersonID uniqueidentifier null,--)--,
--		AptexxPayerID nvarchar(100) null,
--		Part1 uniqueidentifier null,
--		Part2 uniqueidentifier null,
--		PropertyID uniqueidentifier null
--		)--,
--		--NewAdd bit null)

--	CREATE TABLE #AllMyProperties (
--		Sequence int identity,
--		PropertyID uniqueidentifier not null)
		
--	CREATE TABLE #NewTransactions (
--		TransactionID uniqueidentifier not null)
		
--	-- Add all the Payments that are in the batch for processing	
--	INSERT #SettlementPaymentsForProcessing 
--		SELECT atPP.PaymentID, atPP.ExternalID, atPP.PayerID, atPP.[Date], atPP.GrossAmount, atPP.NetAmount, atPP.PaymentType, 
--				atPP.LedgerItemTypeID, pp.ProcessorPaymentID, py.PaymentID, atPP.PayerPersonID, atPP.AptexxPayerID, null, null, null
--			FROM @aptexxPayment atPP
--				LEFT JOIN ProcessorPayment pp ON pp.ProcessorTransactionID = atPP.PaymentID --AND pp.IntegrationPartnerItemID = @integrationPartnerItemID
--				LEFT JOIN Payment py ON pp.PaymentID = py.PaymentID	
				
				
--	UPDATE #SettlementPaymentsForProcessing SET Part1 = CAST(SUBSTRING(AptexxPayerID, 1, 36) AS uniqueidentifier), 
--												Part2 = CAST(Substring(AptexxPayerID, 38, 36) AS uniqueidentifier)
									  
--	UPDATE #sp4p SET PropertyID = ut.PropertyID
--		FROM #SettlementPaymentsForProcessing #sp4p
--			INNER JOIN UnitLeaseGroup ulg ON #sp4p.Part1 = ulg.UnitLeaseGroupID
--			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
--			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
			
--	UPDATE #SettlementPaymentsForProcessing SET PropertyID = Part1	
--		WHERE PropertyID IS NULL	
					
--	INSERT #AllMyProperties
--		SELECT DISTINCT PropertyID
--			FROM #SettlementPaymentsForProcessing					
	
--	-- Create the collection of new payments that need to be posted			
--	--INSERT @newAptexxPayments 
--	--	SELECT ReferenceNumber, ExternalID, PayerID, [Date], GAmount, NAmount, null, PaymentType, COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID), PayerPersonID
--	--		FROM #SettlementPaymentsForProcessing
--	--		WHERE PaymentID IS NULL		
	
--	SELECT @bankDepositGLAccountID = GLAccountID, @bankDepositTransactionTypeID = TransactionTypeID 
--		FROM TransactionType 
--		WHERE AccountID = @accountID
--		  AND Name = ''Deposit''
--		  AND [Group] = ''Bank''
				
--	SET @ctr = 1
--	SET @maxCtr = (SELECT MAX(Sequence) FROM #AllMyProperties)
	
--	WHILE (@ctr <= @maxCtr)
--	BEGIN
		
--		SET @myPropertyID = (SELECT PropertyID FROM #AllMyProperties WHERE Sequence = @ctr)
--		-- If needed, add the ProcessorPayment records
--		--IF ((SELECT COUNT(*) FROM @newAptexxPayments) > 0)
--		IF ((SELECT COUNT(*) FROM #SettlementPaymentsForProcessing WHERE PaymentID IS NULL AND PropertyID = @myPropertyID) > 0)
--		BEGIN			

--			INSERT @newAptexxPayments 
--				SELECT ReferenceNumber, ExternalID, PayerID, [Date], GAmount, NAmount, null, PaymentType, COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID), PayerPersonID, AptexxPayerID
--					FROM #SettlementPaymentsForProcessing
--					WHERE PaymentID IS NULL	
--					  AND PropertyID = @myPropertyID		
			
--			--EXEC ProcessAptexxTransactions @newAptexxPayments, @accountID, @integrationPartnerItemID, @propertyID, @date, @description	
			
--			EXEC ProcessAptexxTransactions @newAptexxPayments, @accountID, @integrationPartnerItemID, @myPropertyID, @date, @description			
			
--			-- Update the ProcessorPaymentID in this settlement		
--			UPDATE #pp SET #pp.ProcessorPaymentID = procPay.ProcessorPaymentID
--			FROM #SettlementPaymentsForProcessing #pp 
--				INNER JOIN ProcessorPayment procPay ON #pp.PayerID = procPay.ObjectID AND #pp.ReferenceNumber = procPay.ProcessorTransactionID AND procPay.AccountID = @accountID
						
--			---- Update the PaymentID on the temp table and the ProcessorPayment table
--			UPDATE #p4p SET #p4p.PaymentID = py.PaymentID
--			FROM #SettlementPaymentsForProcessing #p4p
--				INNER JOIN Payment py ON #p4p.ReferenceNumber = py.ReferenceNumber AND py.AccountID = @accountID
				
--			DELETE @newAptexxPayments					
--		END	
		
--		--UPDATE Payment SET Notes = ''Yup'' WHERE ReferenceNumber IN (SELECT ProcessorPaymentID FROM #SettlementPaymentsForProcessing)
								
--		SET @transSum = (SELECT SUM(pay.Amount)
--							FROM #SettlementPaymentsForProcessing #sp4p
--								INNER JOIN Payment pay ON #sp4p.PaymentID = pay.PaymentID
--							WHERE #sp4p.PropertyID = @myPropertyID)
		
--		IF (@transSum > 0)
--		BEGIN
--			SET @newTransactionID = NEWID()
--			INSERT [Transaction] (AccountID, Amount, TransactionTypeID, TransactionDate, ObjectID, Origin, PropertyID, [Description], TransactionID, [TimeStamp], IsDeleted, NotVisible)
--				VALUES (@accountID, /*@settlementAmount,*/ @transSum, @bankDepositTransactionTypeID, @date, @bankAccountID, ''X'', /*@propertyID,*/ @myPropertyID, @description, @newTransactionID, GETDATE(), 0, 0)
--			-- Credit Undeposited Funds		
--			INSERT [JournalEntry] (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
--				VALUES (NEWID(), @accountID, @bankDepositGLAccountID, @newTransactionID, -1*@transSum /*@settlementAmount*/, ''Cash'')
--			-- Debit bank GL Account
--			INSERT [JournalEntry] (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
--				SELECT NEWID(), @accountID, GLAccountID, @newTransactionID, @transSum /*@settlementAmount*/, ''Cash''
--					FROM BankAccount 
--					WHERE BankAccountID = @bankAccountID
--			-- Credit Undeposited Funds			
--			INSERT [JournalEntry] (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
--				VALUES (NEWID(), @accountID, @bankDepositGLAccountID, @newTransactionID, -1*@transSum /*@settlementAmount*/, ''Accrual'')
--			-- Debit bank GL Account
--			INSERT [JournalEntry] (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
--				SELECT NEWID(), @accountID, GLAccountID, @newTransactionID, @transSum /*@settlementAmount*/, ''Accrual''
--					FROM BankAccount 
--					WHERE BankAccountID = @bankAccountID
--			INSERT #NewTransactions SELECT @newTransactionID	
--		END
		
--		SET @ctr = @ctr + 1		
--	END			
			
--	IF ((SELECT COUNT(*) FROM #NewTransactions) > 0)
--	BEGIN	
--		-- Deal with no batches and batches moved outside of current period			
--		SET @batchNumber = (SELECT dbo.GetNextBankDepositBatch(@accountID, @bankAccountID, @date))

--		DECLARE @newBankTransactionID uniqueidentifier = NEWID()	  
		
--		SET @newBatchID = NEWID()
--		INSERT Batch (BatchID, AccountID, PropertyAccountingPeriodID, BankTransactionID, Number, [Description], [Date], IsOpen, [Type], IntegrationPartnerID)
--			VALUES (@newBatchID, @accountID, ''00000000-0000-0000-0000-000000000000'', @newBankTransactionID, @batchNumber, @description, @date, 0, ''Bank'', 1013)

--		SELECT @bankTransactionCategoryID = BankTransactionCategoryID 
--			FROM BankTransactionCategory
--			WHERE AccountID = @accountID
--			  AND Category = ''System Deposit''
--			  AND Visible = 0	
						 
--		INSERT BankTransaction (BankTransactionID, AccountID, BankTransactionCategoryID, ObjectID, ObjectType, ReferenceNumber, QueuedForPrinting )
--			VALUES (@newBankTransactionID, @accountID, @bankTransactionCategoryID, ''00000000-0000-0000-0000-000000000000'', ''BankTransactionTransaction'', CAST(@batchNumber AS nvarchar(50)), 0)
--		--INSERT BankTransactionTransaction (BankTransactionTransactionID, AccountID, BankTransactionID, TransactionID)
--		--	VALUES (NEWID(), @accountID, @newBankTransactionID, @newTransactionID)
		
--		INSERT BankTransactionTransaction
--			SELECT NEWID(), @accountID, @newBankTransactionID, TransactionID
--				FROM #NewTransactions
			
--		UPDATE Payment SET BatchID = @newBatchID
--			WHERE PaymentID IN (SELECT DISTINCT PaymentID FROM #SettlementPaymentsForProcessing)
			
--		UPDATE ProcessorPayment SET DateSettled = @date
--			WHERE ProcessorPaymentID IN (SELECT ProcessorPaymentID FROM #SettlementPaymentsForProcessing)		
			
--	-- When we do this update, we break the link ProcessorPayment.ObjectID = Transaction.ObjectID.  If we need to get any values of relevance, we need to
--	-- go through Payment (ProcessPayment.PaymentID, then to Payment, PaymentTransaction, Transaction.
--		UPDATE t SET ObjectID = l.UnitLeaseGroupID, TransactionTypeID = ttNew.TransactionTypeID
--			FROM [Transaction] t
--				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
--				INNER JOIN #SettlementPaymentsForProcessing #pp ON t.ObjectID = #pp.PayerID
--				INNER JOIN ProcessorPayment pp ON #pp.ReferenceNumber = pp.ProcessorTransactionID
--				INNER JOIN PersonLease pl ON pl.PersonID = #pp.PayerID
--				INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
--				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
--				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
--				INNER JOIN Building b ON b.BuildingID = u.BuildingID
--				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID AND ut.PropertyID = @propertyID
--				INNER JOIN TransactionType ttNew ON tt.Name = ttNew.Name AND ttNew.[Group] = ''Lease'' AND ttNew.AccountID = @accountID
--			WHERE pl.PersonLeaseID IS NOT NULL
--			  AND t.ObjectID <> l.UnitLeaseGroupID 
--			  AND pp.ObjectType IN (''Prospect'')
--			  AND t.PropertyID = @propertyID
--			  -- Make sure that a prospect transferred to a new property and converted into a lease isn''t
--			  -- assigned a payment from the old property
--			  AND t.PropertyID = b.PropertyID
			  
--		-- Don''t need to check property here as we don''t update it above if it isn''t tied to the same property
--		UPDATE pay SET ObjectID = t.ObjectID, ObjectType = ''Lease''
--			FROM Payment pay
--				INNER JOIN #SettlementPaymentsForProcessing #pp ON pay.ObjectID = #pp.PayerID AND pay.ReferenceNumber = #pp.ReferenceNumber
--				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
--				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID AND t.ObjectID <> pay.ObjectID AND pay.ObjectType NOT IN (''Lease'')
--				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] = ''Lease''		
				
			
--	END
		
--END


--' 
--END
--GO







-- =============================================
-- Author:		Joshua Grigg
-- Create date: April 20, 2015
-- Description:	Gets names of settings associated with an employee
-- =============================================
CREATE PROCEDURE [dbo].[GetDefaultSettingAssociationsByEmployeeID]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,  
	@personID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--be sure table names here are defined in Resman.Common.Constants.DisplayableTableColumnNameSettings.cs
	DECLARE @Property varchar(50) = 'Property'
	DECLARE @AutoMakeReady varchar(50) = 'AutoMakeReady'
	DECLARE @WorkOrderCategoryAssignment varchar(50) = 'WorkOrderCategoryAssignment'
	--DECLARE @WorkOrder varchar(50) = 'WorkOrder'
	
	--Return table name, column name, and property id for setting matches
	CREATE TABLE #DefaultSettingAssociation(
		[Table] nvarchar(50) not null,
		[Column] nvarchar(50) not null,
		PropertyID uniqueidentifier not null
	)
	
	--
	-- Check if employee id is associated with settings
	-- be sure column names here are defined in Resman.Common.Constants.DisplayableTableColumnNameSettings.cs
	--
	
	
	-- Property Table
	
	-- Checking if assigned leasing agent
	INSERT #DefaultSettingAssociation
		SELECT DISTINCT
			@Property,
			'AssignedLeasingAgentPersonID',
			PropertyID
		FROM Property
		WHERE AssignedLeasingAgentPersonID = @personID
		AND AccountID = @accountID
	
	-- Checking if property manager
	INSERT #DefaultSettingAssociation
		SELECT DISTINCT
			@Property,
			'ManagerPersonID',
			PropertyID
		FROM Property
		WHERE ManagerPersonID = @personID
		AND AccountID = @accountID
	
	-- Checking if assigned portal work orders 
	INSERT #DefaultSettingAssociation
		SELECT DISTINCT
			@Property,
			'PortalWorkOrderAssignedToPersonID',
			PropertyID
		FROM Property
		WHERE PortalWorkOrderAssignedToPersonID = @personID
		AND AccountID = @accountID
	
	-- Checking if regional manager
	INSERT #DefaultSettingAssociation
		SELECT DISTINCT
			@Property,
			'RegionalManagerPersonID',
			PropertyID
		FROM Property
		WHERE RegionalManagerPersonID = @personID
		AND AccountID = @accountID
	
	-- Checking if supervisor
	INSERT #DefaultSettingAssociation
		SELECT DISTINCT
			@Property,
			'SupervisorPersonID',
			PropertyID
		FROM Property
		WHERE SupervisorPersonID = @personID
		AND AccountID = @accountID
	
	-- Auto Make Ready Table
	
	-- Checking if has auto make ready assignements	
	INSERT #DefaultSettingAssociation
		SELECT DISTINCT
			@AutoMakeReady,
			'AssignedToPersonID',
			PropertyID
		FROM AutoMakeReady
		WHERE AssignedToPersonID = @personID
		AND AccountID = @accountID

	--Work Order Category Assignment Table
	INSERT #DefaultSettingAssociation
		SELECT DISTINCT
			@WorkOrderCategoryAssignment,
			'WorkOrderCategoryAssignmentID',
			PropertyID
		FROM WorkOrderCategoryAssignment
		WHERE PersonID = @personID
		AND AccountID = @accountID

	/*
	-- Work Order Table
	
	-- Checking if assigned incomplete work order
	INSERT #DefaultSettingAssociation
		SELECT DISTINCT
			@WorkOrder,
			'AssignedPersonID',
			PropertyID
		FROM WorkOrder
		WHERE AssignedPersonID = @personID
		AND AccountID = @accountID
		AND CompletedDate IS NULL
	*/
		
	ALTER TABLE #DefaultSettingAssociation ADD PropertyName varchar(50)
	UPDATE #DefaultSettingAssociation
		SET PropertyName = (SELECT p.Name
								FROM Property p
							WHERE #DefaultSettingAssociation.PropertyID = p.PropertyID)				
	SELECT * FROM #DefaultSettingAssociation

END
GO
