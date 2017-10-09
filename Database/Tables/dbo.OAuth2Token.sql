CREATE TABLE [dbo].[OAuth2Token]
(
[AccountID] [bigint] NOT NULL,
[UserID] [uniqueidentifier] NOT NULL,
[OAuth2ClientID] [uniqueidentifier] NOT NULL,
[Token] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
