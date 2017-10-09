CREATE TABLE [dbo].[TransactionGroupParentTemplate]
(
[TransactionGroupParentTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AccountingBookID] [uniqueidentifier] NULL,
[IsEliminationEntry] [bit] NOT NULL,
[RecurringItemID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TransactionGroupParentTemplate] ADD CONSTRAINT [PK_TransactionGroupParentTemplate] PRIMARY KEY CLUSTERED  ([TransactionGroupParentTemplateID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TransactionGroupParentTemplate] WITH NOCHECK ADD CONSTRAINT [FK_TransactionGroupParentTemplate_RecurringItem] FOREIGN KEY ([RecurringItemID], [AccountID]) REFERENCES [dbo].[RecurringItem] ([RecurringItemID], [AccountID])
GO
ALTER TABLE [dbo].[TransactionGroupParentTemplate] NOCHECK CONSTRAINT [FK_TransactionGroupParentTemplate_RecurringItem]
GO
