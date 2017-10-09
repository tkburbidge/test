CREATE TABLE [dbo].[PropertyGroupProperty]
(
[PropertyGroupPropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyGroupID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyGroupProperty] ADD CONSTRAINT [PK_PropertyGroupProperty] PRIMARY KEY CLUSTERED  ([PropertyGroupPropertyID], [AccountID]) ON [PRIMARY]
GO
