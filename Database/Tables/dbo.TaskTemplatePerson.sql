CREATE TABLE [dbo].[TaskTemplatePerson]
(
[TaskTemplatePersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TaskTemplateID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[IsCarbonCopy] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TaskTemplatePerson] ADD CONSTRAINT [PK_TaskTemplatePerson] PRIMARY KEY CLUSTERED  ([TaskTemplatePersonID], [AccountID]) ON [PRIMARY]
GO
