CREATE TABLE [dbo].[SummaryVendor]
(
[SummaryVendorID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AddressID] [uniqueidentifier] NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PhoneNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SummaryVendor] ADD CONSTRAINT [PK_SummaryVendor] PRIMARY KEY CLUSTERED  ([SummaryVendorID], [AccountID]) ON [PRIMARY]
GO
