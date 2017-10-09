SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE PROCEDURE [dbo].[GetEmailJobs] 
	-- Add the parameters for the stored procedure here
	@numberToReturn int = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- Needs to do a round-robin on federated databases

	SELECT DISTINCT TOP (@numberToReturn)
		NEWID() AS 'RandomID',
		Jobs.*
		FROM
		(SELECT DISTINCT	
			ej.EmailJobID AS 'EmailJobID',
			ej.AccountID AS 'AccountID',
			ej.PropertyID AS 'PropertyID',
			COALESCE(ej.[Subject], et.[Subject]) AS 'Subject',
			COALESCE(ej.Body, et.Body) AS 'Body',
			COALESCE(et.[Type], '') as 'EmailTemplateType',
			p.Email AS 'EmailFromAddress',
			p.SmtpServerName AS 'EmailHostName',
			p.SmtpPortNumber AS 'EmailSmtpPortNumber',
			p.SmtpUserName AS 'EmailUserName',
			p.SmtpPassword AS 'EmailPassword',
			p.SmtpRequiresSSL AS 'EmailSMTPRequiresSSL',
			p.EmailProviderType AS 'EmailProviderType',
			p.Name AS 'EmailFromName',
			ej.CreatedByPersonID AS 'CreatedByPersonID',
			ej.DateTimeCreatedUTC AS 'DateSubmitted',
			se.CompanyEmailAddress as 'CompanyEmailAddress',
			se.CompanyName as 'CompanyName',
			ej.PersonType AS PersonType,
			se.Subdomain AS Subdomain,
			COALESCE(ej.SMSBody, et.SMSBody) AS 'SMSTextBody',
			ipip.Value1 AS 'TwilioAccountSID',
			ipip.Value2 AS 'TwilioAuthID',
			ej.SendingMethod AS 'SendingMethod'
		FROM EmailJob ej
			INNER JOIN Property p ON ej.PropertyID = p.PropertyID
			INNER JOIN EmailRecipient er ON ej.EmailJobID = er.EmailJobID 
							AND (((er.EmailStatus NOT IN ('Preview', 'Completed', 'SMTPErrorConfiguration', 'SMTPGeneralFailure', '') AND er.ErrorCount < 3))
									OR
								((er.TextStatus IN ('Retry', 'NotStarted') AND er.ErrorCount < 3)))
			LEFT JOIN EmailTemplate et ON ej.EmailTemplateID = et.EmailTemplateID
			left join Settings se on se.AccountID = p.AccountID

-- The next line tells us if this property has integrated with Twilio, SMSText aggregator.  The 123 is defined in the constants class, must be changed here too if ....			
			LEFT JOIN IntegrationPartnerItemProperty ipip ON ej.PropertyID = ipip.PropertyID AND ipip.IntegrationPartnerItemID = 123
		WHERE DATEADD(hour, 1, ISNULL(ej.LastSent, '2001-01-01')) <= GETUTCDATE()
			AND er.ErrorCount < 5
			AND ((ej.SendingMethod = 'Email') 
			   OR (et.NotificationID = 17)
			   OR (((ej.SendingMethod = 'Text') OR (ej.SendingMethod = 'Email&Text')) 
						AND ((DATEPART(hour, dbo.GetTimeZoneTime(p.PropertyID)) >= 8) AND (DATEPART(hour, dbo.GetTimeZoneTime(p.PropertyID)) <= 21 /* 9 PM */))))) Jobs
		ORDER BY 'RandomID'
    
END
GO
