CREATE TABLE [dbo].[PropertyPhoneNumber]
(
[PhoneNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[IntegrationPartnerID] [int] NOT NULL,
[IsActive] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyPhoneNumber] ADD CONSTRAINT [PK_PropertyPhoneNumber] PRIMARY KEY CLUSTERED  ([PhoneNumber], [AccountID], [PropertyID], [IntegrationPartnerID]) ON [PRIMARY]
GO
