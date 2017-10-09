CREATE TABLE [dbo].[Address]
(
[AddressID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[AddressType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StreetAddress] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[City] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[State] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Country] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Zip] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsDefaultMailingAddress] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Address] ADD CONSTRAINT [PK_Address] PRIMARY KEY CLUSTERED  ([AddressID], [AccountID]) ON [PRIMARY]
GO
