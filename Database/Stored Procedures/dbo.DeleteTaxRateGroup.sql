SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 12, 2012
-- Description:	Marks a TaxRateGroup as Obsolete, checks each associated TaxRate and marks 
--				those that aren't associated with any other TaxRateGroups as Obsolete too.
-- =============================================
CREATE PROCEDURE [dbo].[DeleteTaxRateGroup] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@taxRateGroupID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE tr SET tr.IsObsolete = 1
		FROM TaxRateGroupTaxRate trgtr
			INNER JOIN TaxRateGroup trg ON trgtr.TaxRateGroupID = trg.TaxRateGroupID AND trgtr.TaxRateGroupID = @taxRateGroupID
			INNER JOIN TaxRate tr ON trgtr.TaxRateID = tr.TaxRateID
			LEFT JOIN TaxRateGroupTaxRate trgtrOther ON tr.TaxRateID = trgtrOther.TaxRateID AND trgtrOther.TaxRateGroupID <> @taxRateGroupID
		WHERE trgtrOther.TaxRateGroupID IS NULL
		
	UPDATE TaxRateGroup SET IsObsolete = 1
		WHERE TaxRateGroupID = @taxRateGroupID
	
END
GO
