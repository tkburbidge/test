CREATE TABLE [dbo].[ApplicantInformationRentableItemType]
(
[ApplicantInformationRentableItemTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ApplicantInformationID] [uniqueidentifier] NOT NULL,
[LedgerItemPoolID] [uniqueidentifier] NOT NULL,
[Quantity] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicantInformationRentableItemType] ADD CONSTRAINT [PK__Applican__127922BDC4963F39] PRIMARY KEY CLUSTERED  ([ApplicantInformationRentableItemTypeID], [AccountID]) ON [PRIMARY]
GO
