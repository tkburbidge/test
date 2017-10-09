SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 23, 2014
-- Description:	Populates the Job table for the day!
-- =============================================
CREATE PROCEDURE [dbo].[GetJobsToQueue]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #JobsForToday (
		JobID uniqueidentifier not null,
		AccountID bigint not null,
		Name nvarchar(50) null,
		ObjectID uniqueidentifier null,
		ObjectType nvarchar(50) null,
		TimeToRun datetime null,
		StartTime datetime null,
		EndTime datetime null,
		[Status] nvarchar(50) null,
		Note nvarchar(MAX) null,
		TimeZoneID nvarchar(50) null)
		
	CREATE TABLE #RecurringItemsIGot (
		RecurringItemID uniqueidentifier null,
		AccountID bigint null,
		PersonID uniqueidentifier null,
		Name nvarchar(50) null,
		AssignedToPersonID uniqueidentifier null)
		
		
	INSERT #RecurringItemsIGot 
		EXEC GetRecurringItemsByType @accountID, 'ReportBatch', @date

	INSERT #JobsForToday
		SELECT	NEWID(), #rcig.AccountID, rrb.Name, #rcig.RecurringItemID, 'Recurring Report',
				CAST(@date AS datetime) + CAST(rrbi.[Time] AS datetime), null, null, 'Not Started', null, 
				COALESCE(p.TimeZoneID, groupedProp.TimeZoneID) AS 'TimeZoneID'
			FROM #RecurringItemsIGot #rcig
				INNER JOIN RecurringReportBatchItem rrbi ON #rcig.RecurringItemID = rrbi.RecurringItemID
				INNER JOIN RecurringReportBatch rrb ON rrbi.RecurringReportBatchID = rrb.RecurringReportBatchID
				LEFT JOIN Property p ON rrbi.PropertyOrGroupID = p.PropertyID
				LEFT JOIN PropertyGroupProperty pgp ON rrbi.PropertyOrGroupID = pgp.PropertyGroupID
							AND pgp.PropertyID = (SELECT TOP 1 PropertyID
													FROM PropertyGroupProperty
													WHERE PropertyGroupID = rrbi.PropertyOrGroupID)
				LEFT JOIN Property groupedProp ON pgp.PropertyID = groupedProp.PropertyID 
		
	SELECT * FROM #JobsForToday
	
END
GO
