SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Jordan Betteridge
-- Create date: August 5, 2014
-- Description:	Updates the next AlertTaskID of a resident
-- =============================================
CREATE PROCEDURE [dbo].[UpdateResidentAlertTaskID] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@leaseID uniqueidentifier = null,
	@alertTaskID uniqueidentifier = null,
	@dueDate DATE = null,
	@completed bit = 0
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- Adding/Updating a task that is NOT complete	  
	UPDATE ulg SET NextAlertTaskID = @alertTaskID
	FROM UnitLeaseGroup ulg
		INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		LEFT JOIN AlertTask at ON ulg.NextAlertTaskID = at.AlertTaskID
	WHERE ulg.AccountID = @accountID
	  AND l.LeaseID = @leaseID
	  AND (ulg.NextAlertTaskID IS NULL OR at.DateDue > @dueDate)
	  AND @completed = 0
	
	-- Updating a task that IS complete
	UPDATE ulg SET NextAlertTaskID = (SELECT TOP 1 at.AlertTaskID
										FROM AlertTask at
											INNER JOIN Lease l ON l.LeaseID = at.ObjectID
										WHERE ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
										  AND at.DateCompleted IS NULL
										  AND (at.ObjectType = 'Resident' OR at.ObjectType = 'Application')
										  AND at.AlertTaskID != @alertTaskID
										ORDER BY at.DateDue)
	FROM UnitLeaseGroup ulg
		INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	WHERE ulg.AccountID = @accountID AND
		  l.LeaseID = @leaseID AND
		  @completed = 1
		
	  
END





GO
