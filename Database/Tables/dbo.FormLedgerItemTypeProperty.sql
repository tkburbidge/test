CREATE TABLE [dbo].[FormLedgerItemTypeProperty]
(
[FormLedgerItemTypePropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LedgerItemTypePropertyID] [uniqueidentifier] NOT NULL,
[FormInformationID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[FormLedgerItemTypeProperty] ADD CONSTRAINT [PK_FormLedgerItemTypeProperty] PRIMARY KEY CLUSTERED  ([FormLedgerItemTypePropertyID], [AccountID]) ON [PRIMARY]
GO
