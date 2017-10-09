SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 12/21/2012
-- Description:	Deletes a form letter and its form letter fields
-- =============================================
CREATE PROCEDURE [dbo].[DeleteFormLetter] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@formLetterID uniqueidentifier
AS 
DECLARE @docID uniqueidentifier
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DELETE FROM FormLetterField WHERE FormLetterField.AccountID = @accountID AND FormLetterField.FormLetterID = @formLetterID
	SELECT @docID = DocumentID
		FROM FormLetter WHERE FormLetterID = @formLetterID
	DELETE FROM FormLetter WHERE FormLetter.AccountID = @accountID AND FormLetter.FormLetterID = @formLetterID
	SELECT @docID
END
GO
