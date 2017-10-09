CREATE TABLE [dbo].[WalletItem]
(
[WalletItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerID] [int] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ProcessorWalletItemID] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AccountType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AccountName] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ExpirationDate] [nvarchar] (7) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [date] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WalletItem] ADD CONSTRAINT [PK_WalletItem] PRIMARY KEY CLUSTERED  ([WalletItemID], [AccountID]) ON [PRIMARY]
GO
