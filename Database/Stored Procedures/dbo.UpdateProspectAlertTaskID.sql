SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Jordan Betteridge
-- Create date: August 1, 2014
-- Description:	Updates the next AlertTaskID of a prospect
-- =============================================
CREATE PROCEDURE [dbo].[UpdateProspectAlertTaskID] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@prospectID uniqueidentifier = null,
	@alertTaskID uniqueidentifier = null,
	@dueDate DATE = null,
	@completed bit = 0
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
		  
	UPDATE p SET NextAlertTaskID = @alertTaskID
	FROM Prospect p
		LEFT JOIN AlertTask at ON p.NextAlertTaskID = at.AlertTaskID
	WHERE p.AccountID = @accountID AND
		  p.ProspectID = @prospectID AND
		  (p.NextAlertTaskID IS NULL OR at.DateDue > @dueDate) AND
		  @completed = 0
		  
	UPDATE p SET NextAlertTaskID = (SELECT TOP 1 at.AlertTaskID
										FROM AlertTask at
										WHERE p.ProspectID = at.ObjectID AND
										  	at.DateCompleted IS NULL AND
											at.ObjectType = 'Prospect' AND
											at.AlertTaskID != @alertTaskID
										ORDER BY at.DateDue)
	FROM Prospect p
	WHERE p.AccountID = @accountID AND
		  p.ProspectID = @prospectID AND
		  @completed = 1
		
	  
END




GO
