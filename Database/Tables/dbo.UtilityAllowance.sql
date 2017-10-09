CREATE TABLE [dbo].[UtilityAllowance]
(
[UtilityAllowanceID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DateChanged] [date] NOT NULL,
[Amount] [int] NOT NULL,
[Notes] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NOT NULL,
[GrossRentChangeID] [uniqueidentifier] NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UtilityAllowance] ADD CONSTRAINT [PK_UtilityAllowance] PRIMARY KEY CLUSTERED  ([UtilityAllowanceID], [AccountID]) ON [PRIMARY]
GO
