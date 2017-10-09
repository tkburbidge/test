CREATE TABLE [dbo].[WaitListIncomeLevel]
(
[WaitListIncomeLevelID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[AmiPercent] [int] NULL,
[Label] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [int] NOT NULL,
[IsIncomeLevel] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitListIncomeLevel] ADD CONSTRAINT [PK_WaitListIncomeLevel] PRIMARY KEY CLUSTERED  ([WaitListIncomeLevelID], [AccountID]) ON [PRIMARY]
GO
