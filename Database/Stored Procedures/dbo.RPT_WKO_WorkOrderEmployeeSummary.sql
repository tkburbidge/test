SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Phillip Lundquist
-- Create date: May 4, 2012
-- Description:	Generates the data for the WorkOrderEmployeeSummary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_WKO_WorkOrderEmployeeSummary]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		
	CREATE TABLE #Averages (WorkOrderID UNIQUEIDENTIFIER, 
				PersonID UNIQUEIDENTIFIER, 
				PropertyID UNIQUEIDENTIFIER, 
				[Days] INT, 
				[Time] INT)
	
	CREATE TABLE #PersonIDs (
		PersonID UNIQUEIDENTIFIER,
		PropertyID UNIQUEIDENTIFIER
	)	
	
	INSERT INTO #PersonIDs
		SELECT DISTINCT 
			wo.AssignedPersonID,
			wo.PropertyID
		FROM WorkOrder wo	
			LEFT JOIN PropertyAccountingPeriod pap ON wo.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID	
		WHERE wo.[Status] NOT IN ('Cancelled')
			--AND wo.ReportedDate >= @startDate
			--AND wo.ReportedDate <= @endDate
			AND (((@accountingPeriodID IS NULL) AND (wo.ReportedDate >= @startDate)	AND (wo.ReportedDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (wo.ReportedDate >= pap.StartDate)	AND (wo.ReportedDate <= pap.EndDate)))
			AND wo.PropertyID IN (SELECT Value FROM @propertyIDs)
	
	INSERT INTO #PersonIDs		
		SELECT DISTINCT 
			wo.CompletedPersonID,
			wo.PropertyID
		FROM WorkOrder wo	
			LEFT JOIN PropertyAccountingPeriod pap ON wo.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID				
		WHERE wo.[Status] NOT IN ('Cancelled')
			--AND wo.ReportedDate >= @startDate
			--AND wo.ReportedDate <= @endDate
			AND (((@accountingPeriodID IS NULL) AND (wo.ReportedDate >= @startDate)	AND (wo.ReportedDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (wo.ReportedDate >= pap.StartDate)	AND (wo.ReportedDate <= pap.EndDate)))			
			AND wo.PropertyID IN (SELECT Value FROM @propertyIDs)
				
	INSERT INTO #Averages
		SELECT
			wo.WorkOrderID,			
			wo.CompletedPersonID,
			wo.PropertyID,
			DateDiff(DAY, wo.ReportedDate, wo.CompletedDate) AS 'Days', 
			DateDiff(HOUR, wo.StartedDate, wo.CompletedDate) AS 'Time'

		FROM WorkOrder wo
			LEFT JOIN PropertyAccountingPeriod pap ON wo.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID			
		WHERE wo.[Status] NOT IN ('Cancelled')
			AND wo.StartedDate IS NOT NULL 
			AND wo.CompletedDate IS NOT NULL
			--AND wo.ReportedDate >= @startDate
			--AND wo.ReportedDate <= @endDate
			AND (((@accountingPeriodID IS NULL) AND (wo.ReportedDate >= @startDate)	AND (wo.ReportedDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (wo.ReportedDate >= pap.StartDate)	AND (wo.ReportedDate <= pap.EndDate)))			
			AND wo.PropertyID IN (SELECT Value FROM @propertyIDs)
			
	SELECT DISTINCT
		prop.Name AS 'PropertyName',
		p.PreferredName + ' ' + p.LastName AS 'Employee',
		(SELECT 
			Count(woa.AssignedPersonID) 
		FROM WorkOrder woa 
			LEFT JOIN PropertyAccountingPeriod pap ON woa.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE woa.[Status] NOT IN ('Cancelled')
			AND woa.AssignedPersonID = PersonIDs.PersonID
			AND woa.PropertyID = PersonIDs.PropertyID
			--AND woa.ReportedDate >= @startDate
			--AND woa.ReportedDate <= @endDate
			AND (((@accountingPeriodID IS NULL) AND (woa.ReportedDate >= @startDate)	AND (woa.ReportedDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (woa.ReportedDate >= pap.StartDate)	AND (woa.ReportedDate <= pap.EndDate)))) AS 'AssignedTo',
		(SELECT
			Count(wos.[Status])
		FROM WorkOrder wos
			LEFT JOIN PropertyAccountingPeriod pap ON wos.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE wos.[Status] NOT IN ('Cancelled')
			AND wos.AssignedPersonID = PersonIDs.PersonID
			AND wos.PropertyID = PersonIDs.PropertyID
			--AND wos.ReportedDate >= @startDate
			--AND wos.ReportedDate <= @endDate
			AND (((@accountingPeriodID IS NULL) AND (wos.ReportedDate >= @startDate)	AND (wos.ReportedDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (wos.ReportedDate >= pap.StartDate)	AND (wos.ReportedDate <= pap.EndDate)))			
			AND wos.[Status] IN ('Not Started', 'Submitted')) AS 'NotStarted',
		(SELECT
			Count(wos.[Status])
		FROM WorkOrder wos
			LEFT JOIN PropertyAccountingPeriod pap ON wos.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE wos.[Status] NOT IN ('Cancelled')
			AND wos.AssignedPersonID = PersonIDs.PersonID
			AND wos.PropertyID = PersonIDs.PropertyID
			--AND wos.ReportedDate >= @startDate
			--AND wos.ReportedDate <= @endDate
			AND (((@accountingPeriodID IS NULL) AND (wos.ReportedDate >= @startDate)	AND (wos.ReportedDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (wos.ReportedDate >= pap.StartDate)	AND (wos.ReportedDate <= pap.EndDate)))			
			AND wos.[Status] = 'Scheduled') AS 'Scheduled',
		(SELECT
			Count(wop.[Status])
			FROM WorkOrder wop
				LEFT JOIN PropertyAccountingPeriod pap ON wop.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE wop.[Status] NOT IN ('Cancelled')
				AND wop.AssignedPersonID = PersonIDs.PersonID
				AND wop.PropertyID = PersonIDs.PropertyID
				--AND wop.ReportedDate >= @startDate
				--AND wop.ReportedDate <= @endDate
				AND (((@accountingPeriodID IS NULL) AND (wop.ReportedDate >= @startDate)	AND (wop.ReportedDate <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (wop.ReportedDate >= pap.StartDate)	AND (wop.ReportedDate <= pap.EndDate)))				
				AND wop.[Status] IN ('In Progress', 'On Hold')) AS 'InProgress',
		(SELECT
			Count(woc.[Status])
			FROM WorkOrder woc
				LEFT JOIN PropertyAccountingPeriod pap ON woc.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE woc.[Status] NOT IN ('Cancelled')
				AND woc.AssignedPersonID = PersonIDs.PersonID
				AND woc.PropertyID = PersonIDs.PropertyID
				--AND woc.ReportedDate >= @startDate
				--AND woc.ReportedDate <= @endDate
				AND (((@accountingPeriodID IS NULL) AND (woc.ReportedDate >= @startDate)	AND (woc.ReportedDate <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (woc.ReportedDate >= pap.StartDate)	AND (woc.ReportedDate <= pap.EndDate)))				
				AND woc.[Status] IN ('Completed', 'Closed')) AS 'Completed',		
		(SELECT
			Count(woc.[Status])
			FROM WorkOrder woc
				LEFT JOIN PropertyAccountingPeriod pap ON woc.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE woc.[Status] NOT IN ('Cancelled')
				AND woc.AssignedPersonID = PersonIDs.PersonID
				AND woc.PropertyID = PersonIDs.PropertyID
				AND (((@accountingPeriodID IS NULL) AND (woc.ReportedDate >= @startDate)	AND (woc.ReportedDate <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (woc.ReportedDate >= pap.StartDate)	AND (woc.ReportedDate <= pap.EndDate)))		
				AND woc.DueDate < getdate()		
				AND woc.[Status] NOT IN ('Completed', 'Closed')) AS 'Overdue',
		(SELECT
			TOP 1 wonc.ReportedDate
		FROM WorkOrder wonc
			LEFT JOIN PropertyAccountingPeriod pap ON wonc.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE wonc.[Status] NOT IN ('Cancelled')
			AND wonc.AssignedPersonID = PersonIDs.PersonID
			AND wonc.PropertyID = PersonIDs.PropertyID
			--AND wonc.ReportedDate >= @startDate
			--AND wonc.ReportedDate <= @endDate
			AND (((@accountingPeriodID IS NULL) AND (wonc.ReportedDate >= @startDate)	AND (wonc.ReportedDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (wonc.ReportedDate >= pap.StartDate)	AND (wonc.ReportedDate <= pap.EndDate)))			
			AND wonc.[Status] NOT IN ('Completed', 'Closed') ORDER BY wonc.ReportedDate DESC) AS 'OldestNotCompletedDate',
		(SELECT
			Count(wodb.CompletedPersonID)
		FROM WorkOrder wodb
			LEFT JOIN PropertyAccountingPeriod pap ON wodb.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE wodb.[Status] NOT IN ('Cancelled')
		    AND wodb.CompletedPersonID = PersonIDs.PersonID
			AND wodb.PropertyID = PersonIDs.PropertyID
			--AND wodb.ReportedDate >= @startDate
			--AND wodb.ReportedDate <= @endDate	
			AND (((@accountingPeriodID IS NULL) AND (wodb.ReportedDate >= @startDate)	AND (wodb.ReportedDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (wodb.ReportedDate >= pap.StartDate)	AND (wodb.ReportedDate <= pap.EndDate)))				
			AND wodb.[Status] IN ('Completed', 'Closed')) AS 'WorkDoneBy',
		(SELECT
			Count(wocbd.CompletedPersonID)
		FROM WorkOrder wocbd
			LEFT JOIN PropertyAccountingPeriod pap ON wocbd.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE wocbd.[Status] NOT IN ('Cancelled')
			AND wocbd.CompletedPersonID = PersonIDs.PersonID
			AND wocbd.PropertyID = PersonIDs.PropertyID
			--AND wocbd.ReportedDate >= @startDate
			--AND wocbd.ReportedDate <= @endDate	
			AND (((@accountingPeriodID IS NULL) AND (wocbd.ReportedDate >= @startDate)	AND (wocbd.ReportedDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (wocbd.ReportedDate >= pap.StartDate)	AND (wocbd.ReportedDate <= pap.EndDate)))					
			AND wocbd.DueDate > wocbd.CompletedDate) AS 'CompletedBeforeDueDateNum',				
		(SELECT
			Avg([Days])
			FROM #Averages tmp
			WHERE
			tmp.PersonID = PersonIDs.PersonID
			AND tmp.PropertyID = PersonIDs.PropertyID) AS 'AvgDaysToComplete',				
		(SELECT
			Avg([Time])
			FROM #Averages tmp
			WHERE
			tmp.PersonID = PersonIDs.PersonID
			AND tmp.PropertyID = PersonIDs.PropertyID) AS 'AvgTimeWorkOrder'
		FROM 
			(SELECT DISTINCT * FROM #PersonIDs) PersonIDs
			INNER JOIN Person p ON p.PersonID = PersonIDs.PersonID			
			INNER JOIN Property prop ON prop.PropertyID = PersonIDs.PropertyID
		
		DROP TABLE #Averages
		DROP TABLE #PersonIDs	
END
GO
