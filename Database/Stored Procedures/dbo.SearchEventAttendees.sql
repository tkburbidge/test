SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: October 31, 2012
-- Description:	Get the events for a date range and
--				a given set of ObjectIDs
-- =============================================
CREATE PROCEDURE [dbo].[SearchEventAttendees] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@term nvarchar(500)
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
		AND u.IsDisabled = 0
		AND pt.[Type] IN ('Employee', 'User')
	    AND (p.FirstName LIKE ('%' + @term + '%')
			 OR p.LastName LIKE ('%' + @term + '%')
			 OR p.PreferredName LIKE ('%' + @term + '%'))
		
	UNION ALL
								
	SELECT 
		prop.PropertyID as 'ObjectID',
		'Property' AS 'ObjectType',
		prop.Name,
		prop.CalendarColor AS 'Color'
	FROM Property prop	
	WHERE prop.AccountID = @accountID
		AND prop.IsArchived = 0
		AND prop.Name LIKE ('%' + @term + '%')		
	ORDER BY Name
END
GO
