SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetNotificationRecipients] 
	@accountID BIGINT,
	@notificationIDs IntCollection readonly,
	@propertyIDs GuidCollection readonly
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #Recipients (
		PersonID UNIQUEIDENTIFIER,
		PropertyID UNIQUEIDENTIFIER,
		PersonName NVARCHAR(81),
		Email NVARCHAR(256),
		NotificationID INT
    )
    DECLARE @PropertyID UNIQUEIDENTIFIER
    
    
    -- get a list of propertyid's from the input list of propertyids that have
    -- valid email setups (resman, or correctlyconfigured smtpservers)
    SET @PropertyID =	(SELECT TOP (1) p.PropertyID
						FROM Property p 
						WHERE	p.AccountID = @accountID AND
								-- is in the available properties list
								p.PropertyID IN (SELECT Value FROM @propertyIDs) 
								-- if the email type is property, that the server is setup (server name not null or empty and port not null
								AND ((p.EmailProviderType = 'Property' AND 
								p.SMTPServerName IS NOT NULL AND 
								p.SMTPServerName <> '' AND
								p.SmtpPortNumber IS NOT NULL) OR
								-- or is set to resman
								p.EmailProviderType = 'ResMan') AND
								-- and the property's email address is not null or empty
								(p.Email IS NOT NULL AND
								 p.Email <> '')
						ORDER BY p.Name)
						
	INSERT	INTO #Recipients (PersonID, PropertyID, PersonName, NotificationID, Email)
		SELECT	npg.ObjectID, @PropertyID, per.FirstName + ' ' + per.LastName, npg.NotificationID, per.Email
		FROM	NotificationPersonGroup npg 
				INNER JOIN Person per ON npg.ObjectID = per.PersonID
				INNER JOIN PersonType pt ON pt.PersonID = per.PersonID AND pt.[Type] IN ('User', 'Employee')
				INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID AND ptp.HasAccess = 1
				LEFT JOIN [User] u ON per.PersonID = u.PersonID
				LEFT JOIN Employee e ON per.PersonID = e.PersonID
		WHERE	npg.AccountID = @accountID 
				AND npg.NotificationID IN (SELECT Value FROM @notificationIDs)
				AND npg.ObjectType = 'Person'
				AND (u.UserID IS NULL OR u.IsDisabled = 0)
				AND (e.PersonID IS NULL or e.QuitDate IS NULL)				
				AND npg.IsEmailSubscribed = '1'
				AND (per.Email IS NOT NULL AND per.Email <> '')				
				AND (npg.PropertyID IS NULL OR npg.PropertyID IN (SELECT Value FROM @propertyIDs))
				AND ptp.PropertyID IN (SELECT Value FROM @propertyIDs)
			
	INSERT	INTO #Recipients (PersonID, PropertyID, PersonName, NotificationID, Email)
		SELECT	u.PersonID, @PropertyID, per.FirstName + ' ' + per.LastName, npg.NotificationID, per.Email
		FROM	NotificationPersonGroup npg 
				INNER JOIN [User] u ON npg.ObjectID = u.SecurityRoleID 
				INNER JOIN Person per ON u.PersonID = per.PersonID
				INNER JOIN PersonType pt ON pt.PersonID = per.PersonID AND pt.[Type] IN ('User', 'Employee')
				INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID AND ptp.HasAccess = 1
				LEFT JOIN Employee e ON per.PersonID = e.PersonID
		WHERE	npg.AccountID = @accountID  
				AND npg.NotificationID IN (SELECT Value FROM @notificationIDs)
				AND npg.ObjectType = 'Group' 
				AND npg.IsEmailSubscribed = '1'  
				AND u.IsDisabled = 0
				AND (e.PersonID IS NULL or e.QuitDate IS NULL)
				AND (per.Email IS NOT NULL AND per.Email <> '')
				AND (npg.PropertyID IS NULL OR npg.PropertyID IN (SELECT Value FROM @propertyIDs))
				AND ptp.PropertyID IN (SELECT Value FROM @propertyIDs)
			
	SELECT DISTINCT * FROM #Recipients GROUP BY PersonID, PropertyID, PersonName, Email, NotificationID
		
END
GO
