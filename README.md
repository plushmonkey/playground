# Playground
This script will automate creating a Subspace server with gameplay bots.  
It will begin by downloading the server and bot zip files, extracting them, then copying over the level files with arena conf file.  
It will automatically generate bot config files to start up the specified number of bots.  

It will begin running the server and bots after everything is downloaded. The next time it's ran, it will skip the download.  
The server will be running on `127.0.0.1:5000`. It can be shut down by pressing `Control + C` in the server terminal.  

## Requirements
This script is for Windows only.  
The server requires the .NET runtime to run the server.  
You can manually install it from [Microsoft](https://dotnet.microsoft.com/en-us/download/dotnet/9.0/runtime).  

## Trench Wars
There's a tw script that will setup a server and bots to play a well balanced team composition.  
Run the `tw.ps1` script and `?go tw` to play it. Make sure the `play.ps1` script is not running.  

There's a bug in the current SubspaceServer where you might need to rejoin the arena after downloading it once to see the flag.  
There is no module for actually running the flag game, so it's just the base gameplay that works.  

## Config
The bot count, name, password, ship, and behavior can be set in the script. The bot config files will be generated every time the script is ran, so it's not actually useful to manually change the zero cfg files.  

The map file and conf file are set in the script. The script will copy them into the server config and activate them.  
