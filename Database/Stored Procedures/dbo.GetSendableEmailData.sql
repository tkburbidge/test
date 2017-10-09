SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Art Olsen
-- Create date: 2/7/2014
-- Description:	Get data needed to create a one off email
-- =============================================
CREATE PROCEDURE [dbo].[GetSendableEmailData] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@senderID	uniqueidentifier, 
	@recipientID uniqueidentifier,
	@objectID	uniqueidentifier = null,
	@personType	nvarchar(30),
	@vendorID	uniqueidentifier = null,
	@unitLeaseGroupID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@availablePropertyIDs GuidCollection readonly
AS
BEGIN
	CREATE TABLE #Properties(
		PropertyID	uniqueidentifier not null,
		Name nvarchar(50) null,
		EmailAddress nvarchar(256))
	CREATE TABLE #Recipients(
		PersonID uniqueidentifier not null,
		Name nvarchar(201) null,
		EmailAddress nvarchar(256),
		PersonType nvarchar(30),
		IsPrimaryRecipient bit, 
		SendEmail bit,
		ResidencyStatus nvarchar(30),
		MainContact bit)
	CREATE TABLE #Sender(
		PersonID uniqueidentifier,
		Name nvarchar(201),
		EmailAddress nvarchar(256),
		EmailSignature nvarchar(max))

	INSERT INTO #Sender (PersonID, Name, EmailAddress, EmailSignature) 
	SELECT @SenderID, p.PreferredName + ' ' + p.LastName, p.Email, u.EmailSignature
	FROM Person p 
		INNER JOIN [User] u ON p.PersonID = u.PersonID
	WHERE p.AccountID = @accountID 
		AND p.PersonID = @senderID



	-- depending on the persontype, get properties
	if (@PersonType = 'Resident' or @personType = 'ResidentAlternate' or @personType = 'Prospect' or @personType = 'Non-Resident Account')
	begin
		insert into #Recipients (PersonID, Name, EmailAddress, PersonType, IsPrimaryRecipient, SendEmail, ResidencyStatus, MainContact)
		select @recipientID, p.PreferredName + ' ' + ISNULL(p.LastName, ''), p.Email, @personType, 1, 1, case when pl.MoveOutDate is not null and pl.ResidencyStatus = 'Current' then 'NTV' else pl.ResidencyStatus end, case when pl.MainContact is null then 1 else pl.MainContact end
		from Person p
		left join PersonLease pl on pl.PersonID = p.PersonID
		where p.PersonID = @recipientID		
			AND p.AccountID = @accountID

		-- get any cc recipients
		-- if we are resident or resident altername, get the cc people from the objectid, which is the lease id
		if (@PersonType = 'Resident')
		begin
			insert into #Recipients (PersonID, Name, EmailAddress, PersonType, IsPrimaryRecipient, SendEmail, ResidencyStatus, MainContact)
			select p.PersonID, p.PreferredName + ' ' + p.LastName, p.Email, pt.[Type], 0, 1, case when pl.MoveOutDate IS NOT NULL AND pl.ResidencyStatus = 'Current' THEN 'NTV' else pl.ResidencyStatus end, pl.MainContact
			from PersonLease pl
			inner join Lease l on pl.LeaseID = l.LeaseID
			inner join Person p on pl.PersonID = p.PersonID
			inner join PersonType pt on p.PersonID = pt.PersonID			
			where l.AccountID = @accountID and l.LeaseID = @objectID and 			
			p.Email IS NOT NULL and p.Email != '' and p.PersonID <> @recipientID and (pt.[Type] = 'Resident' or  pt.[Type] = 'ResidentAlternate')
			order by pl.OrderBy
		end
		else if (@personType = 'ResidentAlternate')
		begin
		insert into #Recipients (PersonID, Name, EmailAddress, PersonType, IsPrimaryRecipient, SendEmail, MainContact)
			select p.PersonID, p.PreferredName + ' ' + p.LastName, p.Email, @personType, 0, 1, 0
			from Person ap 
				INNER JOIN Person p ON p.PersonID = ap.ParentPersonID
			WHERE ap.PersonID = @recipientID 
				AND ap.AccountID = @accountID
				AND p.Email IS NOT NULL 
				AND p.Email != '' 
		end
		-- if we are a propspect, the cc people are also prospects, and are related via th objectid which is the objectid
		else if (@personType = 'Prospect')
		begin	
			-- get any cc recipients, the objectid is the prospectid of the main recipient
			insert into #Recipients (PersonID, Name, EmailAddress, PersonType, IsPrimaryRecipient, SendEmail, MainContact)
			select p.PersonID, p.PreferredName + ' ' + p.LastName, p.Email, 'Prospect', 0, 1, 0
			from ProspectRoommate pr join
					Person p on pr.PersonID = p.PersonID
			where pr.AccountID = @accountID 
				AND pr.ProspectID = @objectID 
				AND pr.PersonID <> @recipientID
				AND p.Email IS NOT NULL 
				AND p.Email != ''		

			-- If the user clicked on the roomate record, we need to get the main prospect person
			-- as a cc recipient
			insert into #Recipients (PersonID, Name, EmailAddress, PersonType, IsPrimaryRecipient, SendEmail, MainContact)
			select p.PersonID, p.PreferredName + ' ' + p.LastName, p.Email, 'Prospect', 0, 1, 0
			from Prospect pr join
					Person p on pr.PersonID = p.PersonID
			where pr.AccountID = @accountID 
				AND pr.ProspectID = @objectID 
				AND pr.PersonID <> @recipientID
				AND p.Email IS NOT NULL 
				AND p.Email != ''		
		end
		
		-- get the property info, as if we are resident, @propertyID has their propertyid
		insert into #Properties (PropertyID, Name, EmailAddress)
		select p.PropertyID, p.Name, p.Email 
		from Property p
		where p.AccountID = @accountID and
					-- is in the available properties list
					 p.PropertyID = @propertyID
					-- if the email type is property, that the server is setup (server name not null or empty and port not null
					AND ((p.EmailProviderType = 'Property' and 
							p.SMTPServerName is not null AND 
							p.SMTPServerName <> '' and
							p.SMTPPortNumber is not null) or
					-- or is set to resman
                    p.EmailProviderType = 'ResMan') and
                    -- and the property's email address is not null or empty
                    (p.Email is not null and
                     p.Email <> '')
	end
	else if (@personType = 'EmployeeAlternate' or @personType = 'Employee' or @personType = 'User')
	begin
		insert into #Recipients (PersonID, Name, EmailAddress, PersonType, IsPrimaryRecipient, SendEmail, MainContact)
		select @recipientID, p.PreferredName + ' ' + p.LastName, p.Email, @personType, 1, 1, 1
		from Person p
		where p.PersonID = @recipientID				
		-- get the property info, as if we are resident, @availablePropertyIDs has the list of available propertyid's the sender has access to
		insert into #Properties (PropertyID, Name, EmailAddress)
		select p.PropertyID, p.Name, p.Email 
		from Property p
		where p.AccountID = @accountID and p.PropertyID 
					-- is in the available properties list
					in (select value from @availablePropertyIDs) 
					-- if the email type is property, that the server is setup (server name not null or empty and port not null
					AND ((p.EmailProviderType = 'Property' and 
							p.SMTPServerName is not null AND 
							p.SMTPServerName <> '' and
							p.SMTPPortNumber is not null) or
					-- or is set to resman
                    p.EmailProviderType = 'ResMan') and
                    -- and the property's email address is not null or empty
                    (p.Email is not null and
                     p.Email <> '')
	end
	else if (@personType = 'VendorGeneral' or @personType = 'VendorPayment' or @personType = 'VendorOther' or @personType = 'VendorSupport')
	begin
		insert into #Recipients (PersonID, Name, EmailAddress, PersonType, IsPrimaryRecipient, SendEmail, MainContact)
		select @recipientID, p.PreferredName, p.Email, @personType, 1, 1, 1
		from Person p
		where p.PersonID = @recipientID

		insert into #Properties (PropertyID, Name, EmailAddress)
		select p.PropertyID, p.Name, p.Email 
		from Vendor v 		
		join VendorProperty vpr on v.VendorID = vpr.VendorID
		join Property p on vpr.PropertyID = p.PropertyID
		where v.AccountID = @accountID
			and v.VendorID = @vendorID			
			and p.PropertyID 
					-- is in the available properties list
					in (select value from @availablePropertyIDs) 
					-- if the email type is property, that the server is setup (server name not null or empty and port not null
					AND ((p.EmailProviderType = 'Property' and 
							p.SMTPServerName is not null AND 
							p.SMTPServerName <> '' and
							p.SMTPPortNumber is not null) or
					-- or is set to resman
                    p.EmailProviderType = 'ResMan') and
                    -- and the property's email address is not null or empty
                    (p.Email is not null and
                     p.Email <> '')
	end
	
	select * from #Sender
	select * from #Properties
	select * from #Recipients 
END


GO
