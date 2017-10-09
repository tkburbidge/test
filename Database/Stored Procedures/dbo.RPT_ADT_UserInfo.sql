SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Josh Grigg
-- Create date: Jan. 24, 2017
-- Description:	Shows basic information for all account users
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ADT_UserInfo]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT
			u.UserID,
			u.Username,
			u.SecurityRoleID,
			sr.[Name] AS 'SecurityRoleName',
			u.WorkflowGroupID,
			wfg.[Name] AS 'WorkflowGroupName',
			u.IsDisabled,
			u.LastLoginDate,
			p.PersonID,
			p.FirstName,
			p.LastName,
			p.Email,
			pt.PersonTypeID,
			pt.[Type] AS 'PersonType'
		FROM Person p 
			INNER JOIN [User] u on p.PersonID = u.PersonID
			INNER JOIN SecurityRole sr on u.SecurityRoleID = sr.SecurityRoleID
			INNER JOIN PersonType pt on p.PersonID = pt.PersonID
			LEFT JOIN WorkflowGroup wfg on u.WorkflowGroupID = wfg.WorkflowGroupID
		WHERE p.AccountID = @accountID
END
GO
