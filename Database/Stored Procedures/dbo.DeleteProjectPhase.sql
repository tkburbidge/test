SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Joshua Grigg
-- Create date: August 17, 2015
-- Description:	Deletes a project phase including all associated tasks, work orders, and work order associations
-- =============================================
CREATE PROCEDURE [dbo].[DeleteProjectPhase] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@projectPhaseID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #ProjectPhaseWorkOrders(
		projectID uniqueidentifier,
		workOrderID uniqueidentifier
	)

	DELETE FROM TaskAssignment
		WHERE AlertTaskID IN 
			  (SELECT at.AlertTaskID FROM AlertTask at
					WHERE at.ObjectType = 'ProjectPhase'
					  AND at.ObjectID = @projectPhaseID
					  AND at.AccountID = @accountID)
				   
	DELETE FROM AlertTask
		WHERE ObjectType = 'ProjectPhase'
		  AND ObjectID = @projectPhaseID
		  AND AccountID = @accountID

	INSERT INTO #ProjectPhaseWorkOrders
		SELECT DISTINCT
			pl.projectID as 'projectID',
			wo.WorkOrderID as 'workOrderID'
		FROM ProjectLocation pl
			JOIN WorkOrderAssociation woa on pl.ProjectID = woa.ObjectID
			JOIN WorkOrder wo on woa.WorkOrderID = wo.WorkOrderID AND wo.ObjectID = pl.ProjectLocationID
		WHERE pl.AccountID = @accountID
		  AND pl.ProjectPhaseID = @projectPhaseID

	DELETE FROM WorkOrderAssociation
		WHERE WorkOrderID IN (SELECT workOrderID FROM #ProjectPhaseWorkOrders)
		
	DELETE FROM WorkOrder 
		WHERE WorkOrderID IN (SELECT workOrderID FROM #ProjectPhaseWorkOrders)
		
	UPDATE ProjectLocation SET ProjectPhaseID = null WHERE ProjectPhaseID = @projectPhaseID

	DELETE FROM ProjectPhase
		WHERE ProjectPhaseID = @projectPhaseID	
END
GO
