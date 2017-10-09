CREATE TABLE [dbo].[CollectionAgreement]
(
[CollectionAgreementID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime] NOT NULL,
[Amount] [money] NOT NULL,
[Notes] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[CollectionType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[NoticeSent] [bit] NOT NULL,
[IsClosed] [bit] NOT NULL,
[IntegrationPartnerItemID] [int] NULL,
[LastSent] [datetime] NULL,
[CollectionAccountClosedReasonPickListItemID] [uniqueidentifier] NULL,
[ClosedPersonNoteID] [uniqueidentifier] NULL,
[ServiceProviderID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CollectionAgreement] ADD CONSTRAINT [PK_CollectionAgreement] PRIMARY KEY CLUSTERED  ([CollectionAgreementID], [AccountID]) ON [PRIMARY]
GO
