SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 9, 2013
-- Description:	Gets data for the Lost Prospects Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_LostProspects] 
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

    -- Insert statements for procedure here
	SELECT	p.Name AS 'PropertyName',
			p.PropertyID AS 'PropertyID',
			per.PersonID AS 'PersonID',
			pros.LostDate AS 'LostDate',
			per.PreferredName + ' ' + per.LastName AS 'Name',
			per.Phone1 AS 'Phone',
			ps.Name AS 'ProspectSource',
			respper.PreferredName + ' ' + respper.LastName AS 'LeasingAgent',
			pli.Name AS 'LostReason',
			pros.LostReasonNotes AS 'LostNotes'
		FROM Person per
			INNER JOIN PersonType pt ON per.PersonID = pt.PersonID AND pt.[Type] = 'Prospect'
			INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID AND ptp.PropertyID IN (SELECT Value FROM @propertyIDs)
			INNER JOIN Property p ON ptp.PropertyID = p.PropertyID
			INNER JOIN Prospect pros ON per.PersonID = pros.PersonID
			INNER JOIN PickListItem pli ON pros.LostReasonPickListItemID = pli.PickListItemID
			INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID AND pps.PropertyID IN (SELECT Value FROM @propertyIDs)
			INNER JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
			INNER JOIN PersonTypeProperty respptp ON pros.ResponsiblePersonTypePropertyID = respptp.PersonTypePropertyID
			INNER JOIN PersonType resppt ON respptp.PersonTypeID = resppt.PersonTypeID
			INNER JOIN Person respper ON resppt.PersonID = respper.PersonID
			LEFT JOIN PersonType ptRes ON per.PersonID = ptRes.PersonID AND ptRes.[Type] = 'Resident' AND (1 = (SELECT COUNT(PersonTypePropertyID) 
																													FROM PersonTypeProperty 
																													WHERE PropertyID = p.PropertyID
																													  AND PersonTypeID = ptRes.PersonTypeID))
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE (((@accountingPeriodID IS NULL) AND (pros.LostDate >= @startDate) AND (pros.LostDate <= @endDate))

			OR ((@accountingPeriodID IS NOT NULL) AND (pros.LostDate >= pap.StartDate) AND (pros.LostDate <= pap.EndDate)))
		  AND ptRes.PersonTypeID IS NULL
END

GO
