SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: Jan 8, 2012
-- Description:	Gets the chart of accounts in a hierarchial
--			    manner
-- =============================================
CREATE FUNCTION [dbo].[GetChartOfAccountsByAlternate]
(
	@accountID bigint,
	@glAccountTypes StringCollection READONLY,
	@alternateChartOfAccountsID uniqueidentifier
)
RETURNS 
@coa TABLE 
(
	-- Add the column definitions for the TABLE variable here
	GLAccountID uniqueidentifier NOT NULL,
    Number nvarchar(15) NOT NULL,
    Name nvarchar(200) NOT NULL, 
    [Description] nvarchar(500) NULL,
    GLAccountType nvarchar(50) NOT NULL,
    ParentGLAccountID uniqueidentifier NULL,
    Depth int NOT NULL,
    IsLeaf bit NOT NULL,
    SummaryParent bit NOT NULL,
    [OrderByPath] nvarchar(max) NOT NULL,
    [Path]  nvarchar(max) NOT NULL,
    SummaryParentPath nvarchar(max)
)
AS
BEGIN
 --   WITH ChartOfAccounts AS
	--(
	--	-- Base Case
	--	SELECT
	--		gl.GLAccountID, 
	--		gl.Number, 
	--		gl.Name, 
	--		gl.[Description],
	--		gl.GLAccountType,
	--		gl.ParentGLAccountID, 			
	--		0 AS Depth,
	--		1 AS IsLeaf,
	--		gl.SummaryParent,
	--		CAST(('!#' + RIGHT('0000000000' + gl.Number, 10)) AS nvarchar(max)) AS [OrderByPath],
	--		CAST(('!#' + gl.Number + ' ' + gl.Name) AS nvarchar(max)) AS [Path],
	--		'!#' + CAST(gl.SummaryParent AS nvarchar(max)) AS SummaryParentPath
	--		--'' AS varchar(50)) AS Prefix
	--	FROM GLAccount gl
	--		INNER JOIN GLAccountAlternateGLAccount glagl ON glagl.GLAccountID = gl.GLAccountID
	--		INNER JOIN AlternateGLAccount agl ON agl.AlternateGLAccountID = glagl.AlternateGLAccountID AND agl.AlternateChartOfAccountsID = @alternateChartOfAccountsID
	--	WHERE agl.ParentAlternateGLAccountID IS NULL
	--	  AND agl.AccountID = @accountID
	--	  AND (((SELECT COUNT(*) FROM @glAccountTypes) = 0) OR (agl.GLAccountType IN (SELECT Value FROM @glAccountTypes)))
		  
	--	UNION ALL
		
	--	-- Recursive Case
	--	SELECT
	--		gl.GLAccountID, 
	--		gl.Number, 
	--		gl.Name,
	--		gl.[Description],
	--		gl.GLAccountType,
	--		gl.ParentGLAccountID, 
	--		1 + Depth AS Depth,
	--		1 AS IsLeaf,
	--		gl.SummaryParent,
	--		(coa.[OrderByPath] + '!#' + RIGHT('0000000000' + gl.Number, 10)) AS [OrderByPath],
	--		(coa.[Path] + '!#' + gl.Number + ' ' + gl.Name) AS [Path],
	--		(coa.SummaryParentPath + '!#' + CAST(gl.SummaryParent AS nvarchar(max))) AS SummaryParentPath
	--		--CAST(coa.Prefix + ' ' AS varchar(50))
	--	FROM ChartOfAccounts coa
	--	INNER JOIN GLAccount gl    
	--		ON gl.ParentGLAccountID = coa.GLAccountID
	--	WHERE AccountID = @accountID
	--)
	DECLARE @empty StringCollection
	INSERT INTO @coa SELECT GLAccountID, 
							Number, 
							Name, 
							[Description], 
							GLAccountType, 
							ParentGLAccountID, 
							Depth, 
							IsLeaf,
							SummaryParent,							
							OrderByPath, 
							[Path],
							SummaryParentPath
					 FROM GetChartOfAccounts(@accountID, @empty)
					 ORDER BY [OrderByPath]
	
	UPDATE @coa SET IsLeaf = 0 WHERE GLAccountID IN (SELECT ParentGLAccountID FROM @coa)

	-- Get rid of unmapped accounts
	DELETE coa
		FROM @coa coa
		WHERE coa.GLAccountID NOT IN (SELECT glagl.GLAccountID 
									  FROM GLAccountAlternateGLAccount glagl 
										INNER JOIN AlternateGLAccount agl ON agl.AlternateGLAccountID = glagl.AlternateGLAccountID AND agl.AlternateChartOfAccountsID = @alternateChartOfAccountsID)

	-- Get rid of GL Accounts that are not of the type passed in
	IF ((SELECT COUNT(*) FROM @glAccountTypes) > 0)
	BEGIN
		DELETE coa 
			FROM @coa coa			
			INNER JOIN GLAccountAlternateGLAccount glagl ON glagl.GLAccountID = coa.GLAccountID
			INNER JOIN AlternateGLAccount agl ON agl.AlternateGLAccountID = glagl.AlternateGLAccountID AND agl.AlternateChartOfAccountsID = @alternateChartOfAccountsID
		WHERE agl.GLAccountType NOT IN (SELECT Value FROM @glAccountTypes)
	END
	
	RETURN 
END




GO
