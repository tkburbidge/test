SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: May 31, 2012
-- Description:	Gets prospects matching the given first and last name
-- =============================================
CREATE PROCEDURE [dbo].[GetMatchingProspects]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier,
	@firstName nvarchar(1000),
	@lastName nvarchar(1000),
	@email nvarchar(1000),
	@phone1 nvarchar(1000),
	@phone2 nvarchar(1000),
	@phone3 nvarchar(1000)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET @phone1 = dbo.[RemoveNonNumericCharacters](@phone1)
	SET @phone2 = dbo.[RemoveNonNumericCharacters](@phone2)
	SET @phone3 = dbo.[RemoveNonNumericCharacters](@phone3)

	SELECT * FROM
	   (SELECT p.PersonID AS 'MainProspectPersonID',
			   p.Email AS 'Email',
			   p.Phone1 AS 'Phone1',
			   p.Phone2 AS 'Phone2',
			   p.Phone3 AS 'Phone3',
			   null AS 'PersonID',
			   p.PreferredName + ' ' + p.LastName AS 'Name',
			   ptp.PropertyID,
			   (SELECT TOP 1 [Date]
				FROM PersonNote pn
				--INNER JOIN PersonTypeProperty ptp1 ON ptp1.PersonTypePropertyID = pn.CreatedByPersonTypePropertyID
				WHERE pn.PersonID = p.PersonID
					AND pn.PersonType = 'Prospect'
					AND pn.PropertyID = @propertyID
				ORDER BY pn.[Date] DESC, pn.DateCreated DESC) AS 'LastContactDate'
		FROM Person p
		INNER JOIN Prospect pro ON p.PersonID = pro.PersonID
		INNER JOIN PersonType pt ON pt.PersonID = p.PersonID AND pt.[Type] = 'Prospect'
		INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID
		WHERE p.AccountID = @accountID
			AND ptp.PropertyID = @propertyID
			AND (((p.FirstName = @firstName OR p.PreferredName = @firstName)
				AND p.LastName = @lastName)
				OR (p.Email <> '' AND p.Email = @email)
				OR (@phone1 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone1) = @phone1)
				OR (@phone2 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone1) = @phone2)
				OR (@phone3 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone1) = @phone3)
				OR (@phone1 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone2) = @phone1)
				OR (@phone2 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone2) = @phone2)
				OR (@phone3 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone2) = @phone3)
				OR (@phone1 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone3) = @phone1)
				OR (@phone2 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone3) = @phone2)
				OR (@phone3 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone3) = @phone3))

		UNION
		
		SELECT pro.PersonID AS 'MainProspectPersonID',
			   p.Email AS 'Email',
			   p.Phone1 AS 'Phone1',
			   p.Phone2 AS 'Phone2',
			   p.Phone3 AS 'Phone3',
			   p.PersonID AS 'PersonID',
			   p.PreferredName + ' ' + p.LastName AS 'Name',
			   ptp.PropertyID,
			   (SELECT TOP 1 [Date]
				FROM PersonNote pn
				--INNER JOIN PersonTypeProperty ptp1 ON ptp1.PersonTypePropertyID = pn.CreatedByPersonTypePropertyID
				WHERE pn.PersonID = pro.PersonID
					AND pn.PersonType = 'Prospect'
					AND pn.PropertyID = @propertyID
				ORDER BY pn.[Date] DESC, pn.DateCreated DESC) AS 'LastContactDate'
		FROM Person p
		INNER JOIN ProspectRoommate pr ON pr.PersonID = p.PersonID
		INNER JOIN Prospect pro ON pro.ProspectID = pr.ProspectID
		INNER JOIN PersonType pt ON pt.PersonID = p.PersonID AND pt.[Type] = 'Prospect'
		INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID
		WHERE p.AccountID = @accountID
			AND ptp.PropertyID = @propertyID
			AND (((p.FirstName = @firstName OR p.PreferredName = @firstName)
				AND p.LastName = @lastName)
				OR (p.Email <> '' AND p.Email = @email)
				OR (@phone1 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone1) = @phone1)
				OR (@phone2 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone1) = @phone2)
				OR (@phone3 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone1) = @phone3)
				OR (@phone1 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone2) = @phone1)
				OR (@phone2 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone2) = @phone2)
				OR (@phone3 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone2) = @phone3)
				OR (@phone1 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone3) = @phone1)
				OR (@phone2 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone3) = @phone2)
				OR (@phone3 <> '' AND dbo.[RemoveNonNumericCharacters](p.Phone3) = @phone3)))	Prospects
	ORDER BY Name	
END


GO
