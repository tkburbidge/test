CREATE TABLE [dbo].[PersonMessage]
(
[PersonMessageID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[UserPersonID] [uniqueidentifier] NULL,
[UserAddress] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[NonUserPersonID] [uniqueidentifier] NULL,
[NonUserAddress] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Subject] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Body] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NOT NULL,
[DateSent] [datetime] NULL,
[Status] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsOutbound] [bit] NOT NULL,
[ProviderMessageID] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ClaimedByPersonID] [uniqueidentifier] NULL,
[ClaimedByDatetime] [datetime] NULL,
[IsBulk] [bit] NOT NULL,
[ProviderErrorID] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsHidden] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonMessage] ADD CONSTRAINT [PK_PersonMessage] PRIMARY KEY CLUSTERED  ([PersonMessageID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonMessage_DateCreated] ON [dbo].[PersonMessage] ([DateCreated]) INCLUDE ([AccountID], [IsBulk], [NonUserAddress], [NonUserPersonID], [PropertyID], [Type]) ON [PRIMARY]
GO
