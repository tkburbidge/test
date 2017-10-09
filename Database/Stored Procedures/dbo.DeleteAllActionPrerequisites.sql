SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 11/7/2013
-- Description:	Deletes all the action prerequisites for a given property and prerequisite type
-- =============================================
CREATE PROCEDURE [dbo].[DeleteAllActionPrerequisites] 
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
	DELETE FROM ActionPrerequisiteItem 
		WHERE AccountID = @accountID AND PropertyID = @propertyID AND [Type] = @type
END
GO
