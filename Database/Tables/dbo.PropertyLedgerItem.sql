CREATE TABLE [dbo].[PropertyLedgerItem]
(
[PropertyLedgerItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[LedgerItemID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyLedgerItem] ADD CONSTRAINT [PK_PropertyLedgerItem] PRIMARY KEY CLUSTERED  ([PropertyLedgerItemID], [AccountID]) ON [PRIMARY]
GO
