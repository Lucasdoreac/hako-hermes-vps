# Estação macOS

O Mac deve ser uma estação independente. Não copie a chave privada do Windows. Crie uma chave
nova, autorize somente sua chave pública na VPS e mantenha cada dispositivo revogável
separadamente.

## 1. Verificar a estação

Na raiz do repositório:

```bash
./clients/macos/bootstrap.sh
```

O modo padrão apenas verifica. Para instalar `git`, `gh` e `jq` por Homebrew, depois de revisar
o script:

```bash
./clients/macos/bootstrap.sh --install
```

O script não instala Homebrew, não instala o Codex e não altera o SSH.

## 2. Criar uma chave exclusiva do Mac

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/hako_contabo_ed25519 -C "hako-mac-$(scutil --get ComputerName)"
chmod 600 ~/.ssh/hako_contabo_ed25519
chmod 644 ~/.ssh/hako_contabo_ed25519.pub
```

Cadastre **somente** o conteúdo do arquivo `.pub` em `/home/lucas/.ssh/authorized_keys` na VPS,
usando uma sessão administrativa já confiável. Mantenha a chave do Windows até testar a do Mac.

## 3. Configurar o alias SSH

Revise `hako-vps.conf.example` e copie seu conteúdo para `~/.ssh/config`. Se já houver um bloco
`Host hako-vps`, edite-o em vez de duplicar. Depois:

```bash
chmod 600 ~/.ssh/config
ssh hako-vps
```

Na primeira conexão, compare a impressão digital apresentada com a impressão obtida por uma
estação já confiável. Não aceite uma chave de host apenas porque apareceu na tela.

## 4. Acessar o painel Hermes

```bash
./clients/macos/hako-ui.sh
```

Mantenha a janela aberta e acesse <http://127.0.0.1:9119/>. O painel continua restrito à VPS e
chega ao Mac somente pelo túnel SSH.

## 5. Codex

Instale o aplicativo oficial, entre com a mesma conta ChatGPT e abra o checkout local. O Codex
usa `~/.codex` como diretório de estado por padrão; não sincronize esse diretório por Git ou
OneDrive. Preferências pessoais ficam em `~/.codex/config.toml` e instruções do projeto ficam no
repositório.

Referências oficiais:

- <https://learn.chatgpt.com/docs/app>
- <https://learn.chatgpt.com/docs/config-file/config-basic>

## 6. Auditoria privilegiada da VPS

Depois que o alias `hako-vps` estiver funcionando, execute na raiz do repositório:

```bash
./clients/macos/hako-vps-audit.sh
```

O script envia o auditor somente leitura e pede a senha `sudo` no terminal. Ele não imprime
tokens nem conteúdo das chaves privadas; o relatório remoto é criado com permissão `600`.
