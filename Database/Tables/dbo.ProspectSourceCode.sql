CREATE TABLE [dbo].[ProspectSourceCode]
(
[ProspectSourceID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerID] [int] NOT NULL,
[Code] [nvarchar] (40) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProspectSourceCode] ADD CONSTRAINT [PK_ProspectSourceCode] PRIMARY KEY CLUSTERED  ([ProspectSourceID], [AccountID], [IntegrationPartnerID]) ON [PRIMARY]
GO
