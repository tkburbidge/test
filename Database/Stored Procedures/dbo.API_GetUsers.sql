SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Thomas Hutchins
-- Create date: 1/17/17
-- Description:	Gets a list of users for the specified account
-- =============================================
CREATE PROCEDURE [dbo].[API_GetUsers] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	DISTINCT
		p.PreferredName + ' ' + p.LastName AS 'Name',
		u.UserID AS 'ID',
		u.Username AS 'Username',
		p.Email,
		sr.Name AS 'PermissionGroup'
	FROM PersonTypeProperty ptp
		JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
		JOIN Person p ON pt.PersonID = p.PersonID
		LEFT JOIN [User] u ON p.PersonID = u.PersonID
		LEFT JOIN SecurityRole sr ON u.SecurityRoleID = sr.SecurityRoleID
	WHERE 
		ptp.AccountID = @accountID
		AND ptp.PropertyID = @propertyID
		AND pt.[Type] = 'User'
		AND ptp.HasAccess = 1 --Employees had this so I'm copying it
END
GO
