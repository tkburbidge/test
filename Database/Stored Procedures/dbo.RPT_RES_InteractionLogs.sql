SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Phillip Lundquist
-- Create date: April 6, 2012
-- Description:	Generates the data for the Interaction Logs Report



-- Update:		August 3, 2015
-- Author:		Joshua Grigg
-- Description:	Order by date and then date created descending
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_InteractionLogs] 
	-- Add the parameters for the stored procedure here 
	@leaseID UniqueIdentifier = null, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT 
			pn.Location AS 'Unit',
			p.FirstName + ' ' + P.LastName AS 'Resident',
			pn.ContactType AS 'ContactType',
			pn.InteractionType AS 'InteractionType',
			pn.[Date] AS 'Date',
			pn.[Description] AS 'Description',
			pn.Note AS 'Note',
			e.FirstName + ' ' + e.LastName AS 'Employee',
			l.LeaseStartDate AS 'LeaseStartDate',
			l.LeaseEndDate AS 'LeaseEndDate'				  
		FROM 
			PersonLease pl	
			INNER JOIN Person p on pl.PersonID = p.PersonID
			INNER JOIN PersonNote pn on P.PersonID = pn.PersonID
			--INNER JOIN PersonTypeProperty ptp on pn.CreatedByPersonTypePropertyID = ptp.PersonTypePropertyID
			--INNER JOIN PersonType pt on ptp.PersonTypeID = pt.PersonTypeID
			--INNER JOIN Person e on pt.PersonID = e.PersonID
			INNER JOIN Person e ON pn.CreatedByPersonID = e.PersonID	
			INNER JOIN Lease l on pl.LeaseID = l.LeaseID	
			LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE 
			pl.LeaseID = @leaseID
			--AND pn.[Date] >= @startDate
			--AND pn.[Date] <= @endDate
			AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
		ORDER BY pn.[Date] DESC, pn.[DateCreated] DESC
END




GO
