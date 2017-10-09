SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Craig Perkins
-- Create date: 04/17/2013
-- Description:	Updates dates of leases associated with a lease term
-- =============================================
CREATE PROCEDURE [dbo].[UpdateLeaseTermLeases]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@leaseTermID uniqueidentifier,
 	-- Other properties that need to be updated
	@startDate date,
	@endDate date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	UPDATE [Lease]
	  SET 
		-- update Lease table fields to the parameters passed in
		LeaseStartDate = @startDate,
		LeaseEndDate = @endDate
	WHERE AccountID = @accountID	
		AND LeaseTermID = @leaseTermID
END
GO
