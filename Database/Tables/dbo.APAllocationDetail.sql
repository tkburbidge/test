CREATE TABLE [dbo].[APAllocationDetail]
(
[APAllocationDetailID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[APAllocationID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NULL,
[GLAccountID] [uniqueidentifier] NULL,
[Percent] [decimal] (7, 4) NOT NULL,
[OrderBy] [tinyint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[APAllocationDetail] ADD CONSTRAINT [PK_APAllocationDetail] PRIMARY KEY CLUSTERED  ([APAllocationDetailID], [AccountID]) ON [PRIMARY]
GO
