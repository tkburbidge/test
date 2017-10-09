SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 5, 2012
-- Description:	Gets PropertyIDs for a given AccountID
-- =============================================
CREATE PROCEDURE [dbo].[GetPropertyIDsByAccount] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT DISTINCT PropertyID FROM Property --WHERE AccountID = @accountID
	
END
GO
