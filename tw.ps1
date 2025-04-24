$TeamSpiderCount = 6
$TeamTerrierCount = 2
$TeamLancCount = 2
$TeamSharkCount = 2

# The bots will be generated with this base name as the first part with the number appended.
$BotBaseName = "Zero"
$BotPassword = "local"

# This is a hash table mapping player names to bot operator levels.
# Higher values will give more control over the bot.
$BotOperators = @{
	'monkey' = 10
	'taz' = 10
}

$MapFilename = "trench.lvl"
$ConfFilename = "tw.conf"

# This is the level file to download from the tw download site.
$DownloadMapName = "trench.lvl"

# Set this to $false if you want to run a server manually (must be 127.0.0.1:5000).
$RunServer = $true

# This delay gives time for the server to startup before running the bots.
$StartupDelay = 3

$ServerPath = "./SubspaceServer-4.0.0-win-x64"
$ServerUrl = "https://github.com/gigamon-dev/SubspaceServer/releases/download/v4.0.0/SubspaceServer-4.0.0-win-x64.zip"
$PristineServerHash = "60B25B69E15BCA75D6CC5218FC344B2D96F86365A01172A626B4C6447D6C0EEA"

$BotUrl = "https://github.com/plushmonkey/zero/releases/download/v0.7/zero-0.7.zip"
$BotPath = "./zero-0.7"
$PristineBotHash = "7C9E78CA467192772C970079FBBA53F1F23A845C78E1D842316429439C3A3EBF"

##############################################

# This is needed to stop powershell from outputting as utf-16 and adding the encoding identifier.
$PSDefaultParameterValues['Out-File:Encoding'] = 'ascii'

if ($RunServer) {
	echo "Beginning startup. Add 127.0.0.1:5000 to zone list to play."
}

$ServerMapPath = "$($ServerPath)/maps/$($MapFilename)"
$BotMapPath = "$($BotPath)/zones/SSCU Trench Wars/$($MapFilename)"

$ServerCurrentMapPath = "$($ServerPath)/maps/_current_tw.lvl"

$ServerConfPath = "$($ServerPath)/conf/tw.conf"
$ArenaConfPath = "$($ServerPath)/arenas/tw/arena.conf"
$ServerGlobalConfPath = "$($ServerPath)/conf/global.conf"

if (-not (Test-Path -Path $ServerPath)) {
	$DownloadServer = $true

	if (Test-Path -Path "./server.zip") {
		$ServerHash = Get-FileHash -Path "./server.zip" -Algorithm SHA256
		$DownloadServer = $ServerHash.Hash -ne $PristineServerHash
	}

	if ($DownloadServer) {
		wget $ServerUrl -Outfile server.zip
	}
	
	Expand-Archive server.zip -DestinationPath .
	Rename-Item -Path "./win-x64" -NewName $ServerPath
  
  # Setup default arena because this was ran before the play script.
  $DefaultArenaConfPath = "$($ServerPath)/arenas/(default)/arena.conf"
  "" >> $DefaultArenaConfPath
	"#include conf/game.conf" >> $DefaultArenaConfPath
	
	"" >> $DefaultArenaConfPath
	"[General]" >> $DefaultArenaConfPath
	"DesiredPlaying = 1024" >> $DefaultArenaConfPath
	"MaxPlaying = 1024" >> $DefaultArenaConfPath
  
	# Reduce logging because terminals can be very slow to write with many bots.
	"" >> $ServerGlobalConfPath
	"[log_console]" >> $ServerGlobalConfPath
	"all = MWE" >> $ServerGlobalConfPath
	"" >> $ServerGlobalConfPath
	"[log_file]" >> $ServerGlobalConfPath
	"all = MWE" >> $ServerGlobalConfPath
}

if (-not (Test-Path -Path "$($ServerPath)/arenas/tw")) {
  # Copy the turf arena to the tw arena to act as a base.
  Copy-Item -Recurse -Path "$($ServerPath)/arenas/turf" -Destination "$($ServerPath)/arenas/tw"

  "" >> $ArenaConfPath
  "#include conf/tw.conf" >> $ArenaConfPath

  "" >> $ArenaConfPath
  "[General]" >> $ArenaConfPath
  "DesiredPlaying = 1024" >> $ArenaConfPath
  "MaxPlaying = 1024" >> $ArenaConfPath
  
  "" >> $ArenaConfPath
	"[General]" >> $ArenaConfPath
	"Map = $($MapFilename)" >> $ArenaConfPath
}

if (-not (Test-Path -Path $BotPath)) {
	$DownloadBot = $true
	
	if (Test-Path -Path "./zero.zip") {
		$BotHash = Get-FileHash -Path "./zero.zip" -Algorithm SHA256
		$DownloadBot = $BotHash.Hash -ne $PristineBotHash
	}

	if ($DownloadBot) {
		wget $BotUrl -Outfile zero.zip
	}
	
	Expand-Archive zero.zip -DestinationPath .
}

if (-not (Test-Path -Path "./$($DownloadMapName)")) {
  wget "https://trenchwars.org/downloads/maps/browse2016/$($DownloadMapName)" -Outfile "$($DownloadMapName)"
}

if (-not (Test-Path -Path $ServerMapPath)) {
	Copy-Item -Path "./$($MapFilename)" -Destination $ServerMapPath
}

if (-not (Test-Path -Path $ServerCurrentMapPath)) {
	Copy-Item -Path "./$($MapFilename)" -Destination $ServerCurrentMapPath
	
	"" >> $ArenaConfPath
	"[General]" >> $ArenaConfPath
	"Map = $($MapFilename)" >> $ArenaConfPath
}

# If the defined map isn't the one set in config, append to config and set defined map as current.
if ((Get-FileHash "./$($MapFilename)").Hash -ne (Get-FileHash $ServerCurrentMapPath).Hash) {
	"" >> $ArenaConfPath
	"[General]" >> $ArenaConfPath
	"Map = $($MapFilename)" >> $ArenaConfPath
	
	Copy-Item -Path "./$($MapFilename)" -Destination $ServerCurrentMapPath
}

# If the current map isn't in the bot map folder or has changed, copy it over.
# This isn't strictly necessary, but it will stop all of the bots from having to download the map.
if ((-not (Test-Path -Path $BotMapPath)) -or (Get-FileHash "./$($MapFilename)").Hash -ne (Get-FileHash $BotMapPath).Hash) {
	# Create the file so it creates the directory structure
	New-Item -ItemType File -Path $BotMapPath -Force
	# Overwrite the empty file with the map.
	Copy-Item -Path "./$($MapFilename)" -Destination $BotMapPath
}

# Overwrite the conf file every run to make sure the currently defined one is set.
Copy-Item -Path "./$($ConfFilename)" -Destination $ServerConfPath
	
$BotRunFile = "$($BotPath)/run.bat"

# Delete the run file and make it again so we can easily change the number of bots.
if (Test-Path -Path $BotRunFile) {
	Remove-Item -Path $BotRunFile
}

function Generate-Bot-Type {
  param (
    $CurrentBotShip,
    $NameSuffix,
    $BehaviorName,
    $Index
  )
  
  $BotName = "$($BotBaseName)$($NameSuffix)"
	
	$ConfigFilename = "$($BotName).cfg"
	$ConfigPath = "$($BotPath)/$($ConfigFilename)"
		
	"start /B ./zero.exe $($ConfigFilename)" >> $BotRunFile
	
	if ($Index % 10 -eq 0) {
		$Delay = ($Index / 10) + 1
		"%WINDIR%\system32\timeout.exe /t $($Delay) /nobreak" >> $BotRunFile
	}
	
	# Delete the config and generate it again every run.
	# This is done to make sure any changed config values in this script are replicated.
	if (Test-Path -Path $ConfigPath) {
		Remove-Item -Path $ConfigPath
	}
	
	"[Login]" >> $ConfigPath
	"Username = $($BotName)" >> $ConfigPath
	"Password = $($BotPassword)" >> $ConfigPath
	"Server = TrenchWars" >> $ConfigPath
	"Encryption = Subspace" >> $ConfigPath
	"" >> $ConfigPath
	"[General]" >> $ConfigPath
	"LogLevel = Error" >> $ConfigPath
	"RequestShip = $($CurrentBotShip)" >> $ConfigPath
	"Behavior = $($BehaviorName)" >> $ConfigPath
  "Arena = tw" >> $ConfigPath
	""  >> $ConfigPath
	"[Servers]" >> $ConfigPath
	"TrenchWars = 127.0.0.1:5000" >> $ConfigPath
	""  >> $ConfigPath
	"[Operators]"  >> $ConfigPath
	foreach ($Operator in $BotOperators.Keys) {
		$OperatorLevel = $BotOperators[$Operator]
		"$($Operator) = $($OperatorLevel)"  >> $ConfigPath	
	}
}

# Generate the run.bat file and all of the config files for the bots.
for ($i = 1; $i -le ($TeamSpiderCount * 2); $i++) {
  Generate-Bot-Type -CurrentBotShip 3 -NameSuffix "Spider$($i)" -BehaviorName "spider" -Index $i
}

"%WINDIR%\system32\timeout.exe /t 3 /nobreak" >> $BotRunFile

for ($i = 1; $i -le ($TeamTerrierCount * 2); $i++) {
  Generate-Bot-Type -CurrentBotShip 5 -NameSuffix "Terrier$($i)" -BehaviorName "terrier" -Index $i
}

"%WINDIR%\system32\timeout.exe /t 3 /nobreak" >> $BotRunFile

for ($i = 1; $i -le ($TeamSharkCount * 2); $i++) {
  Generate-Bot-Type -CurrentBotShip 8 -NameSuffix "Shark$($i)" -BehaviorName "shark" -Index $i
}

"%WINDIR%\system32\timeout.exe /t 3 /nobreak" >> $BotRunFile

for ($i = 1; $i -le ($TeamLancCount * 2); $i++) {
  Generate-Bot-Type -CurrentBotShip 7 -NameSuffix "Lanc$($i)" -BehaviorName "spider" -Index $i
}

if ($RunServer) {
	# Begin running the server.
	Start-Process -FilePath powershell.exe "$($ServerPath)/run-server.ps1"
	#Start-Process -WorkingDirectory "./asss" -FilePath "./asss/asss.bat"
	# Delay long enough for the server to startup.
	powershell.exe "$($Env:windir)/system32/timeout.exe /t $($StartupDelay) /nobreak"
}

# Run the bots.
Start-Process -WorkingDirectory $BotPath -FilePath $BotRunFile
