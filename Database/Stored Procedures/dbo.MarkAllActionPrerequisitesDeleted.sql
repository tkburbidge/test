SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Joshua Grigg
-- Create date: 2/18/2015
-- Description:	Sets IsDeleted to 1 for all the action prerequisites for a given property and prerequisite type
-- =============================================

CREATE PROCEDURE [dbo].[MarkAllActionPrerequisitesDeleted]
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@propertyID uniqueidentifier,
	@type nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	UPDATE ActionPrerequisiteItem 
		SET IsDeleted = 1
		WHERE AccountID = @accountID
		  AND PropertyID = @propertyID
		  AND [Type] = @type
		  AND (Name != 'ResidentAgreesToReSurance') -- add future not editable ones here as well
END
GO
