CREATE TABLE [dbo].[ApplicantTypeApplicationFee]
(
[ApplicantTypeApplicationFeeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ApplicantTypeID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[Amount] [money] NOT NULL,
[Description] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PerUnit] [bit] NOT NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicantTypeApplicationFee] ADD CONSTRAINT [PK_ApplicantTypeApplicationFee] PRIMARY KEY CLUSTERED  ([ApplicantTypeApplicationFeeID], [AccountID]) ON [PRIMARY]
GO
