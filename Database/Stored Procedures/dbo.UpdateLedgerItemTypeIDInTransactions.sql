SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 23, 2012
-- Description:	Updates the LedgerItemTypeIDs in a collection of Transactions
-- =============================================
CREATE PROCEDURE [dbo].[UpdateLedgerItemTypeIDInTransactions] 
	-- Add the parameters for the stored procedure here
	@oldLedgerItemName nvarchar(500) = null, 
	@postingBatchID uniqueidentifier = null,
	@ledgerItemTypeID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE [Transaction] SET LedgerItemTypeID = @ledgerItemTypeID, Note = RIGHT(Note, (LEN(Note) - LEN(@oldLedgerItemName)))
		WHERE PostingBatchID = @postingBatchID
		  AND Note like @oldLedgerItemName + '%'

END
GO
