SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO









-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 13, 2012
-- Description:	Posts a PostingBatch
-- =============================================
CREATE PROCEDURE [dbo].[PostCreditBatch] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@postingBatchID uniqueidentifier = null,
	@postingPersonID uniqueidentifier = null,
	@date date = null
AS

DECLARE @objectIDs GuidCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE PostingBatch SET IsPosted = 1, PostingPersonID = @postingPersonID, PostedDate = @date
		WHERE PostingBatchID = @postingBatchID 
		  AND AccountID = @accountID
		  
	UPDATE [Transaction] SET PersonID = @postingPersonID, TransactionDate = @date
		WHERE PostingBatchID = @postingBatchID
			AND AccountID = @accountID
		
	UPDATE Payment SET [Date] = @date
		WHERE PostingBatchID = @postingBatchID
			AND AccountID = @accountID
	
	INSERT @objectIDs SELECT DISTINCT t.ObjectID
		FROM Payment py
			INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
		WHERE py.PostingBatchID = @postingBatchID
			AND py.AccountID = @accountID
		
	EXEC ApplyAvailableBalance @objectIDs, @postingPersonID, @date, @postingBatchID
	
END


GO
