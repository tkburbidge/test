CREATE TABLE [dbo].[CorduroWallet]
(
[CorduroWalletID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[CorduroVaultID] [uniqueidentifier] NOT NULL,
[MaskedCardNumber] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CardType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ExpirationDate] [nvarchar] (7) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Amount] [money] NOT NULL,
[DateCreated] [date] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CorduroWallet] ADD CONSTRAINT [PK_CorduroWallet] PRIMARY KEY CLUSTERED  ([CorduroWalletID], [AccountID]) ON [PRIMARY]
GO
