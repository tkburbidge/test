SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

 
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 20, 2012
-- Description:	Imports a payment batch
-- =============================================
CREATE PROCEDURE [dbo].[ImportDepositBatch] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@postingBatchID uniqueidentifier = null,
	@defaultLedgerItemTypeID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@personID uniqueidentifier = null,	
	@taxRateGroupID uniqueidentifier = null,
	@origin char(1) = 'X',
	@payments PostingBatchPaymentCollection READONLY,
	@integrationPartnerID int = null,
	@addProcessorPayments bit = 0
AS

DECLARE @maxSequenceNumber			int
DECLARE @ctr						int
DECLARE @objectID					uniqueidentifier
DECLARE @objectName					nvarchar(500)
DECLARE @objectType					nvarchar(25)
DECLARE @amount						money
DECLARE @type						nvarchar(100)
DECLARE @referenceNumber			nvarchar(100)
DECLARE @partnerTransactionID		nvarchar(100)
DECLARE @date						date
DECLARE @description				nvarchar(1000)
DECLARE @notes						nvarchar(1000)
--DECLARE @LITGLAccountID				uniqueidentifier
--DECLARE @TTGLAccountID				uniqueidentifier
DECLARE @transactionTypeID			uniqueidentifier
DECLARE @undepositedFundsID			uniqueidentifier
DECLARE	@prepaidIncomeID			uniqueidentifier
DECLARE @newPaymentID				uniqueidentifier
DECLARE @newTransID					uniqueidentifier
DECLARE @newPrepaymentTransID		uniqueidentifier
DECLARE @ledgerItemTypeID			uniqueidentifier
DECLARE @payerPersonID				uniqueidentifier
DECLARE @dbPropertyID				uniqueidentifier
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #NewPayments (
		SequenceNum				int identity,
		ObjectID				uniqueidentifier not null,
		ReceivedFrom			nvarchar(100) null,
		[Type]					nvarchar(100) null,
		ReferenceNumber			nvarchar(100) null,
		[PartnerTransactionID]  nvarchar(100) NULL,
		Amount					money not null,
		[Date]					date null,
		[Description]			nvarchar(1000) null,
		[Notes]					nvarchar(1000) NULL,
		LedgerItemTypeID		uniqueidentifier null,
		PayerPersonID			uniqueidentifier null,
		PaymentID				uniqueidentifier null)
		

	INSERT #NewPayments 
		SELECT p.*, null FROM @payments p
			LEFT JOIN ProcessorPayment pp ON p.PartnerTransactionID = pp.ProcessorTransactionID AND pp.AccountID = @accountID AND pp.ObjectID = p.ObjectID			
		WHERE ((@addProcessorPayments = 0) OR (pp.ProcessorPaymentID IS NULL))	

	SET @maxSequenceNumber = (SELECT MAX(SequenceNum) FROM #NewPayments)
	SET @ctr = 1
	
	WHILE (@ctr <= @maxSequenceNumber)
	BEGIN				
		SET @transactionTypeID = NULL
		SET @objectName = NULL
				
		-- Pull out the data needed for the deposit
		SELECT @objectID = ObjectID, @objectName = ReceivedFrom, @type = [Type], @referenceNumber = COALESCE(ReferenceNumber, PartnerTransactionID),
				@amount = Amount, @date = [Date], @description = [Description], @ledgerItemTypeID = LedgerItemTypeID,
				@payerPersonID = PayerPersonID, @notes = Notes, @partnerTransactionID = PartnerTransactionID
			FROM #NewPayments
			WHERE SequenceNum = @ctr

		-- If a deposit has already been posted to this objectID
		-- just grab the TransactionTypeID from that deposit			
		SELECT @transactionTypeID = t.TransactionTypeID, @objectType = tt.[Group]
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
		WHERE t.ObjectID = @objectID
		  AND tt.Name = 'Deposit'
		  AND t.AccountID = @accountID
			
		-- If we didn't get a TransactionTypeID then try to get it another way			  
		IF (@transactionTypeID IS NULL)
		BEGIN
			IF ((SELECT COUNT(*) FROM UnitLeaseGroup WHERE UnitLeaseGroupID = @objectID) > 0)
			BEGIN
				SELECT @transactionTypeID = TransactionTypeID, @objectType = [Group]
					FROM TransactionType
					WHERE AccountID = @accountID
					  AND Name = 'Deposit'
					  AND [Group] = 'Lease'					 					  
			END
			ELSE IF ((SELECT COUNT(*) FROM PersonType WHERE PersonID = @objectID AND [Type] = 'Prospect') > 0)
			BEGIN
				SELECT @transactionTypeID = TransactionTypeID, @objectType = [Group]
					FROM TransactionType
					WHERE AccountID = @accountID
					  AND Name = 'Deposit'
					  AND [Group] = 'Prospect'
			END
			ELSE IF ((SELECT COUNT(*) FROM PersonType WHERE PersonID = @objectID AND [Type] = 'Non-Resident Account') > 0)
			BEGIN
				SELECT @transactionTypeID = TransactionTypeID, @objectType = [Group]
					FROM TransactionType
					WHERE AccountID = @accountID
					  AND Name = 'Deposit'
					  AND [Group] = 'Non-Resident Account'
			END
			ELSE IF ((SELECT COUNT(*) FROM WOITAccount WHERE WOITAccountID = @objectID) > 0)
			BEGIN
				SELECT @transactionTypeID = TransactionTypeID, @objectType = [Group]
					FROM TransactionType
					WHERE AccountID = @accountID
					  AND Name = 'Deposit'
					  AND [Group] = 'WOIT Account'
			END
		END		
		
		-- Get the object name if one isn't specified
		IF (@objectName IS NULL)
		BEGIN
			IF (@objectType = 'Lease')
			BEGIN
				SET @objectName = (SELECT TOP 1 u.Number + ' - '
								   FROM UnitLeaseGroup ulg 
										INNER JOIN Unit u on u.UnitID = ulg.UnitID
								   WHERE ulg.UnitLeaseGroupID = @objectID)
								   
				SET @objectName = @objectName + STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
														 FROM UnitLeaseGroup ulg 										
															INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseID = (SELECT TOP 1 LeaseID 
																																				FROM Lease
																																				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																																				ORDER BY LeaseStartDate DESC)										 
															 INNER JOIN PersonLease ON PersonLease.LeaseID = l.LeaseID
															 INNER JOIN Person ON Person.PersonID = PersonLease.PersonID
															 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
														 WHERE ulg.UnitLeaseGroupID = @objectID
															   AND PersonType.[Type] = 'Resident'
															   AND PersonLease.MainContact = 1
														 FOR XML PATH ('')), 1, 2, '')
				SET @objectName = LEFT(@objectName, 50)
			END
			ELSE IF (@objectType = 'Prospect')
			BEGIN
				SET @objectName = (SELECT TOP 1 per.PreferredName + ' ' + per.LastName
								   FROM Prospect p
									INNER JOIN Person per on per.PersonID = p.PersonID
								   WHERE p.AccountID = @accountID
									AND p.PersonID = @objectID)
			END
			ELSE IF (@objectType = 'WOIT Account')
			BEGIN
				SET @objectName = (SELECT TOP 1 woit.Name
								   FROM WOITAccount woit
								   WHERE woit.AccountID = @accountID
									AND woit.WOITAccountID = @objectID)
			END
			ELSE IF (@objectType = 'Non-Resident Account')
			BEGIN
				SET @objectName = (SELECT TOP 1 per.PreferredName + ' ' + per.LastName
								   FROM PersonType pt
									INNER JOIN Person per on per.PersonID = pt.PersonID
								   WHERE pt.AccountID = @accountID
									AND pt.PersonID = @objectID
									AND pt.[Type] = 'Non-Resident Account')
			END

		END	

		
		-- Check to make sure the propertyID passed in matches the propertyID of the account being posted to
		IF (@objectType = 'Lease')
		BEGIN
				SELECT 
					@dbPropertyID = b.PropertyID
				FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				WHERE ulg.UnitLeaseGroupID = @objectID
		END
		ELSE IF (@objectType = 'Prospect')
		BEGIN
				SELECT 
					@dbPropertyID = pps.PropertyID
				FROM Prospect pro
				INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pro.PropertyProspectSourceID
				WHERE pro.PersonID = @objectID
					AND pps.PropertyID = @propertyID
		END
		ELSE IF (@objectType = 'WOIT Account')
		BEGIN
				SELECT 
					@dbPropertyID = woit.PropertyID
				FROM WOITAccount woit
				WHERE woit.WOITAccountID = @objectID
		END
		ELSE IF (@objectType = 'Non-Resident Account')
		BEGIN
				SELECT 
					@dbPropertyID = ptp.PropertyID
				FROM Person p
				INNER JOIN PersonType pt ON pt.PersonID = p.PersonID
				INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID 
				WHERE p.PersonID = @objectID					
		END
		
	
		IF (@transactionTypeID IS NOT NULL AND @dbPropertyID = @propertyID)
		BEGIN
			SET @newPaymentID = NEWID()
			SET @newTransID = NEWID()
		
			IF (@ledgerItemTypeID IS NULL)
			BEGIN
				SET @ledgerItemTypeID = @defaultLedgerItemTypeID
			END

			INSERT [Payment] (PaymentID, AccountID, [Type], ReferenceNumber, [Date], ReceivedFromPaidTo, ObjectID, ObjectType,
								Amount, [Description], [Notes], PaidOut, Reversed, PostingBatchID, [TimeStamp], PayerPersonID)
				VALUES (@newPaymentID, @accountID, @type, @referenceNumber, @date, @objectName, @objectID, @objectType,
								@amount, @description, @notes, CAST(0 AS BIT), CAST(0 AS BIT), @postingBatchID, GETDATE(), @payerPersonID)
			INSERT [Transaction] (TransactionID, AccountID, ObjectID, TransactionTypeID, LedgerItemTypeID, 
									PropertyID, PersonID, TaxRateGroupID, NotVisible, Origin, Amount,
									[Description], Note, TransactionDate, PostingBatchID, [TimeStamp], IsDeleted)
					VALUES		(@newTransID, @accountID, @objectID, @transactionTypeID, @ledgerItemTypeID,
									@propertyID, @personID, @taxRateGroupID, 0, @origin, @amount,
									@description, @notes, @date, @postingBatchID, GETDATE(), 0) 

			IF (@addProcessorPayments = 1)
			BEGIN
				INSERT ProcessorPayment (ProcessorPaymentID, AccountID, IntegrationPartnerItemID, ProcessorTransactionID, WalletItemID, PaymentID, PropertyID, ObjectID, ObjectType,
							 Amount, Fee, DateCreated, PaymentType, Payer, RefundDate, DateProcessed, DateSettled, LedgerItemTypeID, IntegrationPartnerID)
					VALUES (NEWID(), @accountID, 0, @partnerTransactionID, null, @newPaymentID, @propertyID, @objectID, @objectType,
							@amount, 0, GETDATE(), @type, @objectName, null, @date, null,  COALESCE(@ledgerItemTypeID, @defaultLedgerItemTypeID), @integrationPartnerID)
			END


			IF (@@ROWCOUNT < 0)
			BEGIN
				INSERT ActivityLog (ActivityLogID, AccountID, ActivityLogType, ModifiedByPersonID, ObjectName, ObjectID, PropertyID,
										Activity, [Timestamp], ExceptionName, ExceptionCaught, Exception, AltObjectID)
					VALUES			(NEWID(), @accountID, 'ImportDepositBatch', @personID, @objectName, @objectID, @propertyID,
										'PostingBatch', GETDATE(), 'ERROR INSERTING TRANSACTION', 0, @objectName, @postingBatchID)			
			END
			ELSE
			BEGIN
				INSERT PaymentTransaction (PaymentID, TransactionID, AccountID) VALUES (@newPaymentID, @newTransID, @accountID)
			END

			UPDATE #NewPayments SET PaymentID = @newPaymentID WHERE SequenceNum = @ctr
		END			
		ELSE
		BEGIN
			INSERT ActivityLog	(ActivityLogID, AccountID, ActivityLogType, ModifiedByPersonID, ObjectName, ObjectID, PropertyID,
									Activity, [Timestamp], ExceptionName, ExceptionCaught, 
									Exception, AltObjectID)
				VALUES			(NEWID(), @accountID, 'ImportDepositBatch', @personID, @objectName, @objectID, @propertyID,
									'PostingBatch', GETDATE(), 'Object not found', 0,
									'Paid by ' + @objectName + ', Reference: ' + @referenceNumber + ', Amount $' + CAST(@amount as nvarchar) + ', Description: ' + @description + ', Note: ' + @notes, @postingBatchID)
		END

		SET @ctr = @ctr + 1			
	END
	
	SELECT * FROM #NewPayments
END
GO
