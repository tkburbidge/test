CREATE TABLE [dbo].[PropertyBlockedPhoneNumber]
(
[PhoneNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyBlockedPhoneNumber] ADD CONSTRAINT [PK_PropertyBlockedPhoneNumber] PRIMARY KEY CLUSTERED  ([PhoneNumber], [AccountID], [PropertyID]) ON [PRIMARY]
GO
