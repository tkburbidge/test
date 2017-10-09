SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: 11/19/2012
-- Description:	Delete Events related to a recurring event (and optionaly by date)
-- =============================================
CREATE PROCEDURE [dbo].[DeleteScheduledEvents] 
	-- Add the parameters for the stored procedure here
	@AccountID BigInt, 
	@RecurringEventID UniqueIdentifier,
	@EventDate DateTime = null
AS
BEGIN 
	Delete
	From EventAttendee
	Where EventID in (Select EventID FROM [Event]
	Where	AccountID = @AccountID 
			and RecurringEventId = @recurringEventID
			and ((@EventDate is null) or (Start >= @EventDate)))
	
	Delete
	FROM [Event]
	Where	AccountID = @AccountID 
			and RecurringEventId = @recurringEventID
			and ((@EventDate is null) or (Start >= @EventDate))
			
END
GO
