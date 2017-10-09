CREATE TABLE [dbo].[LedgerLineItemGroup]
(
[LedgerLineItemGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LedgerLineItemGroup] ADD CONSTRAINT [PK_LedgerLineItemGroup] PRIMARY KEY CLUSTERED  ([LedgerLineItemGroupID], [AccountID]) ON [PRIMARY]
GO
