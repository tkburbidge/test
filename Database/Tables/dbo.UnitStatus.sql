CREATE TABLE [dbo].[UnitStatus]
(
[UnitStatusID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[StatusLedgerItemTypeID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (248) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitStatus] ADD CONSTRAINT [PK_UnitStatus] PRIMARY KEY CLUSTERED  ([UnitStatusID], [AccountID]) ON [PRIMARY]
GO
