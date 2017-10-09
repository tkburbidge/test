CREATE TABLE [dbo].[TaskTemplateProperty]
(
[TaskTemplatePropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TaskTemplateID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[IsCarbonCopy] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TaskTemplateProperty] ADD CONSTRAINT [PK_TaskTemplateProperty] PRIMARY KEY CLUSTERED  ([TaskTemplatePropertyID], [AccountID]) ON [PRIMARY]
GO
