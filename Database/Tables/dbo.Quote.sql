CREATE TABLE [dbo].[Quote]
(
[QuoteID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RecipientObjectID] [uniqueidentifier] NOT NULL,
[RecipientObjectType] [nvarchar] (16) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[QuoteForObjectID] [uniqueidentifier] NOT NULL,
[QuoteForObjectType] [nvarchar] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [date] NOT NULL,
[ExpirationDate] [date] NULL,
[LeaseTerm] [int] NOT NULL,
[MoveInByDate] [date] NULL,
[DateCompleted] [date] NULL,
[Status] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ApplicantTypeID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Quote] ADD CONSTRAINT [PK_Quote] PRIMARY KEY CLUSTERED  ([QuoteID], [AccountID]) ON [PRIMARY]
GO
