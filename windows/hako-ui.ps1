$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hako-common.ps1')
$localPort = [int]$Hako.DashboardLocalPort
$remoteHost = [string]$Hako.DashboardRemoteHost
$remotePort = [int]$Hako.DashboardRemotePort
Write-Host "Mantenha esta janela aberta e acesse http://127.0.0.1:$localPort/"
& ssh -i $HakoIdentity $HakoRemote "ss -ltn 2>/dev/null | grep -q ':$remotePort '"
if ($LASTEXITCODE -ne 0) {
    Write-Error @'
O SSH funciona, mas o dashboard Hermes não está ativo na VPS.
Entre com hako-ssh.ps1 e inicie-o com:
sudo -u hermes -H /usr/local/bin/hermes dashboard --host 127.0.0.1 --port 9119
Depois mantenha aquele processo aberto e execute este atalho novamente em outra janela.
'@
    exit 1
}
& ssh -i $HakoIdentity -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L "${localPort}:${remoteHost}:${remotePort}" $HakoRemote
