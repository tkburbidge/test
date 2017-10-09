SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Forrest Tait
-- Create date: Jan 13, 2016
-- Description:	This script will assign all unassigned work orders to the default work
--   order assignee. Be sure all properties have a default person assigned
--  (Admin > Properties > Resident Portal Settings > Work Orders > Assigned to),
--  otherwise those work orders will remain unassigned.
-- =============================================

CREATE PROCEDURE [dbo].[AssignUnassignedWorkOrders]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0
AS
BEGIN
	UPDATE wo
	SET AssignedPersonID = p.PortalWorkOrderAssignedToPersonID 	
	FROM WorkOrder wo 
	INNER JOIN Property p ON p.PropertyID = wo.PropertyID
	WHERE AssignedPersonID = '00000000-0000-0000-0000-000000000000'
	AND p.PortalWOrkOrderAssignedToPersonID IS NOT NULL
	AND wo.AccountID = @accountID			
END
GO
