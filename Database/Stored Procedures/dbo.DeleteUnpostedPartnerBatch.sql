SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Art Olsen
-- Create date: 9/5/2013
-- Description:	Delete unposted partner batch and associated transactions or payments
-- =============================================
CREATE PROCEDURE [dbo].[DeleteUnpostedPartnerBatch]
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@postingBatchID uniqueidentifier
AS
BEGIN
	DECLARE @isPosted bit
	DECLARE @isPayemntBatch bit
	
	SELECT @isPosted = pb.IsPosted, @isPayemntBatch = pb.IsPaymentbatch
	FROM PostingBatch pb
	WHERE pb.AccountID = @accountID and pb.PostingBatchID = @postingBatchID
	IF (@isPosted = 1)
	BEGIN
		SELECT -1
		return
	End
	ELSE
		BEGIN

		CREATE TABLE #TransactionIDsToDelete ( TransactionID uniqueidentifier )

		IF (@isPayemntBatch = 1)
			BEGIN
				
				INSERT INTO #TransactionIDsToDelete
					SELECT pt.TransactionID FROM PaymentTransaction pt WHERE pt.AccountID = @accountID and pt.PaymentID in
						 (SELECT p.PaymentID FROM Payment p WHERE p.AccountID = @accountID and p.PostingBatchID = @postingBatchID )

				DELETE FROM PaymentTransaction WHERE PaymentTransaction.TransactionID in 
					(SELECT TransactionID FROM #TransactionIDsToDelete)

				DELETE FROM [Transaction] WHERE [Transaction].TransactionID in 
					(SELECT TransactionID FROM #TransactionIDsToDelete)				
				
				DELETE FROM Payment WHERE Payment.AccountID = @accountID and Payment.PostingBatchID = @postingBatchID		
			End
		ELSE
			BEGIN
				
				INSERT INTO #TransactionIDsToDelete 
					SELECT TransactionID FROM [Transaction] 
					WHERE [Transaction].AccountID = @accountID and [Transaction].PostingBatchID = @postingBatchID

				DELETE FROM [Transaction] 
				WHERE [Transaction].TransactionID IN (SELECT TransactionID FROM #TransactionIDsToDelete)
			End
		DELETE FROM PostingBatch 
		WHERE PostingBatch.AccountID = @accountID and PostingBatch.PostingBatchID = @postingBatchID
	END
END
GO
