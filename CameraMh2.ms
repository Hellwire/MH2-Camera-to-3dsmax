rollout CameraDataParser "Manhunt TVP Editor 2.1" (
    -- UI Elements
	-- Developed by Hellwire, Big thanks to EERD Dev too (Paulie aka givemeanumber aka restinpeace) aswell as Razormoon dev (chorpthon aka n4amel3ss)
    group "Legacy Controls" (
		label lblInfo "Enter Vecpair strings:" align:#center
		label spacer1 "" height:0.5
		editText txtInput "" width:380 height:90 align:#center tooltip:"copy/paste the vecpair lines here or use the file import"
		button btnCreateHelper "Add Helper" align:#center width:90 height:25 tooltip:"Adds a helper object for easy navigation in viewport" across:4	
		button btnreset "Reset Tool" align:#center width:90 height:25 tooltip:"Resets the whole TVP Tool."
		button btnclearlegacytxt "Clear Field" align:#center width:90 height:25 tooltip:"Clears the legacy input field"
		button btnDeleteAllCams "Delete Cameras" align:#center width:90 height:25 tooltip:"Deletes all cameras in the scene (any camera object)."
		label spacer4 "" height:1
        button btnParse "Import Cameras" width:120 height:25 across:3 tooltip:"Imports cameras from textfield to the 3dsmax scene"
        button btnSelectAll "Select All" width:120 height:25 tooltip:"Select all cameras in current 3dsmax scene"
        button btnExport "Export Selected" width:120 height:25 tooltip:"Export all cameras in current scene to clipboard for copy/paste"
    )

    group "File Import/Export" (
        button btnImportFile "Load GLG/INI File..." width:150 height:20 align:#center tooltip:"Import TVP file for manipulation directly"
		label lblRecSearch "Search in Records:" align:#center 
        editText txtRecordSearch "" width:200 height:18 align:#center tooltip:"Search records" tooltip:"Search in execution records..."
        dropdownlist ddlRecords "Records" width:160 height:18 align:#center tooltip:"Select execution record..." across:2
        dropdownlist ddlAngleSets "Angle Sets" width:100 height:18 align:#center tooltip:"Select angle set from execution record. These are used for fallback if angle before is blocked ingame."
        
        button btnImportAngleSet "Import Set to 3ds" width:120 height:25 align:#center across:2 tooltip:"Import from Loaded Cam Data to 3dsmax scene"
        button btnReplaceAngleSet "Replace Set in File" width:120 height:25 align:#center tooltip:"Replace cam data from current 3dsmax scene directly back to imported file. Will overwrite record that is currenty loaded in camera data from import!"
        button btnAddAngleSet "Add Set to File" width:120 height:25 align:#center tooltip:"Adds the current cameras as a new angle set to the selected record" across:2
        button btnDeleteAngleSet "Delete Angle Set" width:120 height:25 align:#center tooltip:"Delete camera angle set from imported file "
        checkbox chkBackup "Create Backup (.bak)" checked:true align:#center tooltip:"Toggle backup creation when replacing angle sets"
        label lblwarn1 "Make sure you always have a backup!" align:#center
    )

    group "Loaded Camera Data" (
        label lblCurrentRecord "Record: None" align:#left across:2
        label lblCameraCount "Cameras: 0" align:#right
        label lblCurrentAngleSet "Angle Set: None" align:#left offset:[0,5]
        label lblPreview "Angle Set Preview:" align:#left
        editText txtAngleSetPreview "" height:80 width:380 readOnly:true 
    )

    label lblCredit "Coded by Hellwire/WhoIsPrice" align:#center


    -- Global Variables
    global createdCameras = #()
    global cameraMetaData = #()
    global parsedRecords = #()
    global currentAngleSets = #()
    global cameraHelperObj = undefined
    global allRecordNames = #()
    global filteredRecordIndices = #()
    global currentGLGFilePath = undefined

    -- Utility Functions
    fn joinString arr delimiter = (
        local str = ""
        for i = 1 to arr.count do (
            str += arr[i]
            if i < arr.count do str += delimiter
        )
        return str
    )

	fn deleteAllCameras = (
        -- Delete all camera objects in the scene
        local allCams = for obj in objects where (isKindOf obj camera) collect obj
        for cam in allCams do (
            if isValidNode cam do delete cam
        )
        
        -- Clear tool's camera tracking
        createdCameras = #()
        cameraMetaData = #()
    )
	
	fn resetTool = (
        -- Clear text fields
        txtInput.text = ""
        txtRecordSearch.text = ""
        txtAngleSetPreview.text = ""
        
        -- Reset file import state
        currentGLGFilePath = undefined
        parsedRecords = #()
        allRecordNames = #()
        filteredRecordIndices = #()
        currentAngleSets = #()
        
        -- Update UI elements
        ddlRecords.items = #()
        ddlRecords.selection = 0
        ddlAngleSets.items = #()
        ddlAngleSets.selection = 0
        lblCurrentRecord.text = "Record: None"
        lblCurrentAngleSet.text = "Angle Set: None"
        lblCameraCount.text = "Cameras: 0"
        for cam in createdCameras where isValidNode cam do delete cam
        createdCameras = #()
        cameraMetaData = #()
        -- Delete camera helper if exists
        if isValidNode cameraHelperObj do (
            delete cameraHelperObj
            cameraHelperObj = undefined
        )
    )
	
    fn deleteCreatedCameras = (
        for cam in createdCameras where isValidNode cam do delete cam
        createdCameras = #()
        cameraMetaData = #()
    )

	fn updateCameraDataDisplay = (
        if ddlRecords.selection == 0 or ddlAngleSets.selection == 0 then (
            lblCurrentRecord.text = "Record: None"
            lblCurrentAngleSet.text = "Angle Set: None"
            lblCameraCount.text = "Cameras: 0"
            txtAngleSetPreview.text = ""
        ) else (
            local actualRecordIndex = if filteredRecordIndices.count > 0 then 
                filteredRecordIndices[ddlRecords.selection] 
            else 
                ddlRecords.selection
            
            local record = parsedRecords[actualRecordIndex]
            local recordName = record[1]
            local angleSetIndex = ddlAngleSets.selection
            local angleSet = record[2][angleSetIndex]
            local numCameras = angleSet.count

            lblCurrentRecord.text = "Record: " + recordName
            lblCurrentAngleSet.text = "Angle Set: " + (angleSetIndex as string)
            lblCameraCount.text = "Cameras: " + (numCameras as string)
            -- Create preview text (show first 5 cameras or all if less than 5)
            local previewLines = for i = 1 to (amin 5 numCameras) collect angleSet[i]
            txtAngleSetPreview.text = joinString previewLines "\n"
            if numCameras > 5 then (
                txtAngleSetPreview.text += "\n... and " + (numCameras - 5) as string + " more"
            )
        )
    )
	
    -- Parsing and Camera Creation
    fn parseVecpairLine line = (
        local hasAtSymbol = matchPattern line pattern:"*@*"
        local tokens = filterString (trimLeft line) " \t"
        if tokens.count >= 10 then (
            local vecpairScale = tokens[2] as float
            local posX = tokens[3] as float
            local posY = tokens[4] as float
            local posZ = tokens[5] as float
            local lookAtX = tokens[6] as float
            local lookAtY = tokens[7] as float
            local lookAtZ = tokens[8] as float
            local unknownVal = tokens[9] as float
            local rollVal = tokens[10] as float

            local cam = freecamera()
            cam.name = uniquename "ExecutionCamera"
            cam.position = [posX, posY, posZ]
            cam.wirecolor = random (color 50 50 50) (color 255 255 255)

            local targetPos = [lookAtX, lookAtY, lookAtZ]
            local lookDist = length (targetPos - cam.position)
            local forwardVec = normalize (cam.position - targetPos)
            local upVec = [0,0,1]
            local rightVec = normalize (cross upVec forwardVec)
            upVec = cross forwardVec rightVec
            cam.transform = matrix3 rightVec upVec forwardVec cam.position

            append createdCameras cam
            local handle = getHandleByAnim cam
            cameraMetaData[handle] = #(vecpairScale, lookDist, unknownVal, rollVal, hasAtSymbol)
        )
    )

    -- Original export function for clipboard (adds a tab)
    fn getExportStringsFromCameras cameras = (
        local exportStrings = #()
        for cam in cameras do (
            local handle = getHandleByAnim cam
            if cameraMetaData[handle] != undefined then (
                local meta = cameraMetaData[handle]
                local pos = cam.position
                local forwardVec = -normalize (cam.transform.row3)
                local lookAt = pos + (forwardVec * meta[2])
                local prefix = if meta[5] then "VECPAIR@" else "VECPAIR"
                local exportStr = "\t" + prefix + " " + (meta[1] as string) + " " +
                    (pos.x as string) + " " + (pos.y as string) + " " + (pos.z as string) + " " +
                    (lookAt.x as string) + " " + (lookAt.y as string) + " " + (lookAt.z as string) + " " +
                    (meta[3] as string) + " " + (meta[4] as string)
                append exportStrings exportStr
            )
        )
        return exportStrings
    )

    -- Corrected export function for file writing (no added indentation)
    fn getExportStringsFromCameras2 cameras = (
        local exportStrings = #()
        for cam in cameras do (
            local handle = getHandleByAnim cam
            if cameraMetaData[handle] != undefined then (
                local meta = cameraMetaData[handle]
                local pos = cam.position
                local forwardVec = -normalize (cam.transform.row3)
                local lookAt = pos + (forwardVec * meta[2])
                local prefix = if meta[5] then "VECPAIR@" else "VECPAIR"
                local exportStr = prefix + " " + (meta[1] as string) + " " +
                    (pos.x as string) + " " + (pos.y as string) + " " + (pos.z as string) + " " +
                    (lookAt.x as string) + " " + (lookAt.y as string) + " " + (lookAt.z as string) + " " +
                    (meta[3] as string) + " " + (meta[4] as string)
                append exportStrings exportStr
            )
        )
        return exportStrings
    )
    
    -- File writing function to replace an existing angle set
    fn replaceAngleSetInFile filePath recordIndex angleSetIndex newAngleSet = (
        try (
            local file = openFile filePath mode:"r"
            if file == undefined then (messageBox "Cannot open source file"; return false)
            local fileLines = #()
            while not eof file do (append fileLines (readLine file))
            close file

            local currentRecordIndex = 0, recordStartLine = 0, recordEndLine = 0, recordIndent = ""
            for i = 1 to fileLines.count do (
                local line = fileLines[i]
                local trimmed = trimLeft line
                if matchPattern trimmed pattern:"RECORD*" then (
                    currentRecordIndex += 1
                    if currentRecordIndex == recordIndex then (
                        recordStartLine = i
                        recordIndent = substring line 1 (line.count - trimmed.count)
                    ) else if recordStartLine > 0 and recordEndLine == 0 then (
                        recordEndLine = i - 1; exit
                    )
                )
                if matchPattern trimmed pattern:"END" and recordStartLine > 0 and recordEndLine == 0 and currentRecordIndex == recordIndex then (
                    recordEndLine = i; exit
                )
            )
            if recordStartLine > 0 and recordEndLine == 0 then recordEndLine = fileLines.count

            if recordStartLine == 0 or recordEndLine == 0 then (
                messageBox "Could not locate the record's boundaries in the file!" title:"Error"
                return false
            )

            if recordIndex > parsedRecords.count then (messageBox "Record index out of bounds."; return false)
            local originalAngleSets = parsedRecords[recordIndex][2]
            
            if angleSetIndex < 1 or angleSetIndex > originalAngleSets.count then (
                 messageBox ("Invalid angle set index selected ("+angleSetIndex as string+"). Record only has " + originalAngleSets.count as string + " sets.") title:"Error"
                 return false
            )

            local newRecordContent = #()
            for i = 1 to originalAngleSets.count do (
                if i == angleSetIndex then (
                     for line in newAngleSet do (
                         append newRecordContent (recordIndent + "\t" + line)
                     )
                ) else (
                     for line in originalAngleSets[i] do (
                         append newRecordContent line
                     )
                )
            )
            
            local finalFileLines = #()
            for i = 1 to recordStartLine - 1 do append finalFileLines fileLines[i]
            append finalFileLines fileLines[recordStartLine]
            for line in newRecordContent do append finalFileLines line
            append finalFileLines fileLines[recordEndLine]
            for i = recordEndLine + 1 to fileLines.count do append finalFileLines fileLines[i]

            if chkBackup.checked do (
                if not (copyFile filePath (filePath + ".bak")) then (
                    messageBox "Failed to create backup file!" title:"Error"; return false
                )
            )
            
            local outFile = createFile filePath
            if outFile == undefined then (
                messageBox "Failed to create output file for writing!" title:"Error"; return false
            )
            
            for line in finalFileLines do (format "%\n" line to:outFile)
            close outFile
            
            return true
        )
        catch (
            messageBox ("An unexpected error occurred in replaceAngleSetInFile: " + getCurrentException()) title:"Critical Error"
            return false
        )
    )

    fn addAngleSetToFile filePath recordIndex newAngleSet = (
        try (
            local file = openFile filePath mode:"r"
            if file == undefined then (messageBox "Cannot open source file"; return false)
            local fileLines = #()
            while not eof file do (append fileLines (readLine file))
            close file

            local currentRecordIndex = 0, recordStartLine = 0, recordEndLine = 0, recordIndent = ""
            for i = 1 to fileLines.count do (
                local line = fileLines[i]
                local trimmed = trimLeft line
                if matchPattern trimmed pattern:"RECORD*" then (
                    currentRecordIndex += 1
                    if currentRecordIndex == recordIndex then (
                        recordStartLine = i
                        recordIndent = substring line 1 (line.count - trimmed.count)
                    ) else if recordStartLine > 0 and recordEndLine == 0 then (
                        recordEndLine = i - 1; exit
                    )
                )
                if matchPattern trimmed pattern:"END" and recordStartLine > 0 and recordEndLine == 0 and currentRecordIndex == recordIndex then (
                    recordEndLine = i; exit
                )
            )
            if recordStartLine > 0 and recordEndLine == 0 then recordEndLine = fileLines.count

            if recordStartLine == 0 or recordEndLine == 0 then (
                messageBox "Could not locate the record's boundaries to add a new set." title:"Error"
                return false
            )
            
            local newAngleSetContent = #()
            for line in newAngleSet do (
                append newAngleSetContent (recordIndent + "\t" + line)
            )

            local part1 = for i = 1 to (recordEndLine - 1) collect fileLines[i]
            local part2 = for i = recordEndLine to fileLines.count collect fileLines[i]
            local finalFileLines = part1 + newAngleSetContent + part2
            
            if chkBackup.checked do (
                if not (copyFile filePath (filePath + ".bak")) then (
                    messageBox "Failed to create backup file!" title:"Error"; return false
                )
            )

            local outFile = createFile filePath
            if outFile == undefined then (
                messageBox "Failed to create output file for writing!" title:"Error"; return false
            )
            
            for line in finalFileLines do (format "%\n" line to:outFile)
            close outFile
            
            return true
        )
        catch(
            messageBox ("An unexpected error occurred in addAngleSetToFile: " + getCurrentException()) title:"Critical Error"
            return false
        )
    )

    -- *** NEW FUNCTION *** to delete an angle set from a record
    fn deleteAngleSetFromFile filePath recordIndex angleSetIndexToDelete = (
        try (
            local file = openFile filePath mode:"r"
            if file == undefined then (messageBox "Cannot open source file"; return false)
            local fileLines = #()
            while not eof file do (append fileLines (readLine file))
            close file

            local currentRecordIndex = 0, recordStartLine = 0, recordEndLine = 0, recordIndent = ""
            for i = 1 to fileLines.count do (
                local line = fileLines[i]
                local trimmed = trimLeft line
                if matchPattern trimmed pattern:"RECORD*" then (
                    currentRecordIndex += 1
                    if currentRecordIndex == recordIndex then (
                        recordStartLine = i
                        recordIndent = substring line 1 (line.count - trimmed.count)
                    ) else if recordStartLine > 0 and recordEndLine == 0 then (
                        recordEndLine = i - 1; exit
                    )
                )
                if matchPattern trimmed pattern:"END" and recordStartLine > 0 and recordEndLine == 0 and currentRecordIndex == recordIndex then (
                    recordEndLine = i; exit
                )
            )
            if recordStartLine > 0 and recordEndLine == 0 then recordEndLine = fileLines.count
            if recordStartLine == 0 or recordEndLine == 0 then (
                messageBox "Could not locate the record's boundaries for deletion!" title:"Error"
                return false
            )

            if recordIndex > parsedRecords.count then (messageBox "Record index out of bounds."; return false)
            local originalAngleSets = parsedRecords[recordIndex][2]
            
            if angleSetIndexToDelete < 1 or angleSetIndexToDelete > originalAngleSets.count then (
                 messageBox ("Invalid angle set index selected for deletion ("+angleSetIndexToDelete as string+").") title:"Error"
                 return false
            )

            local newRecordContent = #()
            for i = 1 to originalAngleSets.count do (
                if i != angleSetIndexToDelete then (
                     for line in originalAngleSets[i] do (
                         append newRecordContent line
                     )
                )
            )
            
            local finalFileLines = #()
            for i = 1 to recordStartLine - 1 do append finalFileLines fileLines[i]
            append finalFileLines fileLines[recordStartLine]
            for line in newRecordContent do append finalFileLines line
            append finalFileLines fileLines[recordEndLine]
            for i = recordEndLine + 1 to fileLines.count do append finalFileLines fileLines[i]

            if chkBackup.checked do (
                if not (copyFile filePath (filePath + ".bak")) then (
                    messageBox "Failed to create backup file!" title:"Error"; return false
                )
            )
            
            local outFile = createFile filePath
            if outFile == undefined then (
                messageBox "Failed to create output file for writing!" title:"Error"; return false
            )
            
            for line in finalFileLines do (format "%\n" line to:outFile)
            close outFile
            
            return true
        )
        catch (
            messageBox ("An unexpected error occurred in deleteAngleSetFromFile: " + getCurrentException()) title:"Critical Error"
            return false
        )
    )

    -- File parsing logic
    fn parseGlgFileContents fileContents = (
        parsedRecords = #()
        allRecordNames = #()
        local lines = filterString fileContents "\r\n"
        local lineNum = 0
        while lineNum < lines.count do(
            lineNum+=1
            local line = lines[lineNum]
            if matchpattern (trimLeft line) pattern:"RECORD*" then(
                local tokens = filterString line " \t"
                local recordName = if tokens.count > 1 then tokens[2] else "Unnamed Record"
                local newRecord = #(recordName, #())
                
                local recordContent = #()
                while lineNum < lines.count do(
                    lineNum+=1
                    line = lines[lineNum]
                    if matchpattern (trimLeft line) pattern:"END" then exit
                    append recordContent line
                )
                
                local angleSets = #()
                local currentSet = #()
                for contentLine in recordContent do(
                    local trimmedLine = trimLeft contentLine
                    if matchpattern trimmedLine pattern:"VECPAIR*" do(
                        append currentSet contentLine
                        if matchpattern trimmedLine pattern:"*@*" then(
                            append angleSets currentSet
                            currentSet = #()
                        )
                    )
                )
                if currentSet.count > 0 do append angleSets currentSet
                newRecord[2] = angleSets
                
                append parsedRecords newRecord
                append allRecordNames recordName
            )
        )

        ddlRecords.items = allRecordNames
        ddlAngleSets.items = #()
        filteredRecordIndices = #()
        txtRecordSearch.text = ""
    )
    
    -- Helper function for loading and parsing the file logic
    fn loadFile filePath = (
        if filePath != undefined and doesFileExist filePath then(
            currentGLGFilePath = filePath
            local fileStream = openFile filePath mode:"r"
            if fileStream != undefined then(
                local fileContents = ""
                while not eof fileStream do(
                     fileContents += readLine fileStream + "\r\n"
                )
                close fileStream
                parseGlgFileContents fileContents
            ) else(
                messageBox ("Could not open the selected file: " + filePath) title:"File Error"
            )
        )
    )

    -- UI Event Handlers
    on btnParse pressed do (
        if txtInput.text == "" then (
            messageBox "Please enter some Vecpair lines to import." title:"Input Error"
        ) else (
            deleteCreatedCameras()
            local lines = filterString txtInput.text "\r\n"
            for line in lines where matchPattern (trimLeft line) pattern:"VECPAIR*" do (
                parseVecpairLine line
            )
            if createdCameras.count > 0 then (
                select createdCameras
            )
        )
    )

    on btnExport pressed do (
        local selectedCameras = for obj in selection where isKindOf obj camera collect obj
        if selectedCameras.count > 0 then (
            local exportStrings = getExportStringsFromCameras selectedCameras
            if exportStrings.count > 0 then (
                setClipboardText (joinString exportStrings "\r\n")
                messageBox ((exportStrings.count as string) + " camera(s) exported to clipboard!") title:"Success"
            ) else (
                messageBox "No metadata found for selected cameras." title:"Error"
            )
        ) else (
            messageBox "Please select one or more cameras to export." title:"Error"
        )
    )

    on btnReplaceAngleSet pressed do (
        if currentGLGFilePath == undefined then (
            messageBox "No GLG file loaded!" title:"Error"
            return undefined
        )
        
        if ddlRecords.selection == 0 then (
            messageBox "Please select a record first!" title:"Error"
            return undefined
        )
        
        if ddlAngleSets.selection == 0 then (
            messageBox "Please select an angle set first!" title:"Error"
            return undefined
        )
        
        if createdCameras.count > 0 do (
            select (for cam in createdCameras where isValidNode cam collect cam)
        )
        
        local selectedCameras = for obj in selection where isKindOf obj camera collect obj
        if selectedCameras.count == 0 then (
            messageBox "There are no imported cameras to use for replacement!" title:"Error"
            return undefined
        )
        
        local actualRecordIndex = if filteredRecordIndices.count > 0 then 
            filteredRecordIndices[ddlRecords.selection] 
        else 
            ddlRecords.selection
        
        local angleSetIndex = ddlAngleSets.selection
        
        local exportStrings = getExportStringsFromCameras2 selectedCameras
        
        if exportStrings.count > 0 then (
            local backupWasEnabled = chkBackup.checked
            local result = replaceAngleSetInFile currentGLGFilePath actualRecordIndex angleSetIndex exportStrings
            if result then (
                messageBox ("Successfully replaced angle set " + angleSetIndex as string + " in\n" + currentGLGFilePath as string) title:"Success"
                loadFile(currentGLGFilePath)
                if backupWasEnabled then chkBackup.checked = false
            )
        ) else (
            messageBox "No valid camera data to export!" title:"Error"
        )
    )

	on btnDeleteAllCams pressed do (
        deleteAllCameras()
    )
	
    on btnAddAngleSet pressed do (
        if currentGLGFilePath == undefined then (
            messageBox "No GLG file loaded!" title:"Error"
            return undefined
        )
        
        if ddlRecords.selection == 0 then (
            messageBox "Please select a record first!" title:"Error"
            return undefined
        )
        
        if createdCameras.count > 0 do (
            select (for cam in createdCameras where isValidNode cam collect cam)
        )
        
        local selectedCameras = for obj in selection where isKindOf obj camera collect obj
        if selectedCameras.count == 0 then (
            messageBox "There are no imported cameras to add as a new angle set!" title:"Error"
            return undefined
        )
        
        local actualRecordIndex = if filteredRecordIndices.count > 0 then 
            filteredRecordIndices[ddlRecords.selection] 
        else 
            ddlRecords.selection
            
        local exportStrings = getExportStringsFromCameras2 selectedCameras
        
        if exportStrings.count > 0 then (
            local backupWasEnabled = chkBackup.checked
            local result = addAngleSetToFile currentGLGFilePath actualRecordIndex exportStrings
            if result then (
                local recordName = parsedRecords[actualRecordIndex][1]
                messageBox ("Successfully added new angle set to record '" + recordName + "'.") title:"Success"
                loadFile(currentGLGFilePath)
                if backupWasEnabled then chkBackup.checked = false
            )
        ) else (
            messageBox "No valid camera data to export!" title:"Error"
        )
    )

    -- *** NEW EVENT HANDLER *** for the delete angle set button
    on btnDeleteAngleSet pressed do (
        if currentGLGFilePath == undefined then (
            messageBox "No GLG/INI file loaded!" title:"Error"
            return undefined
        )
        
        if ddlRecords.selection == 0 then (
            messageBox "Please select a record first!" title:"Error"
            return undefined
        )

        if ddlAngleSets.selection == 0 then (
            messageBox "Please select an angle set to delete!" title:"Error"
            return undefined
        )
        
        local actualRecordIndex = if filteredRecordIndices.count > 0 then 
            filteredRecordIndices[ddlRecords.selection] 
        else 
            ddlRecords.selection

        local angleSetIndex = ddlAngleSets.selection
        local recordName = ddlRecords.items[ddlRecords.selection]
        local angleSetName = ddlAngleSets.items[ddlAngleSets.selection]
        
        if (queryBox ("Are you sure you want to permanently delete\n'" + angleSetName + "' from record '" + recordName + "'?") title:"Confirm Deletion") then(
            local backupWasEnabled = chkBackup.checked
            local result = deleteAngleSetFromFile currentGLGFilePath actualRecordIndex angleSetIndex
            if result then (
                messageBox ("Successfully deleted " + angleSetName + " from record '" + recordName + "'.") title:"Success"
                loadFile(currentGLGFilePath)
                if backupWasEnabled then chkBackup.checked = false
            )
        )
    )

    on btnCreateHelper pressed do (
        if isValidNode cameraHelperObj then (
            rollout errorRolloutHelper "Helper Already Exists" (
                label lblMsg "A helper is already present." align:#center
                button btnDeleteHelper "Delete Helper" width:120 align:#center
                button btnOkayHelper "Okay" width:120 align:#center
                
                on btnOkayHelper pressed do (
                    DestroyDialog errorRolloutHelper
                )
                
                on btnDeleteHelper pressed do (
                    if isValidNode cameraHelperObj do (
                        delete cameraHelperObj
                        cameraHelperObj = undefined
                        destroyDialog errorRolloutHelper
                    )
                )
            )
            createDialog errorRolloutHelper width:200 height:100
        ) else (
            cameraHelperObj = cylinder()
            cameraHelperObj.name = "Viewport Helper Object"
            cameraHelperObj.radius = 0.02
            cameraHelperObj.height = 1.652
            cameraHelperObj.pos = [0,0,0]
            cameraHelperObj.wirecolor = color 255 0 0
            select cameraHelperObj
        )
    )

    on btnreset pressed do (	
        resetTool()
    )
    
    on btnImportFile pressed do (
        local filePath = getOpenFileName caption:"Select Camera Data File" types:"Camera Data (*.glg, *.ini)|*.glg;*.ini|All Files (*.*)|*.*|"
        if filePath != undefined do (
            loadFile(filePath)
        )
    )

    on ddlRecords selected sel do (
        local actualIndex = if filteredRecordIndices.count > 0 then 
            filteredRecordIndices[sel] 
        else 
            sel
        
        if actualIndex > 0 and actualIndex <= parsedRecords.count do (
            local record = parsedRecords[actualIndex]
            local angleSets = record[2]
            currentAngleSets = for i = 1 to angleSets.count collect ("Angle Set " + i as string)
            ddlAngleSets.items = currentAngleSets
            if currentAngleSets.count > 0 then ddlAngleSets.selection = 1
        )
		updateCameraDataDisplay()
    )

    on btnImportAngleSet pressed do (
        if parsedRecords.count > 0 and ddlRecords.selection > 0 and ddlAngleSets.selection > 0 do (
            local actualIndex = if filteredRecordIndices.count > 0 then 
                filteredRecordIndices[ddlRecords.selection] 
            else 
                ddlRecords.selection
            
            local selectedRecord = parsedRecords[actualIndex]
            local angleSetIndex = ddlAngleSets.selection
            if angleSetIndex <= selectedRecord[2].count do (
                deleteCreatedCameras()
                local angleSetLines = selectedRecord[2][angleSetIndex]
                for line in angleSetLines do (
                    parseVecpairLine line
                )
                if createdCameras.count > 0 then (
                    select createdCameras
                    txtInput.text = joinString angleSetLines "\r\n"
                )
            )
        )
		if currentGLGFilePath == undefined then (
            messageBox "No GLG file loaded!" title:"Error"
            return undefined
        )
        
        if ddlRecords.selection == 0 then (
            messageBox "Please select a record first!" title:"Error"
            return undefined
        )
        
        if ddlAngleSets.selection == 0 then (
            messageBox "Please select an angle set first!" title:"Error"
            return undefined
        )
		
		updateCameraDataDisplay()	
    )

    on btnSelectAll pressed do (
        if createdCameras.count > 0 then (
            select (for cam in createdCameras where isValidNode cam collect cam)
        ) else (
            messageBox "No cameras have been imported yet." title:"Error"
        )
    )

	on btnclearlegacytxt pressed do (
        txtInput.text = ""
    )
	
    on txtRecordSearch changed searchText do (
        if allRecordNames.count > 0 do (
            local filteredNames = #()
            filteredRecordIndices = #()
            
            for i = 1 to allRecordNames.count do (
                if matchPattern (toLower allRecordNames[i]) pattern:("*" + toLower searchText + "*") then (
                    append filteredNames allRecordNames[i]
                    append filteredRecordIndices i
                )
            )
            
            ddlRecords.items = filteredNames
            if filteredNames.count > 0 then ddlRecords.selection = 1
            else ddlAngleSets.items = #()
        )
    )
)

createDialog CameraDataParser width:420 height:650
