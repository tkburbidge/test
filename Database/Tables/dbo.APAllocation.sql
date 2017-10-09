CREATE TABLE [dbo].[APAllocation]
(
[APAllocationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[APAllocation] ADD CONSTRAINT [PK_APAllocation] PRIMARY KEY CLUSTERED  ([APAllocationID], [AccountID]) ON [PRIMARY]
GO
