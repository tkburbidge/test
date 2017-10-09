CREATE TABLE [dbo].[UserIntegrationPartnerItem]
(
[UserIntegrationPartnerItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UserID] [uniqueidentifier] NOT NULL,
[IntegrationPartnerItemID] [int] NOT NULL,
[Username] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Password] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UserIntegrationPartnerItem] ADD CONSTRAINT [PK_UserIntegrationPartnerItem] PRIMARY KEY CLUSTERED  ([UserIntegrationPartnerItemID], [AccountID]) ON [PRIMARY]
GO
