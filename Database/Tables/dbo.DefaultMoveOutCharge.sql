CREATE TABLE [dbo].[DefaultMoveOutCharge]
(
[DefaultMoveOutChargeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NULL,
[Description] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Amount] [money] NULL,
[Notes] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DefaultMoveOutCharge] ADD CONSTRAINT [PK_DefaultMoveOutCharge] PRIMARY KEY CLUSTERED  ([DefaultMoveOutChargeID], [AccountID]) ON [PRIMARY]
GO
