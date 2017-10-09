SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Art Olsen
-- Create date: 1/14/2014
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[DeleteEmailRecipients] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@emailRecipientIDs GuidCollection readonly
AS
BEGIN
	DELETE FROM EmailRecipient
	WHERE EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
END

GO
