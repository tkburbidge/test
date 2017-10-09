SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: October 31, 2012
-- Description:	Get the Attendees
-- =============================================
CREATE PROCEDURE [dbo].[GetEventAttendees] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@objectIDs GuidCollection readonly
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	  
	SELECT 
		u.UserID as 'ObjectID',
		'User' AS 'ObjectType',
		(p.PreferredName + ' ' + p.LastName) AS 'Name',
		u.CalendarColor AS 'Color'		
	FROM [User] u
	INNER JOIN Person p on p.PersonID = u.PersonID
	INNER JOIN PersonType pt ON pt.PersonID = p.PersonID	
	WHERE u.AccountID = @accountID
		AND pt.[Type] IN ('Employee', 'User')
	    AND u.UserID IN (SELECT Value FROM @objectIDs)
		
	UNION ALL
								
	SELECT 
		prop.PropertyID as 'ObjectID',
		'Property' AS 'ObjectType',
		prop.Name,
		prop.CalendarColor AS 'Color'
	FROM Property prop	
	WHERE prop.AccountID = @accountID
		AND prop.PropertyID IN (SELECT Value FROM @objectIDs)
END
GO
