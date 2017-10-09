SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 20, 2012
-- Description:	Updates WaitingList records
-- =============================================
CREATE PROCEDURE [dbo].[SatisfyUnitWaitingLists] 
	-- Add the parameters for the stored procedure here
	@personIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE WaitingList SET DateSatisfied = @date
		WHERE PersonID IN (SELECT Value FROM @personIDs)
		  AND ObjectType IN ('Unit', 'UnitType')
END
GO
