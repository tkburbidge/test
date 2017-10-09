SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 26, 2013
-- Description:	Updates the EmailRecipeints table with an email status and figures out the correct status for the EmailJob table.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateEmailRecipient] 
	-- Add the parameters for the stored procedure here
	--@emailRecipientIDs GuidCollection  READONLY, 
	--@emailStatus nvarchar(50) = null,
	--@emailMessage nvarchar(MAX) = null
	@emailJobID uniqueidentifier = null,
	@emailTextDeliveryStatuses EmailRecipientDeliveryStatusCollection READONLY,
	@fromAPI bit = 0
AS
DECLARE @allJobsASuccess bit = 0
DECLARE @jobsStillInProgress bit = 0
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

			
	CREATE TABLE #AllTheStatuseses (
		[EmailRecipientID] [uniqueidentifier] NULL,
		[EmailStatus] [nvarchar](200) NULL,
		[EmailErrorMessage] [nvarchar](MAX) NULL,
		[TextStatus] [nvarchar](200) NULL,
		[TextErrorMessage] [nvarchar](MAX) NULL)
		
	INSERT #AllTheStatuseses
		SELECT * FROM @emailTextDeliveryStatuses
	
	-- update email statuses		
	UPDATE er SET EmailStatus = #stati.EmailStatus, EmailErrorMessage = #stati.EmailErrorMessage
		FROM EmailRecipient er
			INNER JOIN #AllTheStatuseses #stati ON er.EmailRecipientID = #stati.EmailRecipientID
		WHERE @fromAPI = 0  -- only update email statuses if NOT from API	
			
	-- update text statuses		
	UPDATE er SET TextStatus = #stati.TextStatus, TextErrorMessage = #stati.TextErrorMessage
		FROM EmailRecipient er
			INNER JOIN #AllTheStatuseses #stati ON er.EmailRecipientID = #stati.EmailRecipientID
		WHERE
		  -- make sure if API updated it first, we don't overwrite it with 'Queued' or whatever
		  er.TextStatus NOT IN ('Sent', 'Delivered', 'Failed', 'Undelivered')
		  OR @fromAPI = 1 -- if from API always update it
	
	
	-- update error count		
	UPDATE er SET ErrorCount = ISNULL(ErrorCount, 0) + 1
		FROM EmailRecipient er 
			INNER JOIN #AllTheStatuseses #stati ON er.EmailRecipientID = #stati.EmailRecipientID 
							AND ((#stati.EmailStatus NOT IN ('NotStarted', 'InProgress', 'Completed', 'Preview', ''))
							      OR
							     (#stati.TextStatus IN ('Undelivered', 'Failed', 'Retry')))
	
	---- come back and check this					     
	--UPDATE er SET TextStatus = 'Failed'
	--	FROM EmailRecipient er
	--	WHERE er.EmailRecipientID IN (SELECT EmailRecipientID FROM #AllTheStatuseses)
	--	  AND er.SendText = 1
	--	  AND er.ErrorCount > 3

	SET @jobsStillInProgress = CASE
								WHEN (SELECT COUNT(*)
										FROM EmailRecipient er
										WHERE er.EmailJobID = @emailJobID
										  AND (er.EmailStatus IN ('NotStarted', 'InProgress')
											OR er.TextStatus IN ('NotStarted', 'InProgress'))) > 0 THEN 1
								ELSE 0
								END

	SET @allJobsASuccess = CASE
							WHEN (SELECT COUNT(*)
									FROM EmailRecipient er
									WHERE er.EmailJobID = @emailJobID
									  AND er.EmailStatus NOT IN ('Completed', '')
									  AND er.TextStatus NOT IN ('Queued', 'Sending', 'Sent', 'Delivered', '')) = 0 THEN 1
							ELSE 0
							END
								  
	IF (@jobsStillInProgress = 0)
	BEGIN
		IF (@allJobsASuccess = 1)
			BEGIN
				-- set job to Completed 
				UPDATE ej SET [Status] = 'Completed'
					FROM EmailJob ej  
					WHERE ej.EmailJobID = @emailJobID
			END
		ELSE
			BEGIN
				-- set job to Error 
				UPDATE ej SET [Status] = 'Error'
					FROM EmailJob ej  
					WHERE ej.EmailJobID = @emailJobID
			END
	END
	
	
END





GO
