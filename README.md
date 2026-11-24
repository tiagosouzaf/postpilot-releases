# PostPilot

Aplicativo desktop para administrar bancos de dados, inspirado no SQL Server
Management Studio (SSMS): PostgreSQL, SQL Server, Redis, MongoDB e
Elasticsearch em uma janela só, para Linux e Windows. Feito em Rust, sem
Electron nem WebView.

Este repositório guarda só os instaladores. Cada versão está na
[página de Releases](https://github.com/tiagosouzaf/postpilot-releases/releases/latest).

## Linux: um comando só

```sh
curl -fsSL https://raw.githubusercontent.com/tiagosouzaf/postpilot-releases/main/install.sh | bash
```

O [`install.sh`](install.sh) baixa a versão mais recente, confere o SHA-256
contra o `SHA256SUMS` da Release e instala do jeito do seu sistema:

- **Arch Linux e derivados (Omarchy, Manjaro, EndeavourOS):** o
  `.pkg.tar.zst`, com `sudo pacman -U`.
- **Ubuntu, Debian e derivados:** o `.deb`, com `sudo apt install`.
- **Outras distribuições (Fedora, openSUSE…):** o AppImage em
  `~/.local/bin/PostPilot.AppImage`, com atalho no menu de aplicativos, sem
  sudo. O AppImage precisa da `fuse2` (`libfuse2` no Debian e no Ubuntu).

Opções vão depois de `bash -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/tiagosouzaf/postpilot-releases/main/install.sh | bash -s -- --appimage   # AppImage mesmo em Arch/Debian
curl -fsSL https://raw.githubusercontent.com/tiagosouzaf/postpilot-releases/main/install.sh | bash -s -- --version 0.2.73
curl -fsSL https://raw.githubusercontent.com/tiagosouzaf/postpilot-releases/main/install.sh | bash -s -- --uninstall
```

Prefere ver o script antes de rodar? Baixe com
`curl -fsSLO https://raw.githubusercontent.com/tiagosouzaf/postpilot-releases/main/install.sh`,
leia e rode `bash install.sh`.

## Linux: à mão

Baixe o arquivo da Release e:

- **Arch e derivados:** `sudo pacman -U ./postpilot-<versão>-1-x86_64.pkg.tar.zst`.
  Para remover, `sudo pacman -R postpilot`.
- **Ubuntu, Debian e derivados:** `sudo apt install ./postpilot_<versão>_amd64.deb`.
  Para remover, `sudo apt remove postpilot`.
- **Qualquer distribuição:** `chmod +x PostPilot-<versão>-x86_64.AppImage` e
  execute.

## Windows

Baixe o `PostPilot-<versão>-x86_64.msi` (instalador) ou o
`PostPilot-<versão>-windows-x86_64.zip` (portátil, é só extrair e abrir o
`postpilot.exe`). O Windows SmartScreen pode avisar que o app é de um editor
desconhecido, porque o exe não é assinado: clique em "Mais informações" e em
"Executar assim mesmo".

## Atualizar

O próprio app avisa quando sai uma versão nova, com o botão **Atualizar
agora** (ou em Ajuda > Verificar se Há Atualizações). Ele baixa o pacote
daqui, confere o SHA-256 e instala. No Linux, rodar o instalador de novo
também atualiza.

## Problemas e sugestões

Abra uma [issue](https://github.com/tiagosouzaf/postpilot-releases/issues).
