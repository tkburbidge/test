CREATE TABLE [dbo].[AffordableExpenseAmount]
(
[AffordableExpenseAmountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AffordableExpenseID] [uniqueidentifier] NOT NULL,
[EffectiveDate] [datetime] NOT NULL,
[Amount] [money] NOT NULL,
[Period] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateVerified] [datetime] NULL,
[VerifiedByPersonID] [uniqueidentifier] NULL,
[VerificationSources] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableExpenseAmount] ADD CONSTRAINT [PK_AffordableExpenseAmountID] PRIMARY KEY CLUSTERED  ([AffordableExpenseAmountID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableExpenseAmount] ADD CONSTRAINT [FK_AffordableExpenseAmount_AffordableExpense] FOREIGN KEY ([AffordableExpenseID], [AccountID]) REFERENCES [dbo].[AffordableExpense] ([AffordableExpenseID], [AccountID])
GO
