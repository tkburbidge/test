SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: 6/21/2013
-- Description:	Delete TaskTemplateSecurityroles
-- =============================================
CREATE PROCEDURE [dbo].[DeleteTaskTemplatePersons] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@taskTemplateID UniqueIdentifier
AS
BEGIN
	DELETE FROM dbo.TaskTemplatePerson 
	WHERE AccountID = @accountID and TaskTemplateID = @taskTemplateID
END
GO
