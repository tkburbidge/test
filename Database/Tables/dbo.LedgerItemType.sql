CREATE TABLE [dbo].[LedgerItemType]
(
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[AppliesToLedgerItemTypeID] [uniqueidentifier] NULL,
[DepositGLAccount] [uniqueidentifier] NULL,
[DepositAmount] [money] NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Abbreviation] [nvarchar] (7) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OrderBy] [smallint] NULL,
[IsRentable] [bit] NOT NULL,
[IsRent] [bit] NOT NULL,
[IsDeposit] [bit] NOT NULL,
[IsCharge] [bit] NOT NULL,
[IsCredit] [bit] NOT NULL,
[IsPayment] [bit] NOT NULL,
[IsDepositOut] [bit] NOT NULL,
[IsLateFeeAssessable] [bit] NOT NULL,
[IsRevokable] [bit] NOT NULL,
[IsWriteOffable] [bit] NOT NULL,
[IsDepositInterest] [bit] NULL,
[IsRecurringMonthlyRentConcession] [bit] NOT NULL,
[WriteOffLedgerItemTypeID] [uniqueidentifier] NULL,
[AppliesToLedgerItemTypeIDIsExclusive] [bit] NOT NULL,
[RecoveryLedgerItemTypeID] [uniqueidentifier] NULL,
[IsArchived] [bit] NOT NULL,
[DoNotProrate] [bit] NOT NULL,
[IsSalesTax] [bit] NOT NULL,
[IsSalesTaxCredit] [bit] NOT NULL,
[PostToHapLedger] [bit] NOT NULL,
[IsResidentDamage] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LedgerItemType] ADD CONSTRAINT [PK_AmenityServiceType] PRIMARY KEY CLUSTERED  ([LedgerItemTypeID], [AccountID]) ON [PRIMARY]
GO
