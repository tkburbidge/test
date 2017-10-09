SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: October 31, 2012
-- Description:	Get an event
-- =============================================
-- sproc changed due to table changes
CREATE PROCEDURE [dbo].[GetEvent] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@eventID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT 
		e.EventID,
		e.Title,
		e.Location,
		e.[Description],
		e.[Start],
		e.[End],
		e.RecurringEventID,
		e.IsAllDayEvent,
		e.IsPortalVisible,
		e.ObjectType as EventObjectType,
		e.ObjectID as EventObjectID,
		re.StartDate AS 'RecurringStartDate',
		re.EndDate AS 'RecurringEndDate',
		re.EndDate AS 'RecurringEndTime',
		COALESCE (re.Frequency, 0) as Frequency, 
		COALESCE (re.DaysOfWeek,0) as DaysOfWeek,
		COALESCE (re.MonthlyInterval, 0) as MonthlyInterval,
		COALESCE (re.EveryXDays, 0) as EveryXDays,		
		COALESCE (re.DaysOfMonth, 0) AS DaysOfMonth,
		(CASE WHEN u.UserID IS NOT NULL THEN (uper.PreferredName + ' ' + uper.LastName)
			  WHEN prop.PropertyID IS NOT NULL THEN prop.Name
		 END) AS AttendeeObjectName,
		 ea.ObjectType as AttendeeObjectType,
		(CASE WHEN u.UserID IS NOT NULL THEN u.UserID
			  WHEN prop.PropertyID IS NOT NULL THEN prop.PropertyID
		 END) AS AttendeeObjectID,		 
		(CASE WHEN u.UserID IS NOT NULL THEN u.CalendarColor 
			  WHEN prop.PropertyID IS NOT NULL THEN prop.CalendarColor
		 END) AS Color
	FROM [Event] e
	INNER JOIN EventAttendee ea ON ea.EventID = e.EventID
	LEFT JOIN RecurringEvent re ON re.RecurringEventID = e.RecurringEventID
	LEFT JOIN [User] u ON u.UserID = ea.ObjectID
	LEFT JOIN [Person] uper ON uper.PersonID = u.PersonID
	LEFT JOIN Property prop ON prop.PropertyID = ea.ObjectID
	WHERE e.AccountID = @accountID
		AND e.EventID = @eventID
END
GO
