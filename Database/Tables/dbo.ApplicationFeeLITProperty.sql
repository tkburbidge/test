CREATE TABLE [dbo].[ApplicationFeeLITProperty]
(
[ApplicationFeeLITPropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Amount] [money] NOT NULL,
[OrderBy] [int] NOT NULL,
[Description] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PerUnit] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicationFeeLITProperty] ADD CONSTRAINT [PK_ApplicationFeeLITProperty] PRIMARY KEY CLUSTERED  ([ApplicationFeeLITPropertyID], [AccountID]) ON [PRIMARY]
GO
