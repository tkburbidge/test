SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 29, 2012
-- Description:	Generates the data for the UnleasedProspects Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_UnleasedProspects] 
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

	SELECT DISTINCT
			p.Name AS 'PropertyName',
			p.PropertyID AS 'PropertyID', 
			pnf.DateCreated AS 'FirstContact',
			pnl.DateCreated AS 'LastContact',
			pr.PreferredName + ' ' + pr.LastName AS 'Name',
			pr.PersonID AS 'PersonID',
			pr.Phone1 AS 'Phone', 
			pr.Phone1Type AS 'PhoneType',
			pr.Email AS 'Email',
			CASE
				WHEN (lcan.LeaseID IS NOT NULL) THEN CAST(1 AS BIT)
				ELSE CAST(0 AS BIT) END AS 'Cancelled'
		FROM Prospect pro
			INNER JOIN Person pr ON pro.PersonID = pr.PersonID
			INNER JOIN PersonNote pnf ON pnf.PersonNoteID = pro.FirstPersonNoteID		
			INNER JOIN PersonNote pnl ON pnl.PersonNoteID = pro.LastPersonNoteID		
			INNER JOIN Property p ON pnf.PropertyID = p.PropertyID			
			INNER JOIN Person pre ON pnf.CreatedByPersonID = pre.PersonID
			--INNER JOIN PersonNote pnl ON pnl.PersonNoteID = pro.LastPersonNoteID			
			LEFT JOIN PersonLease pl ON pr.PersonID = pl.PersonID					
			LEFT JOIN Lease lcan ON pl.LeaseID = lcan.LeaseID AND lcan.LeaseStatus IN ('Cancelled', 'Denied')	
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			AND (pl.PersonLeaseID IS NULL OR lcan.LeaseID IS NOT NULL)
			AND (((@accountingPeriodID IS NULL) AND (pnf.[Date] >= @startDate) AND (pnf.[Date] <= @endDate))
				OR ((@accountingPeriodID IS NOT NULL) AND (pnf.[Date] >= pap.StartDate) AND (pnf.[Date] <= pap.EndDate)))
END




GO
