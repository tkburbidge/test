SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Craig Perkins
-- Create date: November 15, 2013
-- Description:	Gets a list of employees for the specified account
-- =============================================
CREATE PROCEDURE [dbo].[API_GetEmployees] 
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
		ptp.PersonTypePropertyID AS 'ID',
		p.Phone1 AS 'Phone',
		p.Email,
		sr.Name AS 'SecurityGroup'
	FROM PersonTypeProperty ptp
		JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
		JOIN Person p ON pt.PersonID = p.PersonID
		JOIN Employee e ON p.PersonID = e.PersonID
		LEFT JOIN [User] u ON p.PersonID = u.PersonID
		LEFT JOIN SecurityRole sr ON u.SecurityRoleID = sr.SecurityRoleID
	WHERE 
		ptp.AccountID = @accountID
		AND ptp.PropertyID = @propertyID
		AND pt.[Type] = 'Employee'
		AND ptp.HasAccess = 1
		--AND (e.[Type] = 1 OR e.[Type] = 3 OR e.[Type] = 7 or e.[Type] = 5)	-- only return Leasing employees
		AND e.[Type] & 1 = 1
END
GO
