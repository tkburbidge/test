SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: 9/6/2013
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[ApplyLeaseDatesToLeaseLedgerItems] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@leaseID uniqueIdentifier
AS
DECLARE @startDate DATE
DECLARE @endDate DATE
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SELECT @startDate = l.LeaseStartDate, @endDate = l.LeaseEndDate
	FROM Lease l
	WHERE l.AccountID = @accountID and l.LeaseID = @leaseID
	
    UPDATE lli 
    SET  StartDate = @startDate, EndDate = @endDate
		FROM LeaseLedgerItem lli
			INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
			INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID    
		WHERE lli.AccountID = @accountID 
			AND lli.LeaseID = @leaseID
			AND lit.IsDeposit = 0
END
GO
