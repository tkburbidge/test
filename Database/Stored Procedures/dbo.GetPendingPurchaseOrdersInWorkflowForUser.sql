SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






-- =============================================
-- Author:		Joshua Grigg
-- Create date: July 10, 2015
-- Description:	Gets Purchase Orders pending User's approval
-- =============================================
CREATE PROCEDURE [dbo].[GetPendingPurchaseOrdersInWorkflowForUser] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@personID uniqueidentifier = null,
	@propertyIDs GuidCollection READONLY
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @userWorkflowGroupID uniqueidentifier
	
	
	SET @userWorkflowGroupID = (SELECT WorkflowGroupID FROM [User] WHERE PersonID = @personID)
	
	
	CREATE TABLE #UnapprovedWorkflowRuleApprovals
	(
		ObjectID uniqueidentifier,
		WorkflowRuleApprovalID uniqueidentifier,
		ApprovalWorkflowGroupID uniqueidentifier,
		GroupOrderBy int,
		PropertyID uniqueidentifier,
		PurchaseOrderID uniqueidentifier
	)
	
	INSERT INTO #UnapprovedWorkflowRuleApprovals
	SELECT
		wra.ObjectID,
		wra.WorkflowRuleApprovalID,
		wr.ApprovalWorkflowGroupID,
		wr.GroupOrderBy,
		poli.PropertyID,
		poli.PurchaseOrderID
	FROM WorkflowRuleApproval wra
		INNER JOIN WorkflowRule wr ON wra.WorkflowRuleID = wr.WorkflowRuleID
		INNER JOIN PurchaseOrderLineItem poli ON wra.ObjectID = poli.PurchaseOrderLineItemID
	WHERE wr.AccountID = @accountID 
	  AND wra.[Status] IS NULL
	  AND wra.ObjectType = 'PurchaseOrder' 
	
	SELECT DISTINCT
		po.[Date] as 'Date',
		po.[Description] as 'Description',
		po.PurchaseOrderID as 'PurchaseOrderID',
		po.Number as 'Number',
		poin.[Status] as 'Status',
		po.Total as 'Total',
		v.CompanyName as 'Vendor',
		v.VendorID as 'VendorID',
		STUFF((SELECT DISTINCT ', ' + prop.Abbreviation
						 FROM #UnapprovedWorkflowRuleApprovals #uwra2
						 INNER JOIN Property prop on #uwra2.PropertyID = prop.PropertyID
						 WHERE #uwra2.PurchaseOrderID = po.PurchaseOrderID		   
						 FOR XML PATH ('')), 1, 2, '') AS 'PropertyAbbreviationsList'
	FROM #UnapprovedWorkflowRuleApprovals #uwra
		
		INNER JOIN( --Get the ObjectIDs (POLineItemIDS) for the WorkflowRuleApprovals that are next in Workflow
				/*
				SELECT ObjectID,  
					   MIN(GroupOrderBy) GroupOrderBy
				FROM #UnapprovedWorkflowRuleApprovals
				GROUP BY ObjectID
				*/
				SELECT #uwra3.*
					FROM #UnapprovedWorkflowRuleApprovals #uwra3
					LEFT JOIN #UnapprovedWorkflowRuleApprovals #uwra4 ON(#uwra3.ObjectID = #uwra4.ObjectID AND #uwra3.GroupOrderBy > #uwra4.GroupOrderBy)
					WHERE #uwra4.WorkflowRuleApprovalID IS NULL
		) PendingGroup ON --PendingGroup.ObjectID = #uwra.ObjectID 
						  PendingGroup.WorkflowRuleApprovalID = #uwra.WorkflowRuleApprovalID
					  AND PendingGroup.GroupOrderBy = #uwra.GroupOrderBy 
		INNER JOIN PurchaseOrderLineItem poli ON #uwra.ObjectID = poli.PurchaseOrderLineItemID
		INNER JOIN PurchaseOrder po ON poli.PurchaseOrderID = po.PurchaseOrderID
		INNER JOIN (  --Get the most recent status for Purchase Orders
			SELECT poin1.* 
					FROM POInvoiceNote poin1
					LEFT JOIN POInvoiceNote poin2 ON (poin1.ObjectID = poin2.ObjectID AND poin1.[Timestamp] < poin2.[Timestamp])
					WHERE poin1.AccountID = @accountID 
					  AND poin2.POInvoiceNoteID IS NULL
		) poin ON poin.ObjectID = po.PurchaseOrderID
		INNER JOIN Vendor v ON po.VendorID = v.VendorID
	WHERE poin.[Status] = 'Pending Approval' 
	  AND po.AccountID = @accountID 
	  AND #uwra.ApprovalWorkflowGroupID = @userWorkflowGroupID
	  AND poli.PropertyID IN (SELECT Value FROM @propertyIDs)

END






GO
