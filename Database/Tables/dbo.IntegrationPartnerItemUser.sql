CREATE TABLE [dbo].[IntegrationPartnerItemUser]
(
[IntegrationPartnerItemUserID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerItemID] [int] NOT NULL,
[UserID] [uniqueidentifier] NOT NULL,
[Value1] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value2] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value3] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationPartnerItemUser] ADD CONSTRAINT [PK_IntegrationPartnerItemUser] PRIMARY KEY CLUSTERED  ([IntegrationPartnerItemUserID], [AccountID]) ON [PRIMARY]
GO
