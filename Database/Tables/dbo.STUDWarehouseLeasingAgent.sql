CREATE TABLE [dbo].[STUDWarehouseLeasingAgent]
(
[STUDWarehouseLeasingAgentID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Date] [date] NOT NULL,
[WeekNumber] [int] NOT NULL,
[SignedLeaseCount] [int] NOT NULL,
[ProspectCount] [int] NOT NULL,
[FollowUpCount] [int] NOT NULL
) ON [PRIMARY]
GO
