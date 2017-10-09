SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Jordan Betteridge
-- Create date: Jan. 24, 2017
-- Description:	Shows all workflow approval information.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ADT_WorkflowApprovals] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Workflows (
		WorkflowID uniqueidentifier not null,
		WorkflowName nvarchar(50) not null,
		WorkflowType nvarchar(100) not null,
		ExpenseTypeID uniqueidentifier null,
		ExpenseTypeName nvarchar(100) null,
		Step smallint not null,
		WorkflowGroupID uniqueidentifier not null,
		WorkflowGroupName nvarchar(50) null,
		Users nvarchar(max) null,
		WorkflowRuleID uniqueidentifier not null)

	CREATE TABLE #WorkflowRuleItems (
		WorkflowRuleID uniqueidentifier not null,
		WorkflowRuleItemID uniqueidentifier not null,
		RuleIsAnded bit not null,
		MinimumThreshold money null,
		MaximumThreshold money null,
		[Type] nvarchar(20) null,
		BudgetOverAmount money null)

	INSERT INTO #Workflows
		SELECT
			w.WorkflowID,
			w.Name as 'WorkflowName',
			w.WorkflowType,
			w.ExpenseTypeID,
			et.Name as 'ExpenseTypeName',
			wr.GroupOrderBy as 'Step',
			wr.ApprovalWorkflowGroupID as 'WorkflowGroupID',
			wg.Name as 'WorkflowGroupName',
			STUFF((SELECT ', ' + (p.PreferredName + ' ' + p.LastName)
					FROM Person p
						INNER JOIN [User] u on p.PersonID = u.PersonID		
					WHERE p.AccountID = @accountID
						AND u.WorkflowGroupID = wr.ApprovalWorkflowGroupID
					ORDER BY p.PreferredName, P.LastName		   
					FOR XML PATH ('')), 1, 2, '') AS 'Users',
			wr.WorkflowRuleID
		FROM Workflow w
			INNER JOIN WorkflowRule wr on w.WorkflowID = wr.WorkflowID
			LEFT JOIN ExpenseType et on w.ExpenseTypeID = et.ExpenseTypeID
			INNER JOIN WorkflowGroup wg on wr.ApprovalWorkflowGroupID = wg.WorkflowGroupID
		WHERE w.AccountID = @accountID
			AND wr.IsDeleted = 0
		ORDER BY et.Name, w.WorkflowType, w.Name, wr.GroupOrderBy

	INSERT INTO #WorkflowRuleItems
		SELECT
			#w.WorkflowRuleID,
			wri.WorkflowRuleItemID,
			wr.RuleIsAnded,
			wri.MinimumThreshold,
			wri.MaximumThreshold,
			wri.[Type],
			wri.BudgetOverAmount
		FROM #Workflows #w
			INNER JOIN WorkflowRule wr on #w.WorkflowRuleID = wr.WorkflowRuleID
			INNER JOIN WorkflowRuleItem wri on #w.WorkflowRuleID = wri.WorkflowRuleID


	SELECT * FROM #Workflows

	SELECT * FROM #WorkflowRuleItems

END
GO
