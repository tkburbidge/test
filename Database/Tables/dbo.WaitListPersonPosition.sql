CREATE TABLE [dbo].[WaitListPersonPosition]
(
[WaitListPersonPositionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WaitListPersonID] [uniqueidentifier] NOT NULL,
[Position] [smallint] NULL,
[DateCreated] [datetime] NOT NULL,
[PersonID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitListPersonPosition] ADD CONSTRAINT [PK_WaitListPersonPosition] PRIMARY KEY CLUSTERED  ([WaitListPersonPositionID], [AccountID]) ON [PRIMARY]
GO
