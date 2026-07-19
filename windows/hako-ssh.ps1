$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hako-common.ps1')
& ssh -i $HakoIdentity -o ServerAliveInterval=30 -o ServerAliveCountMax=3 $HakoRemote
