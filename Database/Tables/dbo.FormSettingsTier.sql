CREATE TABLE [dbo].[FormSettingsTier]
(
[FormSettingsTierID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[BaseCourtFee] [money] NULL,
[PerOccupantCourtFee] [money] NULL,
[AttorneyFees] [money] NULL,
[MinBalance] [money] NULL,
[MaxBalance] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[FormSettingsTier] ADD CONSTRAINT [PK_FormSettingsTier] PRIMARY KEY CLUSTERED  ([FormSettingsTierID], [AccountID]) ON [PRIMARY]
GO
