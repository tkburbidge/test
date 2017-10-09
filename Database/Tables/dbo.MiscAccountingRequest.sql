CREATE TABLE [dbo].[MiscAccountingRequest]
(
[MiscAccountingRequestID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [int] NOT NULL,
[Comment] [nvarchar] (78) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[AffordableProgramAllocationID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[MiscAccountingRequest] ADD CONSTRAINT [PK_MiscAccountingRequest] PRIMARY KEY CLUSTERED  ([MiscAccountingRequestID], [AccountID]) ON [PRIMARY]
GO
