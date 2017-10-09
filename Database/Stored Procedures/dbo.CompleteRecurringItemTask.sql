SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: 6/27/2013
-- Description:	mark recurring task as completed
-- =============================================
create PROCEDURE [dbo].[CompleteRecurringItemTask] 
	-- Add the parameters for the stored procedure here
	@accountID BIGINT = 0, 
	@objectId UNIQUEIDENTIFIER,
	@dateUpdated DATE
AS
BEGIN
	UPDATE AlertTask 
	SET DateCompleted = @dateUpdated, Taskstatus = 'Completed'
	WHERE AccountID = @AccountID AND ObjectID = @objectId AND TaskStatus <> 'Completed'
END
GO
