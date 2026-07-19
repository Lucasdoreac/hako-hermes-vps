$configPath = Join-Path $PSScriptRoot 'hako.local.psd1'
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Crie $configPath a partir de hako.example.psd1."
}
$Hako = Import-PowerShellDataFile -LiteralPath $configPath
$identity = [string]$Hako.IdentityFile
if ($identity.StartsWith('~/') -or $identity.StartsWith('~\')) {
    $identity = Join-Path $HOME $identity.Substring(2)
}
$script:HakoIdentity = $identity
$script:HakoRemote = '{0}@{1}' -f $Hako.User, $Hako.Host
if (-not (Test-Path -LiteralPath $script:HakoIdentity)) {
    throw "Chave SSH não encontrada: $script:HakoIdentity"
}

