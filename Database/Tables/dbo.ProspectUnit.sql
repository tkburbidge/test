CREATE TABLE [dbo].[ProspectUnit]
(
[AccountID] [bigint] NOT NULL,
[ProspectID] [uniqueidentifier] NOT NULL,
[UnitID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProspectUnit] ADD CONSTRAINT [PK_ProspectUnit] PRIMARY KEY CLUSTERED  ([AccountID], [ProspectID], [UnitID]) ON [PRIMARY]
GO
