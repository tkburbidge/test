SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 9/16/2013
-- Description:	Updates the order of a list of documents
-- =============================================
CREATE PROCEDURE [dbo].[UpdateDocumentsOrder] 
-- Add the parameters for the stored procedure here
@accountID bigint,
@documentIDs OrderedGuidCollection READONLY
AS
BEGIN
-- SET NOCOUNT ON added to prevent extra result sets from
-- interfering with SELECT statements.
SET NOCOUNT ON;

-- Insert statements for procedure here
UPDATE doc SET OrderBy = #docs.OrderBy
    FROM Document doc 
        INNER JOIN @documentIDs #docs ON doc.DocumentID = #docs.Value
    WHERE doc.AccountID = @accountID 
    
END
GO
