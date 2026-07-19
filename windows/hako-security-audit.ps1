[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $HOME ('hako-windows-audit-{0}.json' -f (Get-Date -Format 'yyyyMMddTHHmmss')))
)

$ErrorActionPreference = 'SilentlyContinue'
$interestingPorts = 22, 139, 445, 3000, 5040, 5130, 8000, 9119

$report = [ordered]@{
    GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
    Computer = $env:COMPUTERNAME
    Windows = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture
    Defender = Get-MpComputerStatus | Select-Object AntivirusEnabled, AntispywareEnabled,
        RealTimeProtectionEnabled, BehaviorMonitorEnabled, IoavProtectionEnabled, NISEnabled,
        AntivirusSignatureLastUpdated, QuickScanAge, FullScanAge
    Firewall = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
    Network = Get-NetConnectionProfile | Select-Object InterfaceAlias, Name, NetworkCategory,
        IPv4Connectivity, IPv6Connectivity
    BitLocker = Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionMethod
    Listeners = Get-NetTCPConnection -State Listen |
        Where-Object LocalPort -In $interestingPorts |
        Select-Object LocalAddress, LocalPort, OwningProcess,
            @{n='ProcessName';e={(Get-Process -Id $_.OwningProcess).ProcessName}}
    Services = Get-Service sshd, ssh-agent, TermService, WinRM, LanmanServer |
        Select-Object Name, Status, StartType
    PortProxy = (netsh interface portproxy show all | Out-String).Trim()
    DockerContainers = if (Get-Command docker -ErrorAction SilentlyContinue) {
        docker ps --format '{{json .}}' 2>$null
    } else { @() }
}

$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Relatório gravado em $OutputPath"
Write-Host "Revise antes de compartilhar: nomes de serviços e containers podem ser confidenciais."
