CREATE TABLE [dbo].[GLAccount]
(
[GLAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[GLAccountType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Number] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Statistic] [nvarchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ParentGLAccountID] [uniqueidentifier] NULL,
[SummaryParent] [bit] NOT NULL,
[IsActive] [bit] NOT NULL CONSTRAINT [DF__GLAccount__IsAct__22B5168E] DEFAULT ((1)),
[DefaultExpenseTypeID] [uniqueidentifier] NULL,
[IsReplacementReserve] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[GLAccount] ADD CONSTRAINT [PK_GLAccount] PRIMARY KEY CLUSTERED  ([GLAccountID], [AccountID]) ON [PRIMARY]
GO
