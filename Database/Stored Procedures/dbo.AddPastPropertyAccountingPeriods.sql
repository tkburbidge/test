SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 3, 2014
-- Description:	Adds PropertyAccountingPeriod records that happened a while ago
-- =============================================
CREATE PROCEDURE [dbo].[AddPastPropertyAccountingPeriods] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@startingAccountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	INSERT PropertyAccountingPeriod (PropertyAccountingPeriodID, AccountID, AccountingPeriodID, PropertyID, LeaseExpirationLimit, LeaseExpirationNotes, Closed, RecurringChargesPosted, LateFeesAccessed, StartDate, EndDate)
		SELECT NEWID(), @accountID, MissingPeriods.AccountingPeriodID, @propertyID, null, null, 0, 1, 0, MissingPeriods.StartDate, MissingPeriods.EndDate
			FROM
				(SELECT pap.PropertyAccountingPeriodID, ap.AccountingPeriodID, ap.StartDate, ap.EndDate
					FROM AccountingPeriod ap 
						LEFT JOIN PropertyAccountingPeriod pap ON ap.AccountingPeriodID = pap.AccountingPeriodID AND pap.PropertyID = @propertyID
					WHERE ap.EndDate >= (SELECT EndDate
											FROM AccountingPeriod
											WHERE AccountingPeriodID = @startingAccountingPeriodID)
					  AND ap.AccountID = @accountID) MissingPeriods
			  WHERE MissingPeriods.PropertyAccountingPeriodID IS NULL
END
GO
