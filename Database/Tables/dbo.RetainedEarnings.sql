CREATE TABLE [dbo].[RetainedEarnings]
(
[RetainedEarningsID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Year] [int] NOT NULL,
[CashTransactionGroupID] [uniqueidentifier] NOT NULL,
[AccrualTransactionGroupID] [uniqueidentifier] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[PostingPersonID] [uniqueidentifier] NOT NULL,
[IsComplete] [bit] NOT NULL,
[AccountingBookID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RetainedEarnings] ADD CONSTRAINT [PK_RetainedEarnings] PRIMARY KEY CLUSTERED  ([RetainedEarningsID], [AccountID]) ON [PRIMARY]
GO
