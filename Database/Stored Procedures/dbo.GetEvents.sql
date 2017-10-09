SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Updated By: Trevor Burbidge
-- =============================================
CREATE PROCEDURE [dbo].[GetEvents] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@startDate datetime,
	@endDate datetime,
	@objectIDs GuidCollection readonly
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
		(CASE WHEN u.UserID IS NOT NULL THEN u.CalendarColor 
			  WHEN prop.PropertyID IS NOT NULL THEN prop.CalendarColor
		 END) AS Color,
		e.IsAllDayEvent,
		'e' as EventType,
		'' as AssignedToName	
	FROM EventAttendee ea
	INNER JOIN [Event] e ON e.EventID = ea.EventID
	LEFT JOIN [User] u ON u.UserID = ea.ObjectID
	LEFT JOIN Property prop ON prop.PropertyID = ea.ObjectID
	WHERE ea.ObjectID IN (SELECT Value FROM @objectIDs)
		AND e.[Start] >= @startDate 
		AND e.[Start] <= @endDate
		
	union all 
	select
		t.AlertTaskID as EventID,
		t.[Subject] AS Title,
		'' as Location,
		t.[Message] as [Description],
		t.DateDue as [Start],
		t.DateDue as [End],
		null as RecurringEventID,
		u.CalendarColor AS Color,
		cast (1 as bit) as IsAllDayEvent,
		't'  as EventType,
		per.FirstName + ' ' + per.LastName as AssignedToName	
		from dbo.AlertTask t
		INNER JOIN TaskAssignment ta ON ta.AlertTaskID = t.AlertTaskID
		left join [User] u on u.PersonID = ta.PersonID
		LEFT JOIN Person per on u.PersonID = per.PersonID 
		where u.UserID in (SELECT Value FROM @objectIDs)
		  AND ta.IsCarbonCopy = 0
		AND t.DateDue >= @startDate
		AND t.DateDue <= @endDate	
		AND t.TaskStatus <> 'Completed'
	
		union all 
	select
		w.WorkOrderID as EventID,
		w.[Description] AS Title,
		w.ObjectName as Location,
		w.[Description] as [Description],
		coalesce (w.ScheduledDate, w.DueDate) as [Start],
		coalesce (w.ScheduledDate, w.DueDate) as [End],
		null as RecurringEventID,
		u.CalendarColor AS Color,
		cast (1 as bit) as IsAllDayEvent,
		'w' as EventType,
		(CASE WHEN w.VendorID IS NOT NULL THEN ven.CompanyName 
			  WHEN w.VendorID IS NULL THEN per.FirstName + ' ' + per.LastName
		 END) AS AssignedToName 	
		from dbo.WorkOrder w
		LEFT JOIN [User] u on u.PersonID = w.AssignedPersonID
		LEFT JOIN Person per on u.PersonID = per.PersonID
		LEFT JOIN Vendor ven on w.VendorID = ven.VendorID
		where u.UserID in (SELECT Value FROM @objectIDs)
		AND coalesce (w.ScheduledDate, w.DueDate) >= @startDate
		AND coalesce (w.ScheduledDate, w.DueDate) <= @endDate	
		AND w.Status <> 'Completed'
	--ORDER BY [Start]				
END




GO
