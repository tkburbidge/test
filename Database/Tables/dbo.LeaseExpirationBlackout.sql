CREATE TABLE [dbo].[LeaseExpirationBlackout]
(
[LeaseExpirationBlackoutID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Value] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DaysBefore] [int] NULL,
[DaysAfter] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LeaseExpirationBlackout] ADD CONSTRAINT [PK_LeaseExpirationBlackout] PRIMARY KEY CLUSTERED  ([LeaseExpirationBlackoutID], [AccountID]) ON [PRIMARY]
GO
