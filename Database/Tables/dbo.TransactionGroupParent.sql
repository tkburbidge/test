CREATE TABLE [dbo].[TransactionGroupParent]
(
[TransactionGroupParentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TransactionGroupID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Date] [date] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[AccountingBasis] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ReversedByTransactionGroupID] [uniqueidentifier] NULL,
[ReversesTransactionGroupID] [uniqueidentifier] NULL,
[AccountingBookID] [uniqueidentifier] NULL,
[ApprovalStatus] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TransactionGroupParent] ADD CONSTRAINT [PK_TransactionGroupParent] PRIMARY KEY CLUSTERED  ([TransactionGroupParentID], [AccountID]) ON [PRIMARY]
GO
