CREATE TABLE [dbo].[Bid]
(
[BidID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL,
[ProjectID] [uniqueidentifier] NULL,
[BidTypePickListItemID] [uniqueidentifier] NOT NULL,
[Date] [datetime] NOT NULL,
[Cost] [money] NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ExpirationDate] [datetime] NULL,
[ApprovedDeniedPersonID] [uniqueidentifier] NULL,
[ApprovedDeniedDate] [datetime] NULL,
[Status] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Bid] ADD CONSTRAINT [PK_BidID] PRIMARY KEY CLUSTERED  ([BidID], [AccountID]) ON [PRIMARY]
GO
