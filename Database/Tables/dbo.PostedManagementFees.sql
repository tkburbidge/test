CREATE TABLE [dbo].[PostedManagementFees]
(
[PostedManagementFeesID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NOT NULL,
[PostedDate] [date] NOT NULL,
[PostedPersonID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PostedManagementFees] ADD CONSTRAINT [PK_PostedManagementFees] PRIMARY KEY CLUSTERED  ([PostedManagementFeesID], [AccountID]) ON [PRIMARY]
GO
