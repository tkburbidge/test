CREATE TABLE [dbo].[OAuth]
(
[AccountID] [bigint] NOT NULL,
[OAuthID] [uniqueidentifier] NOT NULL,
[UserID] [uniqueidentifier] NOT NULL,
[AuthenticationToken] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AuthenticationExpiration] [datetime] NULL,
[RenewalToken] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[OAuth] ADD CONSTRAINT [PK_Oauth] PRIMARY KEY CLUSTERED  ([AccountID], [OAuthID]) ON [PRIMARY]
GO
