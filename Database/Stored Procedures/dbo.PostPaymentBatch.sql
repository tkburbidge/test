SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 13, 2012
-- Description:	Posts a PostingBatch
-- =============================================
CREATE PROCEDURE [dbo].[PostPaymentBatch] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@postingBatchID uniqueidentifier = null,
	@postingPersonID uniqueidentifier = null,
	@date date = null,
	@updatePaymentDate bit = 1
AS

DECLARE @objectIDs GuidCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE PostingBatch SET IsPosted = 1, PostingPersonID = @postingPersonID, PostedDate = @date
		WHERE PostingBatchID = @postingBatchID 
		  AND AccountID = @accountID
	
	-- Store the dates for which we should call ApplyAvailableBalance
	CREATE TABLE #PaymentDates 
	(
		ID int IDENTITY,
		[Date] date	
	)
		  
	IF (@updatePaymentDate = 1)
	BEGIN
		UPDATE [Transaction] SET PersonID = @postingPersonID, TransactionDate = @date
			WHERE PostingBatchID = @postingBatchID
				AND AccountID = @accountID
		
		UPDATE Payment SET [Date] = @date
			WHERE PostingBatchID = @postingBatchID
				AND AccountID = @accountID
	END	

	SELECT PaymentID FROM Payment WHERE AccountID = @accountID AND PostingBatchID = @postingBatchID

	-- Get a list of all the dates for each payment and use those dates individually
	INSERT INTO #PaymentDates
		SELECT DISTINCT [Date] 
		FROM Payment 
		WHERE AccountID = @accountID 
			AND PostingBatchID = @postingBatchID
		ORDER BY [Date] DESC

	DECLARE @processingDate DATE
	DECLARE @ctr int = 1
	DECLARE @maxCtr int = 0	
	SET @maxCtr = ISNULL((SELECT MAX(ID) FROM #PaymentDates), 0)	

	-- Loop through and call ApplyAvailableBalance for every date in the batch
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @processingDate = [Date] FROM #PaymentDates WHERE ID = @ctr

		INSERT @objectIDs SELECT DISTINCT t.ObjectID
			FROM Payment py
				INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			WHERE py.PostingBatchID = @postingBatchID
				AND py.AccountID = @accountID
				AND py.[Date] = @processingDate

		EXEC ApplyAvailableBalance @objectIDs, @postingPersonID, @processingDate, @postingBatchID

		DELETE FROM @objectIDs

		SET @ctr = @ctr + 1
	END
	
END
GO
