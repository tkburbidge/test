CREATE TYPE [dbo].[BudgetImport] AS TABLE
(
[GLAccountID] [uniqueidentifier] NOT NULL,
[Month1Amount] [money] NOT NULL,
[Month2Amount] [money] NOT NULL,
[Month3Amount] [money] NOT NULL,
[Month4Amount] [money] NOT NULL,
[Month5Amount] [money] NOT NULL,
[Month6Amount] [money] NOT NULL,
[Month7Amount] [money] NOT NULL,
[Month8Amount] [money] NOT NULL,
[Month9Amount] [money] NOT NULL,
[Month10Amount] [money] NOT NULL,
[Month11Amount] [money] NOT NULL,
[Month12Amount] [money] NOT NULL
)
GO
