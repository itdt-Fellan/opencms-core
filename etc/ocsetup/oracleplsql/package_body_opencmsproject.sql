CREATE OR REPLACE
PACKAGE BODY OpenCmsProject IS
   -- variable/funktions/procedures which are used only in this package
   bAnyList VARCHAR2(32767) := '';
   FUNCTION addInList(pAnyId NUMBER) RETURN BOOLEAN;
--------------------------------------------------------------------
-- return all project which the user has access
-- this function calls the function getGroupsOfUser
-- and returns the Cursor with the projects
--------------------------------------------------------------------
	FUNCTION getAllAccessibleProjects(pUserID IN NUMBER) RETURN userTypes.anyCursor IS
      CURSOR cProjUser IS
             select * from cms_projects
                    where user_id = pUserID
                    and project_flags = 0
                    order by project_name;
      CURSOR cProjAdmin IS
             select * from cms_projects
                    where project_flags = 0
                    order by project_name;
      CURSOR cProjGroup(cGroupID NUMBER) IS
             select * from cms_projects
                    where (group_id = cGroupId or managergroup_id = cGroupId)
                    and project_flags = 0
                    order by project_name;

      vCursor userTypes.anyCursor := opencmsgroup.getGroupsOfUser (pUserID);
      recAllAccProjects userTypes.anyCursor;
      recGroup cms_groups%ROWTYPE;
      recProject cms_projects%ROWTYPE;
      vQueryStr VARCHAR2(32767) := '';
	BEGIN
      -- all projects where the user is owner
      FOR recProject IN cProjUser LOOP
        -- remember each project-id => no duplicates
        IF addInList(recProject.project_id) THEN
          null;
        END IF;
      END LOOP;
      -- all projects where the groups, which the user belongs to, have access
	  LOOP
	    FETCH vCursor INTO recGroup;
	    EXIT WHEN vCursor%NOTFOUND;
        IF recGroup.group_name = opencmsConstants.C_GROUP_ADMIN THEN
          -- if the user is member of the group administrators then list all projects
          FOR recProject IN cProjAdmin LOOP
            IF addInList(recProject.project_id) THEN
              vQueryStr := vQueryStr||' union select * from cms_projects where project_flags = 0 ';
            END IF;
          END LOOP;
        ELSE
          FOR recProject IN cProjGroup(recGroup.group_id) LOOP
            IF addInList(recProject.project_id) THEN
              vQueryStr := vQueryStr||' union select * from cms_projects where project_flags = 0'||
                                      ' and (group_id = '||to_char(recGroup.group_id)||' or managergroup_id = '||
                                      to_char(recGroup.group_id)||')';
            END IF;
          END LOOP;
        END IF;
	  END LOOP;
      CLOSE vCursor;
      bAnyList := '';
      -- return the cursor

      OPEN recAllAccProjects FOR 'select * from (select * from cms_projects where user_id = '||to_char(pUserID)||' and project_flags = 0 '||
                                  vQueryStr||') order by project_name';
      RETURN recAllAccProjects;
	END getAllAccessibleProjects;
------------------------------------------------------------------------------------
-- funktion checks if the ID is already in list, if not it edits the list
-- and returns boolean
------------------------------------------------------------------------------------
  FUNCTION addInList(pAnyId NUMBER) RETURN BOOLEAN IS
    vCount NUMBER;
  BEGIN
    vCount := nvl(Instr(bAnyList, ''''||to_char(pAnyId)||''''),0);
    IF vCount = 0 THEN
      bAnyList := bAnyList||','''||to_char(pAnyId)||'''';
      RETURN TRUE;
    ELSE
      RETURN FALSE;
	END IF;
  END addInList;
------------------------------------------------------------------------------------------
-- insert a new project and return of the project-id
------------------------------------------------------------------------------------------
  PROCEDURE createProject(pUserId IN NUMBER, pProjectName IN VARCHAR2, pProjectDescription IN VARCHAR2,
                         pGroupName IN VARCHAR2, pManagerGroupName IN VARCHAR2, pTaskID IN NUMBER,
                         pProject OUT userTypes.anyCursor) IS

    vGroupId cms_groups.group_id%TYPE;
    vManagerGroupId cms_groups.group_id%TYPE;
    vProjectID CMS_PROJECTS.project_id%TYPE;
  BEGIN
    -- select the ID of the group
    BEGIN
      select group_id into vGroupID from CMS_GROUPS where group_name = pGroupName;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        vGroupId := -1;
    END;
    BEGIN
      select group_id into vManagerGroupID from CMS_GROUPS where group_name = pManagerGroupName;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        vManagerGroupId := -1;
    END;
    --
    -- insert in CMS_PROJECTS
    vProjectId := getNextId(opencmsConstants.C_TABLE_PROJECTS);
    insert into cms_projects
           (project_id, user_id, group_id, managergroup_id, task_id, project_name, project_description,
            project_flags, project_createdate, project_publishdate, project_published_by, project_type)
    values (vProjectId, pUserId, vGroupId, vManagerGroupId, pTaskId, pProjectName,
            pProjectDescription, 0, sysdate, NULL, -1, 0);
    commit;
    --
    -- return the project
    OPEN pProject FOR select * from cms_projects where project_id = vProjectId;
  EXCEPTION
    WHEN OTHERS THEN
      rollback;
      RAISE;
  END createProject;
--------------------------------------------------------------------------------------------
-- publishes the project: copy (insert/update) the folders, files, properties
-- from the work-project to the online-project
--------------------------------------------------------------------------------------------
  PROCEDURE publishProject (pUserId NUMBER, pProjectId NUMBER, pOnlineProjectId NUMBER,
  							pEnableHistory NUMBER, pPublishDate DATE,
                            pCurDelFolders OUT userTypes.anyCursor, pCurWriteFolders OUT userTypes.anyCursor,
                            pCurDelFiles OUT userTypes.anyCursor, pCurWriteFiles OUT userTypes.anyCursor) IS

    CURSOR curFolders(cProjectId NUMBER) IS
           select cms_resources.resource_id, cms_resources.parent_id,
                  cms_resources.resource_name, cms_resources.resource_type,
                  cms_resources.resource_flags, cms_resources.user_id,
                  cms_resources.group_id, cms_projectresources.project_id,
                  cms_resources.file_id, cms_resources.access_flags, cms_resources.state,
                  cms_resources.locked_by, cms_resources.launcher_type,
                  cms_resources.launcher_classname, cms_resources.date_created,
                  cms_resources.date_lastmodified, cms_resources.resource_size,
                  cms_resources.resource_lastmodified_by
                  from cms_resources, cms_projectresources
                  where cms_projectresources.project_id= cProjectId
                  and cms_resources.resource_type = opencmsConstants.C_TYPE_FOLDER
                  and cms_resources.resource_name like concat(cms_projectresources.resource_name,'%')
                  and cms_resources.state != opencmsConstants.C_STATE_UNCHANGED
                  order by cms_resources.resource_name;

    CURSOR curFiles(cProjectId NUMBER) IS
           select cms_resources.resource_id, cms_resources.parent_id,
                  cms_resources.resource_name, cms_resources.resource_type,
                  cms_resources.resource_flags, cms_resources.user_id,
                  cms_resources.group_id, cms_projectresources.project_id,
                  cms_resources.file_id, cms_resources.access_flags, cms_resources.state,
                  cms_resources.locked_by, cms_resources.launcher_type,
                  cms_resources.launcher_classname, cms_resources.date_created,
                  cms_resources.date_lastmodified, cms_resources.resource_size,
                  cms_resources.resource_lastmodified_by, cms_files.file_content
                  from cms_resources, cms_projectresources, cms_files
                  where cms_projectresources.project_id = cProjectId
                  and cms_resources.resource_name like concat(cms_projectresources.resource_name, '%')
                  and cms_resources.file_id = cms_files.file_id (+)
                  and cms_resources.resource_type != opencmsConstants.C_TYPE_FOLDER
                  and cms_resources.state != opencmsConstants.C_STATE_UNCHANGED
                  order by cms_resources.resource_name;

    recFolders cms_resources%ROWTYPE;
    recFiles userTypes.fileRecord;
    vParentId NUMBER;
    curNewFolder userTypes.anyCursor;
    recNewFolder cms_resources%ROWTYPE;
    curNewFile userTypes.anyCursor;
    recNewFile userTypes.fileRecord;
    vResourceId cms_resources.resource_id%TYPE;
    vFileId cms_resources.file_id%TYPE;
    vDeletedFolders VARCHAR2(32767) := '';
    vCurDelFolders VARCHAR2(32767) := '';
    vCurDelFiles VARCHAR2(32767) := '';
    vCurWriteFolders VARCHAR2(32767) := '';
    vCurWriteFiles VARCHAR2(32767) := '';
    vVersionId NUMBER := 1;
    --vPublishDate DATE := to_date(pPublishDate, 'dd.mm.yyyy hh24:mi');
  BEGIN
    ---------------------------------------
    -- get the next version id for backup
    -- pEnableHistory = 1 => enable history
    ---------------------------------------
    IF pEnableHistory = 1 THEN
      select nvl(max(version_id),0) + 1 into vVersionId from cms_backup_resources;
    END IF;
    ---------------------------------
    -- for all folders of the project
    ---------------------------------
    OPEN curFolders(pProjectId);
    LOOP
      FETCH curFolders INTO recFolders;
      EXIT WHEN curFolders%NOTFOUND;
      -- do not publish folders that are locked in another project
      IF (recFolders.locked_by != opencmsConstants.C_UNKNOWN_ID) THEN
        -- do nothing;
        null;
      -- is the resource marked as deleted?
      ELSIF recFolders.state = opencmsConstants.C_STATE_DELETED THEN
        -- add to list with deleted folders
        vDeletedFolders := vDeletedFolders||'/'||to_char(recFolders.resource_id);
      -- is the resource marked as new?
      ELSIF recFolders.state = opencmsConstants.C_STATE_NEW THEN
        BEGIN
          select resource_id into vParentId
                 from cms_online_resources
                 where resource_name = opencmsResource.getParent(recFolders.resource_name);
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            vParentId := opencmsConstants.C_UNKNOWN_ID;
        END;
        BEGIN
          opencmsResource.createFolder(pUserId, pOnlineProjectId, pOnlineProjectId, recFolders,
            	                         vParentId, recFolders.resource_name, curNewFolder);
          FETCH curNewFolder INTO recNewFolder;
          CLOSE curNewFolder;
		  recNewFolder.state := opencmsConstants.C_STATE_UNCHANGED;
		  opencmsResource.writeFolder(pOnlineProjectId, recNewFolder, 'FALSE');
        EXCEPTION
		  WHEN OTHERS THEN
		  	IF sqlcode = userErrors.C_FILE_EXISTS THEN
		  	  curNewFolder := opencmsResource.readFolder(pUserId, pOnlineProjectId, recFolders.resource_name);
			  FETCH curNewFolder INTO recNewFolder;
			  CLOSE curNewFolder;
		  	  -- the folder already exists in the online-project
              -- update the folder in the online-project
              update cms_online_resources set
                     resource_type = recFolders.resource_type,
                     resource_flags = recFolders.resource_flags,
                     user_id = recFolders.user_id,
                     group_id = recFolders.group_id,
                     project_id = pOnlineProjectId,
                     access_flags = recFolders.access_flags,
                     state = opencmsConstants.C_STATE_UNCHANGED,
                     locked_by = recFolders.locked_by,
                     launcher_type = recFolders.launcher_type,
                     launcher_classname = recFolders.launcher_classname,
                     date_lastmodified = sysdate,
                     resource_lastmodified_by = recFolders.resource_lastmodified_by,
                     resource_size = 0,
                     file_id = recFolders.file_id
                     where resource_id = recNewFolder.resource_id;
              commit;
		  	  curNewFolder := opencmsResource.readFolder(pUserId, pOnlineProjectId, recFolders.resource_name);
			  FETCH curNewFolder INTO recNewFolder;
			  CLOSE curNewFolder;
		    ELSE
			  RAISE;
		    END IF;
        END;
        opencmsResource.writeFolder(pOnlineProjectId, recNewFolder, 'FALSE');
        -- copy properties
        opencmsProperty.writeProperties(pOnlineProjectId, opencmsProperty.readAllProperties(pUserId, pProjectId, recFolders.resource_name),
                                        recNewFolder.resource_id, recNewFolder.resource_type);
        -- remember only one id for mark
        vCurWriteFolders := recNewFolder.resource_id;
        IF pEnableHistory = 1 THEN
        	-- backup the resource
        	opencmsResource.backupFolder(pProjectId, recFolders, vVersionId, pPublishDate);
        END IF;
      -- is the resource marked as changed?
      ELSIF recFolders.state = opencmsConstants.C_STATE_CHANGED THEN
        -- checkExport ???
        -- does the folder exist in the online-project?
        curNewFolder := opencmsResource.readFolder(pUserId, pOnlineProjectId, recFolders.resource_name);
        FETCH curNewFolder INTO recNewFolder;
        CLOSE curNewFolder;
        -- folder does not exist in online-project => create folder
        IF recNewFolder.resource_id IS NULL THEN
          BEGIN
            select resource_id into vParentId
                   from cms_online_resources
                   where resource_name = opencmsResource.getParent(recFolders.resource_name);
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              vParentId := opencmsConstants.C_UNKNOWN_ID;
          END;
          opencmsResource.createFolder(pUserId, pOnlineProjectId, pOnlineProjectId, recFolders,
                                       vParentId, recFolders.resource_name, curNewFolder);
          FETCH curNewFolder INTO recNewFolder;
          CLOSE curNewFolder;
          recNewFolder.state := opencmsConstants.C_STATE_UNCHANGED;
          opencmsResource.writeFolder(pOnlineProjectId, recNewFolder, 'FALSE');
        END IF;
        -- update the folder in the online-project
        update cms_online_resources set
               resource_type = recFolders.resource_type,
               resource_flags = recFolders.resource_flags,
               user_id = recFolders.user_id,
               group_id = recFolders.group_id,
               project_id = pOnlineProjectId,
               access_flags = recFolders.access_flags,
               state = opencmsConstants.C_STATE_UNCHANGED,
               locked_by = recFolders.locked_by,
               launcher_type = recFolders.launcher_type,
               launcher_classname = recFolders.launcher_classname,
               date_lastmodified = sysdate,
               resource_lastmodified_by = recFolders.resource_lastmodified_by,
               resource_size = 0,
               file_id = recFolders.file_id
               where resource_id = recNewFolder.resource_id;
        commit;
        -- copy the properties
        delete from cms_online_properties where resource_id = recNewFolder.resource_id;
        opencmsProperty.writeProperties(pOnlineProjectId, opencmsProperty.readAllProperties(pUserId, pProjectId, recFolders.resource_name),
                                        recNewFolder.resource_id, recNewFolder.resource_type);
        -- remember only one id for mark
        vCurWriteFolders := recNewFolder.resource_id;
        IF pEnableHistory = 1 THEN
          -- backup the resource
          opencmsResource.backupFolder(pProjectId, recFolders, vVersionId, pPublishDate);
        END IF;
      END IF;
    END LOOP;
    CLOSE curFolders;
    ---------------------------------
    -- for all files of the project
    ---------------------------------
    OPEN curFiles(pProjectId);
    LOOP
      FETCH curFiles INTO recFiles;
      EXIT WHEN curFiles%NOTFOUND;
      -- do not publish files that are locked in another project
      IF (recFiles.locked_by != opencmsConstants.C_UNKNOWN_ID) THEN
        -- do nothing;
        null;
      -- resource of offline-project is marked for delete
      ELSIF substr(recFiles.resource_name,instr(recFiles.resource_name,'/',-1,1)+1,1) = opencmsConstants.C_TEMP_PREFIX THEN
        delete from cms_resources where resource_name = recFiles.resource_name;
      -- resource is deleted
      ELSIF recFiles.state = opencmsConstants.C_STATE_DELETED THEN
        --checkExport ???
        curNewFile := opencmsResource.readFileNoAccess(pUserId, pOnlineProjectId, pOnlineProjectId, recFiles.resource_name);
        FETCH curNewFile INTO recNewFile;
        CLOSE curNewFile;
        -- delete the file from online project
        delete from cms_online_properties where resource_id = recNewFile.resource_id;
        delete from cms_online_resources where resource_id = recNewFile.resource_id;
        delete from cms_online_files where file_id = recNewFile.file_id;
        -- remember only one id for mark
        vCurDelFiles := recNewFile.resource_id;
      -- resource is new
      ELSIF recFiles.state = opencmsConstants.C_STATE_NEW THEN
        -- checkExport ???
        BEGIN
          select resource_id into vParentId
                 from cms_online_resources
                 where resource_name = opencmsResource.getParent(recFiles.resource_name);
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            vParentId := opencmsConstants.C_UNKNOWN_ID;
        END;
        BEGIN
          opencmsResource.createFile(pOnlineProjectId, pOnlineProjectId, recFiles, pUserId, vParentId,
                                     recFiles.resource_name, 'FALSE', curNewFile);
          FETCH curNewFile INTO recNewFile;
          CLOSE curNewFile;
          --recNewFile.state := opencmsConstants.C_STATE_UNCHANGED;
          --opencmsResource.writeFile(pOnlineProjectId, recNewFile, 'FALSE');
          update cms_online_resources set state = opencmsConstants.C_STATE_UNCHANGED 
                 where resource_id=recNewFile.resource_id;
        EXCEPTION
          WHEN OTHERS THEN
            IF sqlcode = userErrors.C_FILE_EXISTS THEN
              -- the folder already exist in the online-project
              curNewFile := opencmsResource.readFileNoAccess(pUserId, pOnlineProjectId, pOnlineProjectId, recFiles.resource_name);
              FETCH curNewFile INTO recNewFile;
              CLOSE curNewFile;
              -- update the file in the online-project
              update cms_online_resources set
                     resource_type = recFiles.resource_type,
                     resource_flags = recFiles.resource_flags,
                     user_id = recFiles.user_id,
                     group_id = recFiles.group_id,
                     project_id = pOnlineProjectId,
                     access_flags = recFiles.access_flags,
                     state = opencmsConstants.C_STATE_UNCHANGED,
                     locked_by = recFiles.locked_by,
                     launcher_type = recFiles.launcher_type,
                     launcher_classname = recFiles.launcher_classname,
                     date_lastmodified = sysdate,
                     resource_lastmodified_by = recFiles.resource_lastmodified_by,
                     resource_size = recFiles.resource_size
                     where resource_id = recNewFile.resource_id;
              update cms_online_files set
              		file_content = recFiles.file_content
              		where file_id = recNewFile.file_id;
              commit;
            ELSE
              RAISE;
            END IF;
        END;
        -- copy the properties
        opencmsProperty.writeProperties(pOnlineProjectId, opencmsProperty.readAllProperties(pUserId, pProjectId, recFiles.resource_name),
                                        recNewFile.resource_id, recFiles.resource_type);
        -- remember only one id for mark
        vCurWriteFiles := recNewFile.resource_id;
        IF pEnableHistory = 1 THEN
          -- backup the resource
          opencmsResource.backupFile(pProjectId, recFiles, vVersionId, pPublishDate);
        END IF;
      -- resource is changed
      ELSIF recFiles.state = opencmsConstants.C_STATE_CHANGED THEN
        -- does the folder exist in the online-project?
        curNewFile := opencmsResource.readFileNoAccess(pUserId, pOnlineProjectId, pOnlineProjectId, recFiles.resource_name);
        FETCH curNewFile INTO recNewFile;
        CLOSE curNewFile;
        -- folder does not exist in online-project => create folder
        IF recNewFile.resource_id IS NULL THEN
          BEGIN
            select resource_id into vParentId
                   from cms_online_resources
                   where resource_name = opencmsResource.getParent(recFiles.resource_name);
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              vParentId := opencmsConstants.C_UNKNOWN_ID;
          END;
          opencmsResource.createFile(pOnlineProjectId, pOnlineProjectId, recFiles, pUserId,
                                     vParentId, recFiles.resource_name, 'FALSE', curNewFile);
          FETCH curNewFile INTO recNewFile;
          CLOSE curNewFile;
          --recNewFile.state := opencmsConstants.C_STATE_UNCHANGED;
          --opencmsResource.writeFile(pOnlineProjectId, recNewFile, 'FALSE');
          update cms_online_resources set state = opencmsConstants.C_STATE_UNCHANGED 
                 where resource_id=recNewFile.resource_id;
        END IF;
        -- update the file in the online-project
        update cms_online_resources set
               resource_type = recFiles.resource_type,
               resource_flags = recFiles.resource_flags,
               user_id = recFiles.user_id,
               group_id = recFiles.group_id,
               project_id = pOnlineProjectId,
               access_flags = recFiles.access_flags,
               state = opencmsConstants.C_STATE_UNCHANGED,
               locked_by = recFiles.locked_by,
               launcher_type = recFiles.launcher_type,
               launcher_classname = recFiles.launcher_classname,
               date_lastmodified = sysdate,
               resource_lastmodified_by = recFiles.resource_lastmodified_by,
               resource_size = recFiles.resource_size
               where resource_id = recNewFile.resource_id;
        update cms_online_files set
               file_content = recFiles.file_content
               where file_id = recNewFile.file_id;
        commit;
        -- copy the properties
        delete from cms_online_properties where resource_id = recNewFile.resource_id;
        opencmsProperty.writeProperties(pOnlineProjectId, opencmsProperty.readAllProperties(pUserId, pProjectId, recFiles.resource_name),
                                        recNewFile.resource_id, recNewFile.resource_type);
        -- remember only one id for mark
        vCurWriteFiles := recNewFile.resource_id;
        IF pEnableHistory = 1 THEN
          -- backup the resource
          opencmsResource.backupFile(pProjectId, recFiles, vVersionId, pPublishDate);
        END IF;
      END IF;
    END LOOP;
    CLOSE curFiles;
    -- now remove the folders
    IF length(vDeletedFolders) > 0 THEN
      -- get the string for the cursor of
      vCurDelFolders := replace(substr(vDeletedFolders,2),'/',',');
      vDeletedFolders := vDeletedFolders||'/';
      LOOP
        vResourceId := substr(vDeletedFolders, instr(vDeletedFolders, '/', 1, 1)+1,
                       (instr(vDeletedFolders, '/', 1, 2) - (instr(vDeletedFolders, '/', 1, 1)+1)));
        vDeletedFolders := substr(vDeletedFolders, (instr(vDeletedFolders, '/', 1, 2)));
        BEGIN
          select resource_id, file_id into vResourceId, vFileId
                 from cms_online_resources
          		 where resource_name = (select resource_name from cms_resources where resource_id = vResourceId);
          delete from cms_online_properties where resource_id = vResourceId;
          delete from cms_online_resources where resource_id = vResourceId;
          delete from cms_online_files where file_id = vFileId;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            null;
        END;
        IF length(vDeletedFolders) <= 1 THEN
          EXIT;
        END IF;
      END LOOP;
      commit;
    END IF;
    -- build the cursors which are used in java for the discAccess
    BEGIN
      IF length(vCurDelFolders) > 0 THEN
        OPEN pCurDelFolders FOR 'select r.resource_name from cms_resources r, cms_projectresources p'||
                                ' where p.project_id = '||pProjectId||
                                ' and r.resource_name like concat(p.resource_name,''%'')'||
                                ' and resource_type = '||opencmsConstants.C_TYPE_FOLDER||
          						' and state = '||opencmsConstants.C_STATE_DELETED;
      ELSE
        -- return a cursor that contains no rows
        OPEN pCurDelFolders FOR 'select resource_name from cms_resources where 1=2';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20999, 'error open cursor pCurDelFolders: '||substr(vCurDelFolders,1,200));
    END;
    BEGIN
      IF length(vCurWriteFolders) > 0 THEN
        OPEN pCurWriteFolders FOR 'select r.resource_name from cms_resources r, cms_projectresources p'||
                                  ' where p.project_id = '||pProjectId||
                                  ' and r.resource_name like concat(p.resource_name,''%'')'||
        					      ' and resource_type = '||opencmsConstants.C_TYPE_FOLDER||
        						  ' and state in ('||opencmsConstants.C_STATE_NEW||', '||
        						                     opencmsConstants.C_STATE_CHANGED||')';

      ELSE
        -- return a cursor that contains no rows
        OPEN pCurWriteFolders FOR 'select resource_name from cms_resources where 1=2';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20999, 'error open cursor pCurWriteFolders: '||substr(vCurWriteFolders,2,200));
    END;
    BEGIN
      IF length(vCurDelFiles) > 0 THEN
        OPEN pCurDelFiles FOR 'select r.resource_name from cms_resources r, cms_projectresources p'||
                              ' where p.project_id = '||pProjectId||
                              ' and r.resource_name like concat(p.resource_name,''%'')'||
                              ' and resource_type != '||opencmsConstants.C_TYPE_FOLDER||
          					  ' and state = '||opencmsConstants.C_STATE_DELETED;
      ELSE
        -- return a cursor that contains no rows
        OPEN pCurDelFiles FOR 'select resource_name from cms_resources where 1=2';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20999, 'error open cursor pCurDelFiles: '||substr(vCurDelFiles,2,200));
    END;
    BEGIN
      IF length(vCurWriteFiles) > 0 THEN
        OPEN pCurWriteFiles FOR 'select r.resource_name, file_id from cms_resources r, cms_projectresources p'||
                                ' where p.project_id = '||pProjectId||
                                ' and r.resource_name like concat(p.resource_name,''%'')'||
                                ' and resource_type != '||opencmsConstants.C_TYPE_FOLDER||
          					    ' and state in ('||opencmsConstants.C_STATE_NEW||', '||
        						                   opencmsConstants.C_STATE_CHANGED||')';
      ELSE
        -- return a cursor that contains no rows
        OPEN pCurWriteFiles FOR 'select resource_name, file_id from cms_resources where 1=2';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20999, 'error open cursor pCurWriteFiles: '||substr(vCurWriteFiles,2,200));
    END;
  EXCEPTION
    WHEN OTHERS THEN
      rollback;
      IF curFolders%ISOPEN THEN
        CLOSE curFolders;
      END IF;
      IF curFiles%ISOPEN THEN
		CLOSE curFiles;
	  END IF;
      IF curNewFolder%ISOPEN THEN
        CLOSE curNewFolder;
      END IF;
      IF curNewFile%ISOPEN THEN
        CLOSE curNewFile;
      END IF;
      RAISE;
  END publishProject;
-----------------------------------------------------------------------------------------
-- returns a cursor with the online-project
-----------------------------------------------------------------------------------------
  FUNCTION onlineProject RETURN cms_projects%ROWTYPE IS
    recOnlineProject cms_projects%ROWTYPE;
  BEGIN
    select * into recOnlineProject from cms_projects
           where project_id = openCmsConstants.C_PROJECT_ONLINE_ID
           order by project_name;
    RETURN recOnlineProject;
  END onlineProject;
-----------------------------------------------------------------------------------------
-- returns a cursor with the online-project
-----------------------------------------------------------------------------------------
  FUNCTION onlineProject(pProjectId NUMBER) RETURN cms_projects%ROWTYPE IS
    curOnlineProject cms_projects%ROWTYPE;
    vCount NUMBER;
  BEGIN
/* for multisite now disabled
    -- read Online Project
    select count(*) into vCount from cms_projects p, cms_sites s
                                     where p.project_id = pProjectId
                                     and s.onlineproject_id = p.project_id;
    IF vCount > 0 THEN
      OPEN curOnlineProject FOR select p.* from cms_projects p, cms_sites s
                                         where p.project_id = pProjectId
                                         and s.onlineproject_id = p.project_id;
    ELSE
      -- read Parent Project
      select count(*) into vCount from cms_projects pp, cms_projects cp
                                  where cp.parent_id = pp.project_id
                                  and cp.project_id = pProjectId;
      IF vCount > 0 THEN
        OPEN curOnlineProject FOR select pp.* from cms_projects pp, cms_projects cp
                                           where cp.parent_id = pp.project_id
                                           and cp.project_id = pProjectId;
      ELSE
        -- read current Project
        OPEN curOnlineProject FOR select * from cms_projects where project_id = pProjectId;
      END IF;
    END IF;
*/
    select * into curOnlineProject from cms_projects
           where project_id = openCmsConstants.C_PROJECT_ONLINE_ID
           order by project_name;
    RETURN curOnlineProject;
  END onlineProject;
------------------------------------------------------------------------------------------
END ;
/
