# Atalhos locais HAKO

Estes scripts ficam no OneDrive e sobrevivem à limpeza de pastas temporárias.

Copie `hako.example.psd1` para `hako.local.psd1` e preencha os dados da sua VPS. O arquivo
local é ignorado pelo Git: caminhos, endereço e usuário não ficam presos ao código publicado.

- `hako-ssh.ps1`: abre o terminal da VPS.
- `hako-ui.ps1`: mantém o túnel do painel Hermes em `http://127.0.0.1:9119/`.
- `hako-security-audit.ps1`: gera um relatório local somente leitura, sem coletar segredos.
- `hako-vps-audit.ps1`: envia e executa a auditoria privilegiada e somente leitura na VPS.
- `hako-vps-remediate.ps1`: corrige somente os achados confirmados pela auditoria, com rollback.

No PowerShell, execute a partir da raiz deste repositório:

```powershell
.\windows\hako-ssh.ps1
.\windows\hako-ui.ps1
pwsh -File .\windows\hako-security-audit.ps1
.\windows\hako-vps-audit.ps1
```

Depois de revisar o relatório da auditoria:

```powershell
.\windows\hako-vps-remediate.ps1
```

Mantenha a sessão atual aberta e teste o SSH em uma segunda janela antes de fechá-la.

Para comandos que você pretende reutilizar, prefira um arquivo `.ps1` com nome claro e
comentários. O histórico do PowerShell ajuda a reencontrar comandos, mas não é documentação
nem backup confiável.
