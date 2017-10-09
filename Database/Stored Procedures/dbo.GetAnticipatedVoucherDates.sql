SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetAnticipatedVoucherDates] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@certificationIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT Value AS 'CertificationID', dbo.FirstHUDMonthBillable(Value, @accountID, 1) AS 'AnticipatedVoucherDate'
	FROM @certificationIDs

END
GO
