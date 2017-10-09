SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 25, 2013
-- Description:	Gets a list of the attachments to associate for each email recipient
-- =============================================
CREATE PROCEDURE [dbo].[GetEmailAttachmentsByEmailRecipient] 
	-- Add the parameters for the stored procedure here
	@emailRecipients GuidCollection READONLY
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	er.EmailRecipientID AS 'EmailRecipientID',
			doc.DocumentID AS 'DocumentID',
			doc.Name AS 'Name',
			doc.Uri AS 'Uri',
			doc.FileType AS 'FileType',
			doc.ContentType as 'ContentType'
		FROM EmailAttachment ea
			INNER JOIN EmailRecipient er ON ea.ObjectID = er.EmailRecipientID AND ea.ObjectType = 'EmailRecipient'
			INNER JOIN Document doc ON ea.DocumentID = doc.DocumentID
		WHERE er.EmailRecipientID IN (SELECT Value FROM @emailRecipients)
		
	UNION
	
	SELECT	er.EmailRecipientID AS 'EmailRecipientID',
			doc.DocumentID AS 'DocumentID',
			doc.Name AS 'Name',
			doc.Uri AS 'Uri',
			doc.FileType AS 'FileType',
			doc.ContentType as 'ContentType'
		FROM EmailAttachment ea
			INNER JOIN EmailJob ej ON ea.ObjectID = ej.EmailJobID AND ea.ObjectType = 'EmailJob'
			INNER JOIN EmailRecipient er ON ej.EmailJobID = er.EmailJobID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipients)
			INNER JOIN Document doc ON ea.DocumentID = doc.DocumentID
		
	UNION
	
	SELECT	er.EmailRecipientID AS 'EmailRecipientID',
			doc.DocumentID AS 'DocumentID',
			doc.Name AS 'Name',
			doc.Uri AS 'Uri',
			doc.FileType AS 'FileType',
			doc.ContentType as 'ContentType'
		FROM EmailAttachment ea
			INNER JOIN EmailTemplate et ON et.EmailTemplateID = ea.ObjectID AND ea.ObjectType = 'EmailTemplate'
			INNER JOIN EmailJob ej ON et.EmailTemplateID = ej.EmailTemplateID
			INNER JOIN EmailRecipient er ON ej.EmailJobID = er.EmailJobID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipients)
			INNER JOIN Document doc ON ea.DocumentID = doc.DocumentID
		 		
		
	
END
GO
