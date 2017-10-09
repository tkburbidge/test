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
CREATE FUNCTION [dbo].[GetChartOfAccounts]
(
	@accountID bigint,
	@glAccountTypes StringCollection READONLY
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
    WITH ChartOfAccounts AS
	(
		-- Base Case
		SELECT
			GLAccountID, 
			Number, 
			Name, 
			[Description],
			GLAccountType,
			ParentGLAccountID, 			
			0 AS Depth,
			1 AS IsLeaf,
			SummaryParent,
			CAST(('!#' + RIGHT('000000000000000' + Number, 15)) AS nvarchar(max)) AS [OrderByPath],
			CAST(('!#' + Number + ' ' + Name) AS nvarchar(max)) AS [Path],
			'!#' + CAST(SummaryParent AS nvarchar(max)) AS SummaryParentPath
			--'' AS varchar(50)) AS Prefix
		FROM GLAccount
		WHERE ParentGLAccountID IS NULL
		  AND AccountID = @accountID
		  AND (((SELECT COUNT(*) FROM @glAccountTypes) = 0) OR (GLAccountType IN (SELECT Value FROM @glAccountTypes)))

		UNION ALL
		
		-- Recursive Case
		SELECT
			gl.GLAccountID, 
			gl.Number, 
			gl.Name,
			gl.[Description],
			gl.GLAccountType,
			gl.ParentGLAccountID, 
			1 + Depth AS Depth,
			1 AS IsLeaf,
			gl.SummaryParent,
			(coa.[OrderByPath] + '!#' + RIGHT('000000000000000' + gl.Number, 15)) AS [OrderByPath],
			(coa.[Path] + '!#' + gl.Number + ' ' + gl.Name) AS [Path],
			(coa.SummaryParentPath + '!#' + CAST(gl.SummaryParent AS nvarchar(max))) AS SummaryParentPath
			--CAST(coa.Prefix + ' ' AS varchar(50))
		FROM ChartOfAccounts coa
		INNER JOIN GLAccount gl    
			ON gl.ParentGLAccountID = coa.GLAccountID
		WHERE gl.AccountID = @accountID
	)
	
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
					 FROM ChartOfAccounts
					 ORDER BY [OrderByPath]
					 
	UPDATE @coa SET IsLeaf = 0 WHERE GLAccountID IN (SELECT ParentGLAccountID FROM @coa)
	
	RETURN 
END
GO
