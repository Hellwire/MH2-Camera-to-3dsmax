rollout CameraDataParser "Mh2 Cam Parser 1.5" (
    label lblInfo "Enter Vecpair strings:" align:#center
    label spacer1 "" height:10
    editText txtInput "" width:350 height:60 align:#center
    label spacer2 "" height:5
    checkbox chkDeleteOnReset "Delete cameras on reset" checked:true align:#center
    button btnreset "Reset" align:#center
    label spacer4 "" height:5
    button btnParse "Import Cameras" align:#center
    button btnExport "Export Selected to Clipboard" align:#center
    label spacer3 "" height:5
    label lblCredit "Coded by Hellwire/WhoIsPrice - Modified" align:#center

    global createdCameras = #()
    global cameraMetaData = #() -- handle: #(scale, lookDist, unknown, roll, hasAt)

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
        if selection.count == 1 and isKindOf selection[1] camera then (
            local cam = selection[1]
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
                setClipboardText exportStr
                messageBox "Camera data copied to clipboard!" title:"Success"
            ) else (
                messageBox "No metadata for selected camera." title:"Error"
            )
        ) else (
            messageBox "Select exactly one camera." title:"Error"
        )
    )

    on btnReset pressed do (
        txtInput.text = ""
        if chkDeleteOnReset.checked do deleteCreatedCameras()
    )
)

createDialog CameraDataParser width:402 height:230
