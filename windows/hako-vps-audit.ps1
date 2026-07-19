$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hako-common.ps1')

$localScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'vps-hermes/scripts/95-security-audit.sh'
$remoteScript = '.local/share/hako/hako-vps-security-audit.sh'

Write-Host 'Enviando o auditor somente leitura para a VPS...'
& ssh -i $HakoIdentity -- $HakoRemote 'mkdir -p ~/.local/share/hako && chmod 700 ~/.local/share/hako'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar o diretório remoto.' }
& scp -i $HakoIdentity -- $localScript ("{0}:{1}" -f $HakoRemote, $remoteScript)
if ($LASTEXITCODE -ne 0) { throw 'Falha ao enviar o auditor.' }

Write-Host 'Digite sua senha sudo da VPS quando solicitado.'
& ssh -t -i $HakoIdentity -- $HakoRemote 'sudo bash "$HOME/.local/share/hako/hako-vps-security-audit.sh"'
if ($LASTEXITCODE -ne 0) { throw 'A auditoria da VPS não terminou corretamente.' }

Write-Host 'O caminho do relatório protegido foi exibido ao final da execução remota.'
