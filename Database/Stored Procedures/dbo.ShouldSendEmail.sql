SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[ShouldSendEmail] 
	-- Add the parameters for the stored procedure here
	@accountID BIGINT, 
	@propertyID UNIQUEIDENTIFIER,
	@personID UNIQUEIDENTIFIER,
	@notificationID INT
AS

BEGIN	
	DECLARE @count INT	
	DECLARE @textCount INT
	
	Create Table #ReturnCodeTable(
		PersonID uniqueidentifier null,
		SendText bit null,
		SendEmail bit null)
		
	INSERT INTO #ReturnCodeTable VALUES (@personID, 1, 1)
	
	DECLARE @notificationType nvarchar(100) = (SELECT [Type] FROM [Notification] WHERE NotificationID = @notificationID)

	IF (@notificationType = 'Employee')
	BEGIN
		-- has the person unsubscribed from this email type?
		-- if they have an entry in NotificationPerson and Subscribed is false for that NotificationID, they are unsubscribed.
		-- if its true they are subscribed, If no entry then they are not subscribed
		SET @count = (SELECT count(*) 
						FROM NotificationPersonGroup np 
						WHERE np.AccountID = @accountID 
							  AND np.ObjectID = @personID 
							  AND np.NotificationID = @notificationID 
							  AND np.IsEmailSubscribed = 1) -- check for a specific unsubscribe

		IF (@count = 0)
		BEGIN
			UPDATE #ReturnCodeTable SET SendEmail = 0
		END

		-- has the person unsubscribed from this text type?
		-- if they have an entry in NotificationPerson and Subscribed is false for that NotificationID, they are unsubscribed.
		-- if its true they are subscribed, If no entry then they are not subscribed
		SET @count = (SELECT count(*) 
						FROM NotificationPersonGroup np 
						WHERE np.AccountID = @accountID 
								AND np.ObjectID = @personID 
								AND np.NotificationID = @notificationID 
								AND np.IsSMSSubscribed = 1) -- check for a specific unsubscribe
	
		
		IF (@count = 0) -- if we dont find that, we dont send
		BEGIN			
			UPDATE #ReturnCodeTable SET SendText = 0
		END
	END
	ELSE IF (@notificationType = 'Resident' OR @notificationType = 'Applicant')
	BEGIN
		-- does the property send this kind of notification? 
		SET @count = (SELECT count(*) 
						FROM NotificationProperty np 
						WHERE np.AccountID = @accountID 
							AND np.NotificationID = @notificationID 
							AND np.PropertyID = @propertyID)


		IF (@count = 0)
		BEGIN
			UPDATE #ReturnCodeTable SET SendEmail = 0, SendText = 0
			SELECT * FROM #ReturnCodeTable
			RETURN
		END							
	
		-- has the person unsubscribed from this email type?
		-- if they have an entry in NotificationPersonGroup and Subscribed is false for that NotificationID, they are unsubscribed.
		-- if its true or there is no entry, they are subscribed
		SET @count = (SELECT count(*) 
						FROM NotificationPersonGroup np 
						WHERE np.AccountID = @accountID 
							  AND np.ObjectID = @personID 
							  AND np.NotificationID = @notificationID 
							  AND np.IsEmailSubscribed = 0)

		IF (@count > 0)
		BEGIN
			UPDATE #ReturnCodeTable SET SendEmail = 0
		END		
		
		-- has the person unsubscribed from this email type?
		-- if they have an entry in NotificationPersonGroup and Subscribed is false for that NotificationID, they are unsubscribed.
		-- if its true or there is no entry, they are subscribed
		SET @count = (SELECT count(*) 
						FROM NotificationPersonGroup np 
						WHERE np.AccountID = @accountID 
							  AND np.ObjectID = @personID 
							  AND np.NotificationID = @notificationID 
							  AND np.IsSMSSubscribed = 0)


		IF (@count > 0)
		BEGIN
			UPDATE #ReturnCodeTable SET SendText = 0
		END
					
	END
	
	-- does the person have an email address?
	SET @count = (SELECT COUNT(*) 
					FROM Person p 
					WHERE p.AccountID = @accountID and p.PersonID = @personID and p.Email <> '' and p.Email is not null)



	IF (@count = 0)
	BEGIN
		UPDATE #ReturnCodeTable SET SendEmail = 0
	END

	-- does the person have an mobile phone ?
	SET @count = (SELECT COUNT(*) 
					FROM Person per
					WHERE per.AccountID = @accountID and per.PersonID = @personID 
						and ((per.Phone1Type = 'Mobile' AND per.Phone1 <> '' AND per.Phone1 IS NOT NULL) 
							OR (per.Phone2Type = 'Mobile' AND per.Phone2 <> '' AND per.Phone2 IS NOT NULL) 
							OR (per.Phone3Type = 'Mobile' AND per.Phone3 <> '' AND per.Phone3 IS NOT NULL))) 
	IF (@count = 0)
	BEGIN
		UPDATE #ReturnCodeTable SET SendText = 0
	END
	
	
	-- is the property setup correctly for email?
	-- has an email address, and is set for resman smtp or it's own smtp
	SET @count = (SELECT count(*) 
					FROM Property p 
					WHERE p.AccountID = @accountID and p.PropertyID = @propertyID and p.Email != '' and p.Email is not null and 
					(p.EmailProviderType = 'resman' or 
						(p.SMTPServerName != '' and p.SMTPServerName IS NOT null and p.SmtpPortNumber IS NOT null and p.SmtpPortNumber > 0 )))


	IF (@count = 0)
	BEGIN
		UPDATE #ReturnCodeTable SET SendEmail = 0
	END

	SET @count = (SELECT count(*)
				  FROM Property p
					INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.PropertyID = p.PropertyID 
					INNER JOIN PropertyPhoneNumber ppn ON ppn.PropertyID = p.PropertyID AND ppn.IsActive = 1
				  WHERE
					p.PropertyID = @propertyID
					AND ipip.IntegrationPartnerItemID = 123)
	IF (@count = 0)
	BEGIN
		UPDATE #ReturnCodeTable SET SendText = 0
	END
	
	SELECT * FROM #ReturnCodeTable
	
END
GO
