SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 7/2/2012
-- Description:	Updates the amounts on the LedgerItems associated
--				with a LedgerItemPool
-- =============================================
CREATE PROCEDURE [dbo].[UpdateLedgerItemsAmounts]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@ledgerItemPoolID uniqueidentifier = null,
	@amount money = null
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	UPDATE [LedgerItem] SET Amount = @amount WHERE LedgerItemPoolID = @ledgerItemPoolID AND AccountID = @accountID
	
END
GO
