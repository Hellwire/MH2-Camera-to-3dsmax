utility Allen_Scripts "Allen's Manhunt 2 Scripts" 
(
	button script01 "MDL IO" width:140 align:#center 
	button script02 "IFP IO" width:140 align:#center 
	button script03 "COL IO" width:140 align:#center
	button script06 "BSP IO" width:140 align:#center
	button script07 "BSP READER" width:140 align:#center
	button script04 "TVP EDITOR" width:140 align:#center
	on script01 pressed do (
		try ( fileIn (scriptspath+"\\Manhunt2_Tools\\MDL_IO.ms") quiet:true   )
		catch messagebox "Please re-install my MDL IO script!" title:"Can't find MDL IO script"
	)
	on script02 pressed do(
		try (filein  (scriptspath+"\\Manhunt2_Tools\\IFP_IO.ms") quiet:true)
		catch messagebox "Please re-install my IFO IO script!" title:"Can't find IFO IO script"
	)
	on script03 pressed do (
		try ( fileIn (scriptspath+"\\Manhunt2_Tools\\COL_IO.ms") quiet:true   )
		catch messagebox "Please re-install my COL script!" title:"Can't find COL IO script"
	)
	on script04 pressed do (
		try ( fileIn (scriptspath+"\\Manhunt2_Tools\\CameraMh2.ms") quiet:true   )
		catch messagebox "Please re-install TVP Editor script!" title:"Can't find CameraMh2 script or script error"
	)
	on script06 pressed do (
		try ( fileIn (scriptspath+"\\Manhunt2_Tools\\MH2BSPIO.mse") quiet:true   )
		catch messagebox "Please re-install BSP Importer script!" title:"Can't find MH2BSPIO script or script error"
	)
	on script07 pressed do (
		try ( fileIn (scriptspath+"\\Manhunt2_Tools\\ReadBSP.ms") quiet:true   )
		catch messagebox "Please re-install Read BSP script!" title:"Can't find ReadBSP script or script error"
	)
	group "Manhunt 1"(
	button script05 "DFF Import" width:140 align:#center
	)	
	on script05 pressed do (
		try ( fileIn (scriptspath+"\\Manhunt2_Tools\\DFFUI.ms") quiet:true   )
		catch messagebox "Please re-install my DFF script!" title:"Can't find DFF script"		
	)
)
openUtility Allen_Scripts
