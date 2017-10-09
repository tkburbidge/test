CREATE TABLE [dbo].[TimeZone]
(
[TimeZoneID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ObservesDST] [bit] NULL,
[StandardGMTOffset] [int] NOT NULL,
[DaylightGMTOffset] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TimeZone] ADD CONSTRAINT [PK_TimeZone] PRIMARY KEY CLUSTERED  ([TimeZoneID]) ON [PRIMARY]
GO
