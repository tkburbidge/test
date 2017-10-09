SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: 9/10/2013
-- Description:	Get a list of appointments for a specified prospect/user etc
-- =============================================
CREATE PROCEDURE [dbo].[GetAppointments] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@objectID uniqueIdentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	select  
			e.EventID,
			e.Start,
			e.[End],
			e.Title as Subject,
			e.[Description],
			e.Location,
			p.PreferredName + ' ' + p.LastName as Attendee,
			e.IsAllDayEvent

			from [Event] e
			join [EventAttendee] ea on e.EventID = ea.EventID
			join [User] u on ea.ObjectID = u.UserID
			join [Person] p on u.PersonID = p.PersonID
			where e.AccountID = @accountID and e.objectID= @objectID

	union all
	select  
			e.EventID,
			e.Start,
			e.[End],
			e.Title as Subject,
			e.[Description],
			e.Location,
			p.Name as Attendee,
			e.IsAllDayEvent

			from [Event] e
			join [EventAttendee] ea on e.EventID = ea.EventID
			join Property p on ea.ObjectID = p.PropertyID
			where e.AccountID = @accountID and e.objectID= @objectID
END
GO
