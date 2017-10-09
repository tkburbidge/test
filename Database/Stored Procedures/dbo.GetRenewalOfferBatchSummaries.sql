SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetRenewalOfferBatchSummaries] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT
		rob.RenewalOfferBatchID AS 'RenewalOfferBatchID',
		COUNT(RenewalOfferID) AS 'OfferCount',
		MinExpirationDate AS 'MinExpirationDate',
		MaxExpirationDate AS 'MaxExpirationDate',
		SUM(CASE WHEN [Status] = 'Sent' THEN 1 ELSE 0 END) AS 'OffersSentCount', 
		SUM(CASE WHEN [Status] = 'Accepted' THEN 1 ELSE 0 END) AS 'OffersAcceptedCount',
		CASE WHEN ValidRangeFixedEnd IS NULL THEN DATEADD(day, -ValidRangeRelativeEnd, MaxExpirationDate)
			 ELSE ValidRangeFixedEnd END AS 'OfferExpirationDate'
	FROM RenewalOfferBatch rob
		LEFT JOIN RenewalOffer ro on rob.RenewalOfferBatchID = ro.RenewalOfferBatchID
	WHERE rob.AccountID = @accountID
	  AND rob.PropertyID = @propertyID
	GROUP BY rob.RenewalOfferBatchID, rob.ValidRangeFixedEnd, rob.MinExpirationDate, rob.MaxExpirationDate, rob.ValidRangeRelativeEnd
END
GO
