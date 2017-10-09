SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 24, 2012
-- Description:	Updates the Budget.Notes column
-- =============================================
CREATE PROCEDURE [dbo].[UpdateBudgetNotes] 
	-- Add the parameters for the stored procedure here
	@budgetID uniqueidentifier = null, 
	@notes nvarchar(500) = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE Budget SET Notes = @notes WHERE BudgetID = @budgetID
	
END
GO
