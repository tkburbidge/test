CREATE TABLE [dbo].[CompanyCommunicationUser]
(
[CompanyCommunicationUserID] [uniqueidentifier] NOT NULL,
[CompanyCommunicationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UserID] [uniqueidentifier] NOT NULL,
[DateAcknowledged] [date] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CompanyCommunicationUser] ADD CONSTRAINT [PK_CompanyCommunicationUser_1] PRIMARY KEY CLUSTERED  ([CompanyCommunicationUserID], [AccountID]) ON [PRIMARY]
GO
