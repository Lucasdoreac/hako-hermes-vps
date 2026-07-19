$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hako-common.ps1')

# Portas do n8n. Se ausentes no hako.local.psd1, usa os padrões (loopback:5678).
$localPort  = if ($Hako.N8nLocalPort)  { [int]$Hako.N8nLocalPort }     else { 5678 }
$remoteHost = if ($Hako.N8nRemoteHost) { [string]$Hako.N8nRemoteHost } else { '127.0.0.1' }
$remotePort = if ($Hako.N8nRemotePort) { [int]$Hako.N8nRemotePort }    else { 5678 }

Write-Host "Mantenha esta janela aberta e acesse http://127.0.0.1:$localPort/"

# Confirma que o n8n esta escutando na VPS antes de abrir o tunel.
& ssh -i $HakoIdentity $HakoRemote "ss -ltn 2>/dev/null | grep -q '127.0.0.1:$remotePort '"
if ($LASTEXITCODE -ne 0) {
    Write-Error @'
O SSH funciona, mas o n8n nao esta escutando na VPS (127.0.0.1:5678).
Verifique o servico com hako-ssh.ps1 e, la dentro:
  systemctl --user status n8n
  systemctl --user start n8n
Depois execute este atalho novamente.
'@
    exit 1
}

& ssh -i $HakoIdentity -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L "${localPort}:${remoteHost}:${remotePort}" $HakoRemote
