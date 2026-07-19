@{
    Host = 'vps.example.com'
    User = 'admin'
    IdentityFile = '~/.ssh/id_ed25519'
    DashboardLocalPort = 9119
    DashboardRemoteHost = '127.0.0.1'
    DashboardRemotePort = 9119
    # Opcional: túnel do n8n. Se omitido, hako-n8n.ps1 usa 127.0.0.1:5678.
    N8nLocalPort = 5678
    N8nRemoteHost = '127.0.0.1'
    N8nRemotePort = 5678
}

