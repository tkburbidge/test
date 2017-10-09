SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Forrest Tait
-- Create date: Jan 13, 2016
-- Description:	This script will copy all vendor addresses to the payment address.
-- =============================================

CREATE PROCEDURE [dbo].[CopyVendorAddresses]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0
AS
BEGIN
	UPDATE pa
	SET pa.StreetAddress = ga.StreetAddress,
		pa.City = ga.City,
		pa.[State] = ga.[State],
		pa.Zip = ga.[Zip],
		pa.Country = ga.[Country]
	FROM [Address] pa
	INNER JOIN VendorPerson vpp ON vpp.PersonID = pa.ObjectID
	INNER JOIN VendorPerson vpg ON vpg.VendorID = vpp.VendorID AND vpg.VendorPersonID <> vpp.VendorPersonID
	INNER JOIN [Address] ga ON ga.ObjectID = vpg.PersonID
	WHERE pa.AddressType = 'VendorPayment'
	AND pa.AccountID = @accountID
	AND ga.AccountID = @accountID
	and (pa.StreetAddress is null OR pa.StreetAddress = '')	
END
GO
