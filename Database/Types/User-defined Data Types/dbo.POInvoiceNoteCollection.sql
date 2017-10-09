CREATE TYPE [dbo].[POInvoiceNoteCollection] AS TABLE
(
[POInvoiceNoteID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NULL,
[AltObjectID] [uniqueidentifier] NULL,
[AltObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Date] [date] NOT NULL,
[Status] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Notes] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Timestamp] [datetime] NOT NULL,
[IntegrationPartnerID] [int] NULL
)
GO
