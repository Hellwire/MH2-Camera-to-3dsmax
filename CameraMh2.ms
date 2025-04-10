rollout CameraDataParser "Mh2 Cam Parser 1.6" (
    label lblInfo "Enter Vecpair strings:" align:#center
    label spacer1 "" height:0.5
    editText txtInput "" width:350 height:90 align:#center
    label spacer2 "" height:5
    checkbox chkDeleteOnReset "Delete cameras on reset" checked:true align:#center
    button btnreset "Reset" align:#center width:50 height:30
    label spacer4 "" height:10
	
	group "Controls" (
		button btnParse "Import Cameras" align:#center width:150 height:20
		button btnExport "Export Selected to Clipboard" align:#center width:150 height:20
		button btnCreateHelper "Add Helper" width:100 height:20
	)
	label spacer3 "" height:5
    label lblCredit "Coded by Hellwire/WhoIsPrice" align:#center

    global createdCameras = #()
    global cameraMetaData = #() -- handle: #(scale, lookDist, unknown, roll, hasAt)

    -- Helper function to join strings with delimiter
    fn joinString arr delimiter = (
        local str = ""
        for i = 1 to arr.count do (
            str += arr[i]
            if i < arr.count do str += delimiter
        )
        return str
    )

    fn deleteCreatedCameras = (
        for cam in createdCameras where isValidNode cam do delete cam
        createdCameras = #()
        cameraMetaData = #()
    )

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
            cam.name = uniquename "ImportedCamera"
            cam.position = [posX, posY, posZ]

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

    on btnParse pressed do (
        local lines = filterString txtInput.text "\n"
        for line in lines where matchPattern (trimLeft line) pattern:"VECPAIR*" do (
            parseVecpairLine line
        )
        if createdCameras.count > 0 then select createdCameras
    )

    on btnExport pressed do (
        local selectedCameras = for obj in selection where isKindOf obj camera collect obj
        
        if selectedCameras.count > 0 then (
            local exportStrings = #()
            
            for cam in selectedCameras do (
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
            
            if exportStrings.count > 0 then (
                setClipboardText (joinString exportStrings "\n")
                messageBox ((exportStrings.count as string) + " camera(s) exported to clipboard!") title:"Success"
            ) else (
                messageBox "No metadata found for selected cameras." title:"Error"
            )
        ) else (
            messageBox "Please select one or more cameras to export." title:"Error"
        )
    )

    on btnCreateHelper pressed do (
        -- Create cylinder with specified dimensions at origin
        local helperCylinder = cylinder()
        helperCylinder.name = "CameraHelper"
        helperCylinder.radius = 0.02
        helperCylinder.height = 1.652
        helperCylinder.pos = [0,0,0]
        helperCylinder.wirecolor = color 255 0 0  -- Make it red for visibility
        
        -- Select the new helper
        select helperCylinder
    )

    on btnReset pressed do (
        txtInput.text = ""
        if chkDeleteOnReset.checked do deleteCreatedCameras()
    )
)

createDialog CameraDataParser width:402 height:340
