CREATE TABLE [dbo].[AutoMakeReady]
(
[AutoMakeReadyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[AssignedToPersonID] [uniqueidentifier] NOT NULL,
[WorkOrderCategoryID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [tinyint] NOT NULL,
[Priority] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DaysToComplete] [tinyint] NOT NULL,
[Abbreviation] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Prepopulate] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AutoMakeReady] ADD CONSTRAINT [PK_AutoMakeReady] PRIMARY KEY CLUSTERED  ([AutoMakeReadyID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AutoMakeReady] WITH NOCHECK ADD CONSTRAINT [FK_AutoMakeReady_Property] FOREIGN KEY ([PropertyID], [AccountID]) REFERENCES [dbo].[Property] ([PropertyID], [AccountID])
GO
ALTER TABLE [dbo].[AutoMakeReady] NOCHECK CONSTRAINT [FK_AutoMakeReady_Property]
GO
