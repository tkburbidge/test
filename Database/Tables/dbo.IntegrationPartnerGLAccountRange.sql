CREATE TABLE [dbo].[IntegrationPartnerGLAccountRange]
(
[IntegrationPartnerGLAccountRangeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerID] [int] NOT NULL,
[StartNumber] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EndNumber] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationPartnerGLAccountRange] ADD CONSTRAINT [PK_IntegrationPartnerGLAccountRange] PRIMARY KEY CLUSTERED  ([IntegrationPartnerGLAccountRangeID], [AccountID]) ON [PRIMARY]
GO
