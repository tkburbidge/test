CREATE TABLE [dbo].[BankAccountReconciliation]
(
[BankAccountReconciliationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BankAccountID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[StatementDate] [date] NOT NULL,
[DateStarted] [date] NOT NULL,
[DateCompleted] [date] NULL,
[Difference] [money] NULL,
[EndingBalance] [money] NULL,
[BankFileContent] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DocumentID] [uniqueidentifier] NULL,
[DateCreated] [datetime] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[BankAccountReconciliation] ADD CONSTRAINT [PK_BankAccountReconciliation] PRIMARY KEY CLUSTERED  ([BankAccountReconciliationID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BankAccountReconciliation] WITH NOCHECK ADD CONSTRAINT [FK_BankAccountReconciliation_BankAccount] FOREIGN KEY ([BankAccountID], [AccountID]) REFERENCES [dbo].[BankAccount] ([BankAccountID], [AccountID])
GO
ALTER TABLE [dbo].[BankAccountReconciliation] NOCHECK CONSTRAINT [FK_BankAccountReconciliation_BankAccount]
GO
