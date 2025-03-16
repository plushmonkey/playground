$BotCount = 12
# The bots will be generated with this base name as the first part with the number appended.
$BotBaseName = "ZeroBot"
$BotPassword = "local"
# The bot ship can be any value from 1 to 8 for standard ships.
# Set this value to 0 to have it be randomized for each generated bot.
$BotShip = 0

$MapFilename = "_bzw.lvl"
$ConfFilename = "chaos.conf"

# This is the defined server for the generated bots.
# Local, Subgame, Hyperspace, Devastation, MetalGear, ExtremeGames
# It will always point to 127.0.0.1, but zero is setup so each server name has a different set of behaviors.
# It's probably fine to keep it as Subgame with terrier as the behavior for most configs.
$BotBehaviorServer = "Subgame"
$BotBehavior = "terrier"

# Set this to $false if you want to run a server manually (must be 127.0.0.1:5000).
$RunServer = $true

# This delay gives time for the server to startup before running the bots.
$StartupDelay = 3

$ServerPath = "./SubspaceServer-3.0.0-win-x64"
$ServerUrl = "https://github.com/gigamon-dev/SubspaceServer/releases/download/v3.0.0/SubspaceServer-3.0.0-win-x64.zip"
$PristineServerHash = "7CE688FF50ECBDF9FFB5C4414F180D4AB60A88454F9507802ECBAB65EC10492F"

$BotUrl = "https://github.com/plushmonkey/zero/releases/download/v0.4/zero-0.4.zip"
$BotPath = "./zero-0.4"
$PristineBotHash = "C89544B7CBAD208C6D6F55D95FD29DA85C76C52B76672F37940953858EF8C693"

##############################################

# This is needed to stop powershell from outputting as utf-16 and adding the encoding identifier.
$PSDefaultParameterValues['Out-File:Encoding'] = 'ascii'

if ($RunServer) {
	echo "Beginning startup. Add 127.0.0.1:5000 to zone list to play."
}

$ServerMapPath = "$($ServerPath)/maps/$($MapFilename)"
$BotMapPath = "$($BotPath)/zones/subgame/$($MapFilename)"

$ServerCurrentMapPath = "$($ServerPath)/maps/_current.lvl"

$ServerConfPath = "$($ServerPath)/conf/game.conf"
$ArenaConfPath = "$($ServerPath)/arenas/(default)/arena.conf"
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
	
	"" >> $ArenaConfPath
	"#include conf/game.conf" >> $ArenaConfPath
	
	"" >> $ArenaConfPath
	"[General]" >> $ArenaConfPath
	"DesiredPlaying = 1024" >> $ArenaConfPath
	"MaxPlaying = 1024" >> $ArenaConfPath
	
	# Reduce logging because terminals can be very slow to write with many bots.
	"" >> $ServerGlobalConfPath
	"[log_console]" >> $ServerGlobalConfPath
	"all = MWE" >> $ServerGlobalConfPath
	"" >> $ServerGlobalConfPath
	"[log_file]" >> $ServerGlobalConfPath
	"all = MWE" >> $ServerGlobalConfPath
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

# Generate the run.bat file and all of the config files for the bots.
for ($i = 1; $i -le $BotCount; $i++) {
	$BotName = "$($BotBaseName)$($i)"
	$CurrentBotShip = $BotShip
	
	if (($CurrentBotShip -lt 1) -or ($CurrentBotShip -gt 8)) {
		$CurrentBotShip = Get-Random -Minimum 1 -Maximum 9	
	}
	
	$ConfigFilename = "$($BotName).cfg"
	$ConfigPath = "$($BotPath)/$($ConfigFilename)"
		
	"start /B ./zero.exe $($ConfigFilename)" >> $BotRunFile
	
	if ($i % 10 -eq 0) {
		$Delay = ($i / 10) + 1
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
	"Server = $($BotBehaviorServer)" >> $ConfigPath
	"Encryption = Subspace" >> $ConfigPath
	"" >> $ConfigPath
	"[General]" >> $ConfigPath
	"LogLevel = Error" >> $ConfigPath
	"RequestShip = $($CurrentBotShip)" >> $ConfigPath
	"Behavior = $($BotBehavior)" >> $ConfigPath
	""  >> $ConfigPath
	"[Servers]" >> $ConfigPath
	"$($BotBehaviorServer) = 127.0.0.1:5000" >> $ConfigPath
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
