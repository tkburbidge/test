SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Tony Morgan
-- Create date: 11/24/2014
-- Description:	Deletes a LedgerLineItemGroup as well as all Line Item Type Associations
-- =============================================
CREATE PROCEDURE [dbo].[DeleteLedgerLineItemGroup] 
	-- Add the parameters for the stored procedure here
	@accountID BIGINT,
	@groupID UNIQUEIDENTIFIER
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DELETE liglit
    FROM LedgerLineItemGroupLedgerItemType liglit 
    WHERE liglit.LedgerLineItemGroupID = @groupID 
		AND liglit.AccountID = @accountID
    
    DELETE lig 
    FROM LedgerLineItemGroup lig
    WHERE lig.AccountID = @accountID 
		AND lig.LedgerLineItemGroupID = @groupID
END
GO
