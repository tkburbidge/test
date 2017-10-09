SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Phillip Lundquist
-- Create date: May 22, 2012
-- Description:	Generates the data for the Tasks Per Employee Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TASKS_TaskList]
	-- Add the parameters for the stored procedure here
	@employeeIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@taskStatuses StringCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SELECT 
		p.PreferredName + ' ' + p.LastName AS 'AssignedPersonName',
		ta.PersonID AS 'AssignedToPersonID', 
		at.DateDue AS 'DueDate',
		at.[Subject] AS 'Subject', 
		at.[Message] AS 'Description', 
		at.Importance AS 'Importance',
		(SELECT COUNT(ta2.PersonID)
			FROM AlertTask at2
			INNER JOIN TaskAssignment ta2 ON at2.AlertTaskID = ta2.AlertTaskID
			WHERE 
			ta2.PersonID = ta.PersonID
			AND ta2.IsCarbonCopy = 0
			AND ((at2.DateAssigned >= @startDate AND at2.DateAssigned <= @endDate)
				OR (at2.DateDue >= @startDate AND at2.DateDue <= @endDate))
			AND at2.TaskStatus in (SELECT Value FROM @taskStatuses)) AS 'TaskCount'
		FROM AlertTask at
		INNER JOIN TaskAssignment ta ON at.AlertTaskID = ta.AlertTaskID
		INNER JOIN Person p ON p.PersonID = ta.PersonID
		INNER JOIN Ordering o ON o.Value = at.Importance
		
		-- We need to LEFT JOIN EVERYTHING that could possible be 
		LEFT JOIN Unit u ON at.ObjectID = u.UnitID
		LEFT JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
		LEFT JOIN Building b ON at.ObjectID = b.BuildingID
		LEFT JOIN WOITAccount woit ON at.ObjectID = woit.WOITAccountID
		LEFT JOIN Property prop ON ut.PropertyID = prop.PropertyID OR b.PropertyID = prop.PropertyID OR woit.PropertyID = prop.PropertyID
		LEFT JOIN PropertyAccountingPeriod pap ON prop.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE
		p.PersonID IN (SELECT Value FROM @employeeIDs)
		AND ta.IsCarbonCopy = 0
		--AND ((at.DateAssigned >= @startDate AND at.DateAssigned <= @endDate)
		--	  OR (at.DateDue >= @startDate AND at.DateDue <= @endDate))
		AND (((@accountingPeriodID IS NULL)
			AND (((at.DateAssigned >= @startDate AND at.DateAssigned <= @endDate)
				  OR (at.DateDue >= @startDate AND at.DateDue <= @endDate))))
		  OR ((@accountingPeriodID IS NOT NULL)
			AND (((at.DateAssigned >= pap.StartDate AND at.DateAssigned <= pap.EndDate)
				  OR (at.DateDue >= pap.StartDate AND at.DateDue <= pap.EndDate)))))		  	
		AND at.TaskStatus in (SELECT Value FROM @taskStatuses)	
		ORDER BY at.DateDue, o.OrderBy
END
GO
