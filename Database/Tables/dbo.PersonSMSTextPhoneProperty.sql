CREATE TABLE [dbo].[PersonSMSTextPhoneProperty]
(
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[ReceivesTextsFromPhoneNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonSMSTextPhoneProperty] ADD CONSTRAINT [PK_PersonSMSTextPhoneProperty] PRIMARY KEY CLUSTERED  ([AccountID], [PersonID], [PropertyID]) ON [PRIMARY]
GO
