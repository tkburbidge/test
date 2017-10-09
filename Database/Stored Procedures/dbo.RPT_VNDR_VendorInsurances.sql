SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Jordan Betteridge
-- Create date: November 12, 2013
-- Description:	Gets each vendor insurance policy
-- =============================================
CREATE PROCEDURE [dbo].[RPT_VNDR_VendorInsurances] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@includeExpiredPolicies bit = null,
	@showInactiveVendors bit = null,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #VendorInsuranceData
	(
		VendorID uniqueidentifier not null,
		VendorName nvarchar(200) not null,
		--[Status] nvarchar(50) null,
		[Type] int not null,
		Provider nvarchar(250) null,
		PolicyNumber nvarchar(100) null,
		ContactName nvarchar(100) null,
		ContactPhone nvarchar(100) null,
		ContactEmail nvarchar(256) null,
		ExpirationDate date not null,
		CoverageAmount money null
	)
	
	INSERT INTO #VendorInsuranceData
		SELECT	DISTINCT 
				v.VendorID,
				v.CompanyName AS 'VendorName',
				vi.[Type],
				vi.Provider,
				vi.PolicyNumber,
				vi.ContactName,
				vi.ContactPhoneNumber AS 'ContactPhone',
				vi.ContactEmail,
				vi.ExpirationDate,
				vi.Coverage AS 'CoverageAmount'
			FROM VendorInsurance vi
				INNER JOIN Vendor v ON vi.VendorID = v.VendorID
				INNER JOIN VendorProperty vp ON vi.VendorID = vp.VendorID
			WHERE vp.PropertyID IN (SELECT Value FROM @propertyIDs)
				AND (@includeExpiredPolicies = 1 OR vi.ExpirationDate >= @date)
				AND (@showInactiveVendors = 1 OR v.IsActive = 1)

	
	SELECT * FROM #VendorInsuranceData 
	ORDER BY 
		VendorName
END
GO
