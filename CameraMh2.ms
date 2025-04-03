rollout CameraDataParser "Mh2 Cam Parser 1.3" (
    label lblInfo "Enter Vecpair string:" align:#center
    label spacer1 "" height:10
    editText txtInput "" width:350 height:10 align:#center
    label spacer2 "" height:5
	checkbox chkDeleteOnReset "Delete camera on reset" checked:true align:#center
    button btnreset "Reset" align:#center
    label spacer4 "" height:5
    button btnParse "Apply Camera Movements" align:#center
    button btnExport "Export Values to clipboard" align:#center
    label spacer3 "" height:5
    label lblCredit "Coded by Hellwire/WhoIsPrice" align:#center
    
    global importedCamera = undefined
    global vecpairScale = 1.0
    global originalLookAtDistance = 1.0
    global originalRoll = 0.0
    global originalUnknownValue = 0.5
    global hasAtSymbol = false
    global createdCameras = #() -- Array to store all created cameras
    
    fn deleteCreatedCameras = (
        for cam in createdCameras where isValidNode cam do (
            delete cam
        )
        createdCameras = #() -- Clear the array
        importedCamera = undefined -- Reset the global camera reference
    )
    
    on btnParse pressed do (
        global importedCamera, vecpairScale, originalLookAtDistance, originalRoll, originalUnknownValue, hasAtSymbol, createdCameras
        local inputData = txtInput.text
        local lines = filterString inputData "\n"
        
        -- Delete any existing cameras before creating new ones
        deleteCreatedCameras()
        
        importedCamera = freecamera()
        importedCamera.name = uniquename "ImportedCamera"
        append createdCameras importedCamera -- Add to tracking array
        select importedCamera 
        local firstPositionSet = false
    
        for line in lines do (
            local cleanLine = trimLeft line
            if matchPattern cleanLine pattern:"VECPAIR*" do (
                -- Check if line has @ symbol
                hasAtSymbol = matchPattern cleanLine pattern:"*@*"
                
                local tokens = filterString cleanLine " \t"
                if tokens.count >= 10 do (  
                    vecpairScale = tokens[2] as float
                    local posX = tokens[3] as float
                    local posY = tokens[4] as float
                    local posZ = tokens[5] as float
                    local lookAtX = tokens[6] as float
                    local lookAtY = tokens[7] as float
                    local lookAtZ = tokens[8] as float
                    originalUnknownValue = tokens[9] as float
                    originalRoll = tokens[10] as float
                
                    if not firstPositionSet then (
                        importedCamera.position = [posX, posY, posZ]
                        local targetPos = [lookAtX, lookAtY, lookAtZ]
                        originalLookAtDistance = length (targetPos - importedCamera.position)
                        local forwardVec = normalize (importedCamera.position - targetPos)
                        local upVec = [0, 0, 1]
                        local rightVec = normalize (cross upVec forwardVec)
                        upVec = cross forwardVec rightVec
                        importedCamera.transform = matrix3 rightVec upVec forwardVec importedCamera.position
                        firstPositionSet = true
                    )
                )
            )
        )
    )
    
    on btnExport pressed do (
        if importedCamera != undefined and isValidNode importedCamera then (
            local pos = importedCamera.position
            local forwardVec = -normalize (importedCamera.transform.row3)
            local lookAt = pos + (forwardVec * originalLookAtDistance)
            
            local vecpairPrefix = "VECPAIR"
            if hasAtSymbol then vecpairPrefix += "@"
            
            local exportString = vecpairPrefix + " " + (vecpairScale as string) + " " + 
                              (pos.x as string) + " " + (pos.y as string) + " " + (pos.z as string) + " " + 
                              (lookAt.x as string) + " " + (lookAt.y as string) + " " + (lookAt.z as string) + " " + 
                              (originalUnknownValue as string) + " " + (originalRoll as string)
            
            -- Preserve tab before vecpair strings if original had one
            if matchPattern txtInput.text pattern:"*\tVECPAIR*" do (
                exportString = "\t" + exportString
            )
            
            setClipboardText exportString
            messageBox "Camera values copied to clipboard!" title:"Export Success"
        ) else (
            messageBox "No imported camera found for export." title:"Error"
        )
    )
    
    on btnReset pressed do (
        txtInput.text = ""  
        hasAtSymbol = false
		if chkDeleteOnReset.checked do (
			deleteCreatedCameras()
		)	
    )
)
createDialog CameraDataParser width:402 height:200
