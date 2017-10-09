SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 5, 2013
-- Description:	Adds an entry in the ActivityLog.  Should only be called from the ScheduledTaskRepository
-- =============================================
CREATE PROCEDURE [dbo].[AddActivityLogEntry] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@activityLogType nvarchar(50) = null,
	@modifiedByPersonID uniqueidentifier = null,
	@objectName nvarchar(50) = null,
	@objectID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@activity nvarchar(500) = null,
	@exceptionName nvarchar(200) = null,
	@exceptionCaught bit = null,
	@exception nvarchar(max) = null,
	@altObjectID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	INSERT ActivityLog (ActivityLogID, AccountID, ActivityLogType, ModifiedByPersonID, ObjectName, ObjectID, PropertyID, Activity, [Timestamp],
						ExceptionName, ExceptionCaught, Exception, AltObjectID)
		VALUES (NEWID(), @accountID, @activityLogType, @modifiedByPersonID, @objectName, @objectID, @propertyID, @activity, GETDATE(),
						@exceptionName, @exceptionCaught, @exception, @altObjectID)
	
END
GO
