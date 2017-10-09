SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[GetJobDetails]
	@recurringItemID uniqueidentifier = null

AS
BEGIN

		
	SELECT	rrb.ReportBatchID, rrb.RecurringReportBatchID, rrbi.PropertyOrGroupID, 
			CASE 
				WHEN (rrb.FromObjectType = 'Person') THEN per.Email
				ELSE fromProp.Email END AS 'FromEmailAddress',
			CASE 
				WHEN (rrb.FromObjectType = 'Person') THEN per.PreferredName + ' ' + per.LastName
				ELSE fromProp.Name END AS 'FromEmailName',	
			rrbi.Recipients,
			ri.PersonID,
			s.Subdomain
		FROM RecurringItem ri
			INNER JOIN RecurringReportBatchItem rrbi ON ri.RecurringItemID = rrbi.RecurringItemID
			INNER JOIN RecurringReportBatch rrb ON rrbi.RecurringReportBatchID = rrb.RecurringReportBatchID
			INNER JOIN Settings s ON ri.AccountID = s.AccountID
			LEFT JOIN Person per ON rrb.FromObjectID = per.PersonID
			LEFT JOIN Property fromProp ON rrb.FromObjectID = fromProp.PropertyID
		WHERE ri.RecurringItemID = @recurringItemID

END


GO
