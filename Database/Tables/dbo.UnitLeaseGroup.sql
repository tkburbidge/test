CREATE TABLE [dbo].[UnitLeaseGroup]
(
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[UnitID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PreviousUnitLeaseGroupID] [uniqueidentifier] NULL,
[MoveInInventoryReceived] [bit] NULL,
[CashOnlyOverride] [bit] NOT NULL,
[OnlinePaymentsDisabled] [bit] NOT NULL,
[MoveOutReconciliationNotes] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ImportNSFCount] [smallint] NULL,
[ImportTimesLate] [smallint] NULL,
[NSFImportDate] [date] NULL,
[EndingBalancesTransferred] [bit] NULL,
[LastPersonNoteID] [uniqueidentifier] NULL,
[NextAlertTaskID] [uniqueidentifier] NULL,
[ProratedMoveOutChargesDate] [date] NULL,
[WorkOrderResidentInstructions] [nvarchar] (3500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PropertyCanAcceptPackges] [bit] NULL,
[DoNotRenewPersonNoteID] [uniqueidentifier] NULL,
[ConversionDepositInterestRefund] [money] NULL,
[MoveOutReconciliationDate] [date] NULL,
[SalesTaxExempt] [bit] NOT NULL,
[TransferGroupID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitLeaseGroup] ADD CONSTRAINT [PK_UnitLeaseGroup] PRIMARY KEY CLUSTERED  ([UnitLeaseGroupID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_UnitLeaseGroup_UnitID] ON [dbo].[UnitLeaseGroup] ([UnitID]) ON [PRIMARY]
GO
