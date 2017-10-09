SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Art Olsen
-- Create date: 12/13/13
-- Description:	Get all waived applicant charges for a (group) of property(s)
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_GetWaivedApplicantCharges] 
	-- Add the parameters for the stored procedure here
	@propertyIDs		GuidCollection readonly, 
	@dateFrom			DATE,
	@dateTo				DATE,
	@accountID			BIGINT,
	@interactionType	NVARCHAR(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT	p.Name,
			pn.DateCreated as [Date],
			pn.Location as Unit,
			per.PreferredName + ' ' + per.LastName as Resident,
			pn.[Description] as ChargeDescription,
			perb.PreferredName + ' ' + perb.LastName as WaivedBy,
			pn.Note as WaiveNotes,
			l.LeaseStartDate,
			l.LeaseEndDate,
			l.LeaseID
			
	FROM	PersonNote pn
			INNER JOIN Person per on pn.PersonID = per.PersonID 
			--INNER JOIN PersonTypeProperty ptp on pn.CreatedByPersonTypePropertyID = ptp.PersonTypePropertyID
			--INNER JOIN PersonType pt on pt.PersonTypeID = ptp.PersonTypeID
			--INNER JOIN Property p on p.PropertyID = ptp.PropertyID
			INNER JOIN Property p on pn.PropertyID = p.PropertyID
			INNER JOIN Lease l on pn.ObjectID = l.leaseID
			--INNER JOIN Person perb on perb.PersonID = pt.PersonID
			INNER JOIN Person perb on pn.CreatedByPersonID = perb.PersonID
			
	WHERE	p.PropertyID in (select value from @propertyIDs)
			AND		pn.DateCreated >= @dateFrom
			AND		pn.DateCreated <= @dateTo
			AND		@accountID = pn.AccountID
			AND		pn.InteractionType = @interactionType
		
END
GO
