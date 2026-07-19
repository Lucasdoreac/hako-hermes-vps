$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hako-common.ps1')

$localScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'vps-hermes/scripts/96-remediate-security-findings.sh'
$remoteScript = '.local/share/hako/96-remediate-security-findings.sh'

Write-Host 'Esta ação corrige SSH, neutraliza a conta ubuntu e repara o backup local.'
Write-Host 'Mantenha esta janela aberta até a validação final.'
& ssh -i $HakoIdentity -- $HakoRemote 'mkdir -p ~/.local/share/hako && chmod 700 ~/.local/share/hako'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar o diretório remoto.' }
& scp -i $HakoIdentity -- $localScript ("{0}:{1}" -f $HakoRemote, $remoteScript)
if ($LASTEXITCODE -ne 0) { throw 'Falha ao enviar a remediação.' }

& ssh -t -i $HakoIdentity -- $HakoRemote 'sudo bash "$HOME/.local/share/hako/96-remediate-security-findings.sh"'
if ($LASTEXITCODE -ne 0) { throw 'A remediação não terminou corretamente; consulte o rollback exibido.' }

Write-Host 'Abra uma segunda janela e confirme o login SSH antes de encerrar esta.'
