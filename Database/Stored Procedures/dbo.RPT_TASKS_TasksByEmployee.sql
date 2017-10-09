SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Phillip Lundquist
-- Create date: May 15, 2012
-- Description:	Generates the data for the Tasks by Employee Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TASKS_TasksByEmployee] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
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
		at.AlertTaskID AS 'AlertTaskID', 
		ta.PersonID AS 'AssignedToPersonID', 
		at.DateAssigned AS 'DateAssigned',
		at.[Subject] AS 'Subject', 
		at.[Message] AS 'Notes', 
		at.Importance AS 'Importance', 
		at.TaskStatus AS 'Status', 
		at.DateDue AS 'DueDate',
		at.PercentComplete AS 'PercentComplete', 
		at.DateCompleted AS 'DateCompleted', 
		at.TimeToComplete AS 'TimeToComplete'
		FROM AlertTask at
			INNER JOIN TaskAssignment ta ON ta.AlertTaskID = at.AlertTaskID
			INNER JOIN Person p ON p.PersonID = ta.PersonID
			INNER JOIN PersonType pt ON p.PersonID = pt.PersonID AND pt.[Type] = 'Employee'
			INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID AND ptp.PropertyID IN (SELECT Value FROM @propertyIDs) AND ptp.HasAccess = 1
			LEFT JOIN Unit u ON at.ObjectID = u.UnitID
			LEFT JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			LEFT JOIN Building b ON at.ObjectID = b.BuildingID 
			LEFT JOIN WOITAccount woit ON at.ObjectID = woit.WOITAccountID
			LEFT JOIN Property prop ON ut.PropertyID = prop.PropertyID OR b.PropertyID = prop.PropertyID OR woit.PropertyID = prop.PropertyID
			LEFT JOIN PropertyAccountingPeriod pap ON prop.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE ta.IsCarbonCopy = 0
		--p.PersonID IN (SELECT
		--				per.PersonID
		--				FROM Person per
		--				INNER JOIN PersonType pt ON pt.PersonID = per.PersonID
		--				INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID
		--				WHERE
		--				ptp.PropertyID IN (SELECT Value FROM @propertyIDs)
		--				AND pt.[Type] = 'Employee'
		--				)
		--AND ((at.DateAssigned >= @startDate AND at.DateAssigned <= @endDate)
		--	  OR (at.DateDue >= @startDate AND at.DateDue <= @endDate))
		AND (((@accountingPeriodID IS NULL) AND (((at.DateAssigned >= @startDate) AND (at.DateAssigned <= @endDate)) OR ((at.DateDue >= @startDate) AND (at.DateDue <= @endDate))))
		  OR ((@accountingPeriodID IS NOT NULL) AND (((at.DateAssigned >= pap.StartDate) AND (at.DateAssigned <= pap.EndDate)) OR ((at.DateDue >= pap.StartDate) AND (at.DateDue <= pap.EndDate)))))
		AND at.TaskStatus in (SELECT Value FROM @taskStatuses)
		
END
GO
