SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 23, 2012
-- Description:	Satisfies RentableItem waiting lists
-- =============================================
CREATE PROCEDURE [dbo].[SatisfyRentableItemWaitingList] 
	-- Add the parameters for the stored procedure here
	@personIDs GuidCollection READONLY, 
	@ledgerItemID uniqueidentifier = null,
	@ledgerItemPoolID uniqueidentifier = null,
	@date date = null
AS
DECLARE @updatedRows int

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	UPDATE WaitingList SET DateSatisfied = @date
		WHERE PersonID IN (SELECT Value FROM @personIDs)
		  AND ObjectID = @ledgerItemID
	SET @updatedRows = @@ROWCOUNT
	
	IF (@updatedRows = 0)
	BEGIN
		UPDATE WL SET WL.DateSatisfied = (SELECT TOP 1 wt.DateCreated
													FROM WaitingList wt
													WHERE wt.PersonID IN (SELECT Value FROM @personIDs)
													ORDER BY wt.DateCreated)
			FROM WaitingList WL
			WHERE WL.PersonID IN (SELECT Value FROM @personIDs)
	END
	
END
GO
