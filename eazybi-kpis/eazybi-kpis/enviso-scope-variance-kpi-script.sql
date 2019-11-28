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

 ,cte_EpicStoryPoints AS (
     SELECT 
         [customfieldvalue].[ID]	AS EpicStoryPointID
         ,[ISSUE]        			AS IssueID
         ,ISNULL([NUMBERVALUE],0)  	AS EpicStoryPoints 
     FROM [jiraschema].[customfieldvalue]
     INNER JOIN [jiraschema].[customfield] ON [customfieldvalue].[CUSTOMFIELD] = [customfield].[ID]
     WHERE [customfield].[cfname] = 'Epic Story Points'
 )

 ,cte_SprintDetails AS (
	SELECT 
		[customfieldvalue].[Issue]	AS IssueID
		,[AO_60DB71_SPRINT].[Name]	AS SprintName
	FROM jiraschema.customfieldvalue 
	INNER JOIN jiraschema.AO_60DB71_SPRINT ON AO_60DB71_SPRINT.ID = customfieldvalue.STRINGVALUE
	WHERE 1=1
	AND [customfieldvalue].[customfield] = 10005 
	AND [AO_60DB71_SPRINT].[Name] LIKE 'NG%'
 )

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

SELECT 
	[jiraissue].[ID]                                    AS IssueID,
    CONCAT([project].[pkey],'-',[jiraissue].[issuenum]) AS IssueKey,
	[issuetype].[pname]                                 AS IssueType,
	[priority].[pname]                                  AS IssuePriority,
	[issuestatus].[pname]                               AS IssueStatus,
	[label].[Label]										AS Label,
	CASE 
		WHEN [cte_ProjectCategory].[ProjectCategory] LIKE '%RCX%'	THEN 'ReCreateX'
		WHEN [cte_ProjectCategory].[ProjectCategory] LIKE '%NG%'	THEN 'Enviso'
	END													AS Portfolio,
    [cte_ProjectCategory].[ProjectCategory]             AS Category,
	[project].[pname]                                   AS App,
	--[cte_IssueFixVersion].[VersionStatus]				AS VersionStatus,
	[cte_IssueFixVersion].[Version]						AS VersionOriginal,
	CASE 
		WHEN [cte_IssueFixVersion].[Version] IS NULL
		THEN CONCAT(
			SUBSTRING([label].[Label],LEN([label].[Label])-2,1)
			,'.'
			,SUBSTRING([label].[Label],LEN([label].[Label])-1,1)
			,'.'
			,SUBSTRING([label].[Label],LEN([label].[Label]),1)
		)
		ELSE [cte_IssueFixVersion].[Version] 
	END													AS [Version],
	[cte_SprintDetails].[SprintName]					AS [SprintName],
    ISNULL([cte_EpicStoryPoints].[EpicStoryPoints],0)   AS [StoryPointsPlanned],
	CASE 
		WHEN [issuestatus].[pname] IN ('CLOSED','Awaiting Release')
		THEN ISNULL([cte_EpicStoryPoints].[EpicStoryPoints],0)
		ELSE 0
	END													AS [StoryPointsDelivered]
FROM jiraschema.jiraissue
INNER JOIN jiraschema.project ON project.id = jiraissue.project
INNER JOIN jiraschema.issuetype ON issuetype.id = jiraissue.issuetype
INNER JOIN jiraschema.priority ON priority.id = jiraissue.priority
INNER JOIN jiraschema.issuestatus ON issuestatus.id = jiraissue.issuestatus
LEFT OUTER JOIN jiraschema.label ON label.issue = jiraissue.ID
LEFT OUTER JOIN cte_IssueFixVersion ON cte_IssueFixVersion.IssueID = jiraissue.id
LEFT OUTER JOIN cte_ProjectCategory ON cte_ProjectCategory.ProjectKey = project.pkey
LEFT OUTER JOIN cte_EpicStoryPoints ON cte_EpicStoryPoints.IssueID = jiraissue.ID
LEFT OUTER JOIN cte_SprintDetails ON cte_SprintDetails.IssueID = jiraissue.ID
WHERE 1 = 1
AND issuetype IN (7)	--(8,10309,10410) -- 7=Epic
--AND issuestatus IN (6,11608) --6=Closed, 11608=Awaiting Release
AND priority IN (10000,10001,10002,10003) --Must,Should,Could,Would
-- AND SINK_NODE_ID = 36400
AND label.label like 'NG%'