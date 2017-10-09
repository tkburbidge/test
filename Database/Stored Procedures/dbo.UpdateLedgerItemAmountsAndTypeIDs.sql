SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [dbo].[UpdateLedgerItemAmountsAndTypeIDs]
	@accountID bigint = null,
	@ledgerItemPoolID uniqueidentifier = null,
	@amount money = null,
	@ledgerItemTypeID uniqueidentifier = null
AS
BEGIN
	SET NOCOUNT ON;

	UPDATE
		[LedgerItem]
	SET
		Amount = @amount,
		LedgerItemTypeID = @ledgerItemTypeID
	WHERE
		LedgerItemPoolID = @ledgerItemPoolID AND AccountID = @accountID
END
GO
