# Acesso à VPS — padrão seguro (sem segredos no repo)

> **Regra de ouro:** este repositório é público. **Nenhum** dado de acesso
> (IP, usuário, chave privada, `known_hosts`) entra no Git. A configuração de
> acesso mora **apenas** em `~/.ssh/` na máquina do operador. Este documento usa
> **placeholders** — substitua localmente, nunca commite os valores reais.

## 1. Config SSH local (`~/.ssh/config`)

Fixar o usuário evita sondagem de nomes — que dispara fail2ban e derruba o acesso.

```sshconfig
Host hako-vps
    HostName <IP_DA_VPS>
    User <USUARIO_ADMIN>
    Port 22
    IdentityFile ~/.ssh/<CHAVE_PRIVADA>
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
    ServerAliveCountMax 4
```

Depois: `ssh hako-vps` — sem `-i`, sem usuário na mão, sem tentativa errada.

## 2. Permissão da chave privada

- **Linux/macOS:** `chmod 600 ~/.ssh/<CHAVE_PRIVADA>`
- **Windows (NTFS — o que vale de verdade):**
  ```powershell
  icacls "$env:USERPROFILE\.ssh\<CHAVE_PRIVADA>" /inheritance:r /grant:r "$(whoami):(F)"
  ```
  Remove herança e deixa a chave acessível **só ao dono**. `chmod` no Git-Bash
  não altera a ACL do Windows — use `icacls`.

## 3. Regras anti-vulnerabilidade

- Nunca sondar usuários (`ssh root@`, `ssh admin@`…): erra a auth e o fail2ban
  bane o IP. Sempre use o alias com o usuário correto.
- Nunca colocar IP/usuário/chave em arquivo versionado. O `.gitignore` da raiz
  barra `.ssh/`, `*.key`, `*.pem`, `.env*`, `secrets/` — mas isso é rede de
  proteção, não permissão para tentar. A rede pega o nome esperado; não pega
  `chave-antiga.txt`, nem o IP colado dentro de um `.md`, nem um `git add -f`.
- `known_hosts` fixa a identidade do host (anti-MITM). Não apagar.

## 4. Rodar comandos com `sudo`

O SSH automatizado (CI/scripts) roda **sem tty**, então `sudo` interativo não
funciona nele. Para tarefas administrativas, o operador roda no próprio terminal:

```bash
ssh hako-vps
sudo <comando>        # pede a senha normalmente
```

## 5. Acesso de emergência (SSH indisponível)

Console web (noVNC) do painel Contabo — passa pela infra do provedor, não pelo
SSH nem pelo IP eventualmente banido. Colar no noVNC: abrir a barra lateral do
console → ícone de **clipboard** → colar o texto na caixa → colar no terminal
remoto com **Ctrl+Shift+V**. Alternativa infalível: trocar o IP de saída
(hotspot 4G) e voltar ao SSH normal.

## 6. Acesso do CI/CD (deploy)

Não usa a chave do operador. Usuário dedicado `hako-deploy`, chave própria,
sudo restrito a um único script, e credenciais em **GitHub Environment secrets**
(cifradas) — ver `HAKO-CICD-DEPLOY.md`. Segredos nunca entram no Git.
