CREATE TABLE [dbo].[AccountingBook]
(
[AccountingBookID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsArchived] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AccountingBook] ADD CONSTRAINT [PK_AccountingBook] PRIMARY KEY CLUSTERED  ([AccountingBookID], [AccountID]) ON [PRIMARY]
GO
