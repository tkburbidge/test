SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO








-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 22, 2013
-- Description:	Get a list of recipients for a given email job.
-- =============================================
CREATE PROCEDURE [dbo].[GetEmailRecipients] 
	-- Add the parameters for the stored procedure here
	@numberToReturn int = 0, 
	@emailJobID uniqueidentifier = null
AS
DECLARE @newGuid		uniqueidentifier
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SET @newGuid = NEWID()
	UPDATE EmailRecipient SET UpdateGuid = @newGuid, DateProcessed = SYSUTCDATETIME ()
		WHERE EmailRecipientID IN 
			(SELECT TOP (@numberToReturn) EmailRecipientID
				FROM EmailRecipient
				WHERE EmailJobID = @emailJobID
				  AND ((EmailStatus IN ('NotStarted')
								OR ((EmailStatus IN ('InProgress', 'UnableToProcessRecipient', 'SMTPRetry', 'UnableToSendEmail')) 
								AND (SYSUTCDATETIME() > DATEADD(minute, 60, DateProcessed))))
				   OR (TextStatus IN ('NotStarted')
								OR ((TextStatus IN ('Retry'))
								AND (SYSUTCDATETIME() > DATEADD(minute, 60, DateProcessed)))))
				  AND ErrorCount < 3
				ORDER BY DateCreated DESC
			)
	
	-- update email status
	UPDATE EmailRecipient SET EmailStatus = 'InProgress'
		WHERE UpdateGuid = @newGuid
		  -- 2014-12-1: Removed because we change the DateProcessed in the above query and it was
		  --				not getting updated before 
		  AND EmailStatus IN ('NotStarted', 'InProgress', 'UnableToProcessRecipient', 'SMTPRetry', 'UnableToSendEmail')
				--	OR ((EmailStatus IN ('InProgress', 'UnableToProcessRecipient', 'SMTPRetry', 'UnableToSendEmail')) 
				--	AND (SYSUTCDATETIME() > DATEADD(minute, 60, DateProcessed))))
		  --AND ErrorCount < 3
		  
	-- update text status
	UPDATE EmailRecipient SET TextStatus = 'InProgress'
		WHERE UpdateGuid = @newGuid
		  -- 2014-12-1: Removed because we change the DateProcessed in the above query and it was
		  --				not getting updated before 
		  AND TextStatus IN ('NotStarted', 'Retry')
				--	OR ((TextStatus IN ('Retry'))
				--	AND (SYSUTCDATETIME() > DATEADD(minute, 60, DateProcessed))))
		  --AND ErrorCount < 3
			
	-- update job status
	UPDATE EmailJob SET [Status] = 'InProgress'
	WHERE EmailJobID = @emailJobID
		
	SELECT DISTINCT
			er.EmailRecipientID AS 'EmailRecipientID',
			per.PersonID AS 'PersonID',
			er.ObjectID AS 'ObjectID',
			per.Email AS 'EmailAddress',
			per.PreferredName AS 'PreferredName',
			per.LastName AS 'LastName',
			'' AS 'Location',
			er.[Subject] as PreviewedSubject,
			er.Body as PreviewedBody,
			er.SMSBody as 'PreviewedSMSBody',
			pSMStpp.ReceivesTextsFromPhoneNumber as 'SMSPhoneNumber',
			CASE
				WHEN (per.Phone1Type = 'Mobile') THEN per.Phone1
				WHEN (per.Phone2Type = 'Mobile') THEN per.Phone2
				WHEN (per.Phone3Type = 'Mobile') THEN per.Phone3
				END AS 'PersonMobilePhoneNumber',
			per.PreferredContactMethod AS 'PreferredContactMethod',
			CASE 
				WHEN (er.EmailStatus IN ('InProgress')) THEN er.SendEmail  -- always will be InProgress becasue set to InProgress above
				ELSE CAST(0 AS bit)
				END AS 'SendEmail',
			CASE
				WHEN (er.TextStatus IN ('InProgress')) THEN er.SendText -- always will be InProgress becasue set to InProgress above
				ELSE CAST(0 AS bit)
				END AS 'SendText'
		FROM EmailRecipient er 
			INNER JOIN Person per ON er.PersonID = per.PersonID	
			LEFT JOIN EmailJob ej ON ej.EmailJobID = @emailJobID
			LEFT JOIN EmailTemplate et ON ej.EmailTemplateID = et.EmailTemplateID
			LEFT JOIN PersonSMSTextPhoneProperty pSMStpp ON per.PersonID = pSMStpp.PersonID AND ej.PropertyID = pSMStpp.PropertyID			
		where er.UpdateGuid = @newGuid
END
GO
