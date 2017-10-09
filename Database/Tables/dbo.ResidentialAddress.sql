CREATE TABLE [dbo].[ResidentialAddress]
(
[AccountID] [bigint] NOT NULL,
[AddressID] [uniqueidentifier] NOT NULL,
[MoveInDate] [date] NULL,
[IsApartment] [bit] NOT NULL,
[CommunityName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ManagerName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ManagerPhone] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReasonForLeaving] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ResidentialAddress] ADD CONSTRAINT [PK_ResidentialAddress] PRIMARY KEY CLUSTERED  ([AccountID], [AddressID]) ON [PRIMARY]
GO
