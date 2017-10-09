SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Craig Perkins
-- Create date: 03/06/2013
-- Description:	Merges two vendors together
-- =============================================
CREATE PROCEDURE [dbo].[MergeVendor] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@vendorID uniqueidentifier,
	@mergingVendorID uniqueidentifier
AS
BEGIN
	UPDATE [Invoice]				SET VendorID = @vendorID WHERE VendorID = @mergingVendorID AND AccountID = @accountID
	UPDATE [InvoiceTemplate]		SET VendorID = @vendorID WHERE VendorID = @mergingVendorID AND AccountID = @accountID
	UPDATE [PurchaseOrder]			SET VendorID = @vendorID WHERE VendorID = @mergingVendorID AND AccountID = @accountID	
	UPDATE [WorkOrder]				SET VendorID = @vendorID WHERE VendorID = @mergingVendorID AND AccountID = @accountID
	UPDATE [Payment]				SET ObjectID = @vendorID WHERE ObjectID = @mergingVendorID AND AccountID = @accountID AND ObjectType = 'Vendor'
	UPDATE [Document]				SET ObjectID = @vendorID WHERE ObjectID = @mergingVendorID AND AccountID = @accountID

	UPDATE Vendor SET IsActive = 0 WHERE VendorID = @mergingVendorID AND AccountID = @accountID
END
GO
