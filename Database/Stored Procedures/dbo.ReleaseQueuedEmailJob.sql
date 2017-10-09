SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: 1/10/2014
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[ReleaseQueuedEmailJob] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@emailJobID uniqueIdentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    UPDATE EmailRecipient SET [EmailStatus] = 'NotStarted', [TextStatus] = 'NotStarted'
    WHERE AccountID = @accountID and EmailJobID = @emailJobID
    
    UPDATE EmailJob SET [Status] = 'NotStarted'
    WHERE AccountID = @accountID and EmailJobID = @emailJobID
END
GO
