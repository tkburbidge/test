CREATE TABLE [dbo].[IntercompanySetting]
(
[IntercompanySettingID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SourcePropertyID] [uniqueidentifier] NOT NULL,
[DestinationPropertyID] [uniqueidentifier] NOT NULL,
[DueToGLAccountID] [uniqueidentifier] NOT NULL,
[DueFromGLAccountID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntercompanySetting] ADD CONSTRAINT [PK_IntercompanySetting] PRIMARY KEY CLUSTERED  ([IntercompanySettingID], [AccountID]) ON [PRIMARY]
GO
