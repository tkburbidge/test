SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 05/12/2014
-- Description:	Deletes zombie documents
-- =============================================
CREATE PROCEDURE [dbo].[DeleteUnattachedDocuments] 
	-- Add the parameters for the stored procedure here
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DELETE 
		FROM Document
		WHERE [Type] = 'PreAttachment'
		  AND DATEDIFF(DAY, DateAttached, @date) > 7
END
GO
