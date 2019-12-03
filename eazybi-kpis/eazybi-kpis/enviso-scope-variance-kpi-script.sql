/*
	Script:			enviso-scope-variance-kpi-script.sql
	Author:			Aveek Das
	Description:	This script is used to create a data cube in EazyBI on which multiple reports
					can be developed. These reports are to be used by the management team to 
					manage and streamline the ongoing processes.
	Date:			03-Dec-2019

*/

----------------------------------------------------------------------------------------------------
-- Bringing in the data for ProjectKey and ProjectCategories
-- There is no direct relationship between these two entities
-- Need to use the intermediate bridge table NodeAssociation to fetch the same
----------------------------------------------------------------------------------------------------
WITH cte_ProjectCategory AS (
    SELECT 
        [project].[pname]			AS ProjectName
        ,[project].[pkey]			AS ProjectKey
        ,[projectcategory].[cname]	AS ProjectCategory
    FROM [jiraschema].[project]
    INNER JOIN [jiraschema].[nodeassociation] ON [nodeassociation].[source_node_id] = [project].[id]
    INNER JOIN [jiraschema].[projectcategory] ON [nodeassociation].[sink_node_id] = [projectcategory].[id]
    WHERE 1=1
    AND ProjectCategory.cname IN ('NG_APP','NG_CORE')
    AND [nodeassociation].[association_type] = 'ProjectCategory'
)
----------------------------------------------------------------------------------------------------
-- This CTE fetches the StoryPoints for all the Epics
-- irrespective of the projects (i.e. NG+RCX+DEV+...)

-- PS: In order to fetch only related Epics for NG, need to introduce INNER JOINs with JiraIssue and Project
-- which might be costlier than bringing in all data without filtering...
-- 13503 is the CustomFieldID for EpicStoryPoints
----------------------------------------------------------------------------------------------------
 ,cte_EpicStoryPoints AS (
     SELECT 
         [ISSUE]        			AS IssueID
         ,ISNULL([NUMBERVALUE],0)  	AS EpicStoryPoints 
     FROM [jiraschema].[customfieldvalue]
     WHERE [customfieldvalue].[customfield] = 13503	
 )
 ----------------------------------------------------------------------------------------------------
 -- Not using Sprint Details as of now since Epics are not planned in Sprint
 ----------------------------------------------------------------------------------------------------
 /*,cte_SprintDetails AS (
	SELECT 
		[customfieldvalue].[Issue]	AS IssueID
		,[AO_60DB71_SPRINT].[Name]	AS SprintName
	FROM jiraschema.customfieldvalue 
	INNER JOIN jiraschema.AO_60DB71_SPRINT ON AO_60DB71_SPRINT.ID = customfieldvalue.STRINGVALUE
	WHERE 1=1
	AND [customfieldvalue].[customfield] = 10005 
	AND [AO_60DB71_SPRINT].[Name] LIKE 'NG%'
 )*/
 ----------------------------------------------------------------------------------------------------
 -- Not using IssueFixVersion as we are extracting version information from the dedicated fields:
 -- * PMO Planned Portfolio Version
 -- * PMO Planned App Version
 ----------------------------------------------------------------------------------------------------
 ,cte_IssueFixVersion AS (
	SELECT 
		nodeassociation.SOURCE_NODE_ID					AS IssueID
		,[projectversion].[vname]						AS [Version]
		,CASE 
			WHEN [projectversion].[released] = 'true' THEN 'Released' ELSE 'Archived'
		END													AS VersionStatus
	FROM jiraschema.nodeassociation
	LEFT OUTER JOIN jiraschema.projectversion ON nodeassociation.sink_node_id  = projectversion.id
	WHERE nodeassociation.ASSOCIATION_TYPE = 'IssueFixVersion'
 )
 ----------------------------------------------------------------------------------------------------
 -- Building the PlannedPortfolioVersion table by extracting the Label value
 ----------------------------------------------------------------------------------------------------
 ,cte_PortfolioVersions AS (
	SELECT
		Issue	AS IssueID
		,Label	AS PortfolioVersionLabel
		,CONCAT(
			SUBSTRING([label].[Label],LEN([label].[Label])-1,1)
			,'.'
			,SUBSTRING([label].[Label],LEN([label].[Label]),1)
			,'.0'
		)		AS PortfolioVersion
	FROM [jiraschema].[label]
	WHERE 1=1
	AND [FieldID] IN (20901) -- 20901 = PMO Planned Portfolio Version
)
  ----------------------------------------------------------------------------------------------------
-- Building the PlannedAppVersion table by extracting the Label value
----------------------------------------------------------------------------------------------------
,cte_AppVersions AS (
	SELECT
		Issue	AS IssueID
		,Label	AS AppVersionLabel
		,CONCAT(
			SUBSTRING([label].[Label],LEN([label].[Label])-2,1)
			,'.'
			,SUBSTRING([label].[Label],LEN([label].[Label])-1,1)
			,'.'
			,SUBSTRING([label].[Label],LEN([label].[Label]),1)
		)		AS AppVersion
	FROM [jiraschema].[label]
	WHERE 1=1
	AND [FieldID] IN (20900) -- 20900 = PMO Planned App Version
)
 ----------------------------------------------------------------------------------------------------
 ----------------------------------------------------------------------------------------------------
SELECT 
	[jiraissue].[ID]												AS [IssueID]
    ,CONCAT([project].[pkey],'-',[jiraissue].[issuenum])			AS [IssueKey]
	,[issuetype].[pname]											AS [IssueType]
	,CASE 
		WHEN [priority].[pname] = 'Must'	THEN 1
		WHEN [priority].[pname] = 'Should'	THEN 2
		WHEN [priority].[pname] = 'Could'	THEN 3
		WHEN [priority].[pname] = 'Would'	THEN 4
	END																AS [IssuePriorityKey]
	,[priority].[pname]												AS [IssuePriority]
	,[issuestatus].[pname]											AS [IssueStatus]
	,CASE 
		WHEN [cte_ProjectCategory].[ProjectCategory] LIKE '%RCX%'	
			THEN 'ReCreateX'
		WHEN [cte_ProjectCategory].[ProjectCategory] LIKE '%NG%'	
			THEN 'Enviso'
	END																AS [Portfolio]
	,[cte_PortfolioVersions].[PortfolioVersionLabel]				AS [PortfolioVersionLabel]
	,CONCAT(
		CASE 
			WHEN [cte_ProjectCategory].[ProjectCategory] LIKE '%RCX%'	
				THEN 'ReCreateX'
			WHEN [cte_ProjectCategory].[ProjectCategory] LIKE '%NG%'	
				THEN 'Enviso'
		END
		,' '
		,[cte_PortfolioVersions].[PortfolioVersion]					
	)																AS [PortfolioVersion]
	--,[cte_PortfolioVersions].[PortfolioVersion]						AS [PortfolioVersion]
    ,[cte_ProjectCategory].[ProjectCategory]						AS [Category]
	,[project].[pname]												AS [App]
	,[cte_AppVersions].[AppVersionLabel]							AS [AppVersionLabel]
	,CONCAT(
		[project].[pname]
		,' '
		,[cte_AppVersions].[AppVersion]
	)																AS [AppVersion]
	--,[cte_AppVersions].[AppVersion]									AS [AppVersion]
	----[cte_IssueFixVersion].[VersionStatus]				AS VersionStatus,
	--,[cte_IssueFixVersion].[Version]								AS VersionOriginal
	--CASE 
	--	WHEN [cte_IssueFixVersion].[Version] IS NULL
	--	THEN CONCAT(
	--		SUBSTRING([label].[Label],LEN([label].[Label])-2,1)
	--		,'.'
	--		,SUBSTRING([label].[Label],LEN([label].[Label])-1,1)
	--		,'.'
	--		,SUBSTRING([label].[Label],LEN([label].[Label]),1)
	--	)
	--	ELSE [cte_IssueFixVersion].[Version] 
	--END													AS [Version],
	----[cte_SprintDetails].[SprintName]					AS [SprintName],
    ,ISNULL([cte_EpicStoryPoints].[EpicStoryPoints],0)				AS [StoryPointsPlanned]
	,CASE 
		WHEN [issuestatus].[pname] IN ('CLOSED','Awaiting Release')
		THEN ISNULL([cte_EpicStoryPoints].[EpicStoryPoints],0)
		ELSE 0
	END																AS [StoryPointsDelivered]
FROM		[jiraschema].[jiraissue]
INNER JOIN	[jiraschema].[project]			ON [project].[id]						= [jiraissue].[project]
INNER JOIN	[cte_ProjectCategory]			ON [cte_ProjectCategory].[ProjectKey]	= [project].[pkey]
INNER JOIN	[jiraschema].[issuetype]		ON [issuetype].[id]						= [jiraissue].[issuetype]
INNER JOIN	[jiraschema].[priority]			ON [priority].[id]						= [jiraissue].[priority]
INNER JOIN	[jiraschema].[issuestatus]		ON [issuestatus].[id]					= [jiraissue].[issuestatus]
INNER JOIN	[cte_PortfolioVersions]			ON [cte_PortfolioVersions].[IssueID]	= [jiraissue].[ID]
INNER JOIN	[cte_AppVersions]				ON [cte_AppVersions].[IssueID]			= [jiraissue].[ID]
INNER JOIN	[cte_EpicStoryPoints]			ON [cte_EpicStoryPoints].[IssueID]		= [jiraissue].[ID]
--INNER JOIN	[cte_IssueFixVersion]			ON [cte_IssueFixVersion].[IssueID]		= [jiraissue].[id]
--LEFT OUTER JOIN cte_SprintDetails ON cte_SprintDetails.IssueID = jiraissue.ID
WHERE 1 = 1
AND [jiraissue].[issuetype]	IN (7)											-- 7=Epic
AND [jiraissue].[priority]	IN (10000,10001,10002,10003)					-- Must,Should,Could,Would
--AND [jiraissue].[issuenum] = 2921