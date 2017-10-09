CREATE TABLE [dbo].[PhoneNumber]
(
[PhoneNumberID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Number] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Type] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PhoneNumber] ADD CONSTRAINT [PK_PhoneNumber] PRIMARY KEY CLUSTERED  ([PhoneNumberID], [AccountID]) ON [PRIMARY]
GO
