/*
This migration script replaces uncommitted changes made to these objects:
Settings

Use this script to make necessary schema and data changes for these objects only. Schema changes to any other objects won't be deployed.

Schema changes and migration scripts are deployed in the order they're committed.

Migration scripts must not reference static data. When you deploy migration scripts alongside static data 
changes, the migration scripts will run first. This can cause the deployment to fail. 
Read more at https://documentation.red-gate.com/display/SOC5/Static+data+and+migrations.
*/
ALTER TABLE dbo.Settings ADD	NewColumn INT NULL
GO
UPDATE dbo.Settings SET NewColumn = 900
GO
ALTER TABLE dbo.Settings ALTER COLUMN NewColumn INT NOT NULL
GO

