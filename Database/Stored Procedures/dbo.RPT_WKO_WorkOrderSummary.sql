SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Nick Olsen
-- Create date: April 14, 2012
-- Description:	Gets a summary of work orders
-- =============================================
CREATE PROCEDURE [dbo].[RPT_WKO_WorkOrderSummary] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@startDate datetime = null,
	@endDate datetime = null,
	@statuses StringCollection READONLY,
	@includeMakeReady bit = 1,
	@includeNonMakeReady bit = 0,
	@includeProject bit = 0,
	@filterDateType nvarchar(100) = 'Reported Date',
	@employeeIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null,
	@pickListItemIDs GuidCollection READONLY	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT p.Name AS 'PropertyName',
		   wo.WorkOrderID,
		   wo.Number,
		   wo.ObjectName,
		   wo.ObjectType,
		   wo.ReportedDate AS 'DateReported',
		   wo.[Description],
		   wo.ReportedNotes AS 'Notes',
		   wo.CompletedDate AS 'DateCompleted',
		   wo.CompletedNotes AS 'CompletionNotes',
		   CASE WHEN wo.UnitNoteID IS NULL THEN CAST(0 as bit) 
				ELSE CAST(1 as bit)
		   END AS 'MakeReady',
			CASE WHEN pwoa.WorkOrderAssociationID IS NULL THEN CAST(0 as bit) 
				ELSE CAST(1 as bit)
		   END AS 'Project',
		   wo.[Status],
		   pli.Name AS 'Category',
		   wo.CancellationDate AS 'DateCancelled',
		   pli2.Name AS 'CancelledReason',
		   wo.ScheduledDate,
		   per.PreferredName + ' ' + per.LastName AS 'AssignedPerson'
	FROM WorkOrder wo
	INNER JOIN Property p on wo.PropertyID = p.PropertyID
	INNER JOIN Person per on per.PersonID = wo.AssignedPersonID
	INNER JOIN PickListItem pli ON pli.PickListItemID = wo.WorkOrderCategoryID
	LEFT JOIN PickListItem pli2 ON pli2.PickListItemID = wo.CancellationReasonPickListItemID
	LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	LEFT JOIN WorkOrderAssociation pwoa on wo.WorkOrderID = pwoa.WorkOrderID AND pwoa.ObjectType = 'Project'
	WHERE wo.PropertyID IN (SELECT Value FROM @propertyIDs)
	  AND wo.[Status] IN (SELECT Value FROM @statuses)
	  AND ((SELECT COUNT(*) FROM @employeeIDs) = 0
		OR (wo.AssignedPersonID IN (SELECT Value FROM @employeeIDs)))
	  --AND (@includeMakeReady = 1 OR wo.UnitNoteID IS NULL)
	  AND (((@includeMakeReady = 1) AND (wo.UnitNoteID IS NOT NULL))
		OR ((@includeNonMakeReady = 1) AND (wo.UnitNoteID IS NULL) AND ((@includeProject = 0) AND (pwoa.WorkOrderAssociationID IS NULL)))
		OR ((@includeNonMakeReady = 1) AND (wo.UnitNoteID IS NULL) AND ((@includeProject = 1) AND (pwoa.WorkOrderAssociationID IS NULL)))
		OR ((@includeProject = 1) AND (pwoa.WorkOrderAssociationID IS NOT NULL)))
	  AND (((@accountingPeriodID IS NULL) AND 
		  (((@filterDateType IS NULL OR @filterDateType = 'Reported Date') AND wo.ReportedDate >= @startDate AND wo.ReportedDate <= @endDate)			
		 OR (@filterDateType = 'Completed Date' AND CONVERT(date, wo.CompletedDate) >= @startDate AND CONVERT(date, wo.CompletedDate) <= @endDate)
		 OR (@filterDateType = 'Scheduled Date' AND CONVERT(date, wo.ScheduledDate) >= @startDate AND CONVERT(date, wo.ScheduledDate) <= @endDate)
		 OR (@filterDateType = 'Cancelled Date' AND CONVERT(date, wo.CancellationDate) >= @startDate AND CONVERT(date, wo.CancellationDate) <= @endDate)
		 OR (@filterDateType = 'Due Date' AND wo.DueDate >= @startDate AND wo.DueDate <= @endDate)))
		OR ((@accountingPeriodID IS NOT NULL) AND 
		  (((@filterDateType IS NULL OR @filterDateType = 'Reported Date') AND wo.ReportedDate >= pap.StartDate AND wo.ReportedDate <= pap.EndDate)			
		 OR (@filterDateType = 'Completed Date' AND CONVERT(date, wo.CompletedDate) >= pap.StartDate AND CONVERT(date, wo.CompletedDate) <= pap.EndDate)
		 OR (@filterDateType = 'Scheduled Date' AND CONVERT(date, wo.ScheduledDate) >= pap.StartDate AND CONVERT(date, wo.ScheduledDate) <= pap.EndDate)
		 OR (@filterDateType = 'Cancelled Date' AND CONVERT(date, wo.CancellationDate) >= pap.StartDate AND CONVERT(date, wo.CancellationDate) <= pap.EndDate)
		 OR (@filterDateType = 'Due Date' AND wo.DueDate >= pap.StartDate AND wo.DueDate <= pap.EndDate))))
	  AND ((SELECT COUNT(*) FROM @pickListItemIDs) = 0
	   OR (pli.PickListItemID IN (SELECT Value FROM @pickListItemIDs)))
	ORDER BY wo.Number		
END

GO
