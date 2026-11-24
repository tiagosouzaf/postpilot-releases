#!/usr/bin/env bash
# Instalador do PostPilot para Linux (x86_64), em um comando:
#
#   curl -fsSL https://raw.githubusercontent.com/tiagosouzaf/postpilot-releases/main/install.sh | bash
#
# Baixa a versão mais recente do Release do GitHub, confere o SHA-256 contra o
# SHA256SUMS do Release e instala do jeito de cada sistema:
#
#   - Arch e derivados (Omarchy, Manjaro, EndeavourOS): o .pkg.tar.zst, com
#     `sudo pacman -U` (substitui o antigo `pgstudio`);
#   - Debian, Ubuntu e derivados: o .deb, com `sudo apt install`;
#   - o resto: o AppImage em ~/.local/bin, com atalho no menu (sem sudo).
#
# Rodar de novo atualiza. Opções (depois de `bash -s --`):
#   --appimage        instala o AppImage mesmo em Arch/Debian (sem sudo)
#   --version X.Y.Z   instala essa versão em vez da mais recente
#   --force           reinstala mesmo se essa versão já estiver instalada
#   --uninstall       remove o PostPilot instalado por este script
#
# Exemplo: curl -fsSL .../install.sh | bash -s -- --appimage

set -euo pipefail

REPO="tiagosouzaf/postpilot-releases"
GITHUB="https://github.com/$REPO"
# Para testes: outra origem com o mesmo formato de Release.
RELEASES="${POSTPILOT_RELEASES_URL:-$GITHUB/releases}"
AUR_PACKAGE="tf-postpilot-bin"

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
APPIMAGE_PATH="$BIN_DIR/PostPilot.AppImage"
DESKTOP_FILE="$DATA_DIR/applications/postpilot.desktop"
ICON_FILE="$DATA_DIR/icons/hicolor/256x256/apps/postpilot.png"

if [ -t 1 ]; then
  BOLD=$'\033[1m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'
else
  BOLD='' RED='' GREEN='' YELLOW='' RESET=''
fi

say() { printf '%s==>%s %s\n' "$BOLD" "$RESET" "$*"; }
ok() { printf '%s==>%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%saviso:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die() {
  printf '%serro:%s %s\n' "$RED" "$RESET" "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Instalador do PostPilot para Linux (x86_64).

  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash
  curl -fsSL .../install.sh | bash -s -- [opções]

Opções:
  --appimage        instala o AppImage em ~/.local/bin mesmo em Arch/Debian (sem sudo)
  --version X.Y.Z   instala essa versão em vez da mais recente
  --force           reinstala mesmo se essa versão já estiver instalada
  --uninstall       remove o PostPilot instalado por este script
EOF
}

# Baixa uma URL para um arquivo (curl ou wget).
fetch() {
  local url=$1 out=$2
  if command -v curl >/dev/null 2>&1; then
    curl -fL --proto '=https' --tlsv1.2 --retry 3 --progress-bar -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --show-progress -O "$out" "$url"
  else
    die "preciso do curl ou do wget para baixar o PostPilot."
  fi
}

# Tag do Release mais recente (v0.1.0), pelo redirecionamento de
# /releases/latest: não usa a API do GitHub, então não esbarra no limite dela.
latest_tag() {
  local url
  if command -v curl >/dev/null 2>&1; then
    url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$RELEASES/latest") || return 1
  else
    url=$(wget -q --max-redirect=5 -S --spider "$RELEASES/latest" 2>&1 |
      awk 'tolower($1) == "location:" { l = $2 } END { print l }') || return 1
  fi
  url=${url%$'\r'}
  case $url in
    */tag/*) printf '%s\n' "${url##*/tag/}" ;;
    *) return 1 ;;
  esac
}

# Executa como root: direto se já for root, senão com sudo (ou doas).
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  elif command -v doas >/dev/null 2>&1; then
    doas "$@"
  else
    die "preciso de sudo (ou doas) para instalar o pacote. Rode como root ou use --appimage."
  fi
}

# Se dá para fazer perguntas ao usuário pelo terminal. Com `curl | bash` a
# entrada padrão é o próprio script, então as perguntas vão para /dev/tty.
have_tty() { { : </dev/tty; } 2>/dev/null; }

detect_system() {
  if command -v pacman >/dev/null 2>&1 && [ -d /var/lib/pacman ]; then
    echo arch
  elif command -v apt-get >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1; then
    echo debian
  else
    echo appimage
  fi
}

# Baixa o arquivo `name` do Release `tag` para `dir` e confere o SHA-256.
download_verified() {
  local tag=$1 name=$2 dir=$3 expected actual
  expected=$(awk -v n="$name" '$2 == n || $2 == "*" n { print $1 }' "$dir/SHA256SUMS")
  [ -n "$expected" ] || die "o SHA256SUMS do Release $tag não tem $name."
  say "Baixando $name"
  fetch "$RELEASES/download/$tag/$name" "$dir/$name" || die "não consegui baixar $name."
  actual=$(sha256sum "$dir/$name" | awk '{ print $1 }')
  [ "$actual" = "$expected" ] ||
    die "SHA-256 de $name não confere (esperado $expected, veio $actual). Nada foi instalado."
  ok "SHA-256 conferido"
}

install_arch() {
  local tag=$1 version=$2 dir=$3 name current
  if pacman -Q "$AUR_PACKAGE" >/dev/null 2>&1; then
    ok "O PostPilot já está instalado pelo AUR ($AUR_PACKAGE). Atualize com o yay ou o paru."
    return
  fi
  current=$(pacman -Q postpilot 2>/dev/null | awk '{ print $2 }') || true
  if [ -n "$current" ] && [ "${current%-*}" = "$version" ] && [ -z "$FORCE" ]; then
    ok "O PostPilot $version já está instalado. Use --force para reinstalar."
    return
  fi
  name=$(awk '$2 ~ /^\*?postpilot-.*-x86_64\.pkg\.tar\.zst$/ { sub(/^\*/, "", $2); print $2; exit }' "$dir/SHA256SUMS")
  [ -n "$name" ] || die "o Release $tag não tem pacote do Arch (.pkg.tar.zst). Tente com --appimage."
  download_verified "$tag" "$name" "$dir"
  # Pelo arquivo local: `pacman -U <URL>` procura um .sig que o Release não
  # tem e falha.
  say "Instalando com o pacman (pede a senha do sudo)"
  if have_tty; then
    if pacman -Q pgstudio >/dev/null 2>&1; then
      say "O pacman vai perguntar se remove o pgstudio (o nome antigo do app): responda y."
    fi
    as_root pacman -U "$dir/$name" </dev/tty
  else
    # Sem terminal o --noconfirm responderia "não" à remoção do pacote em
    # conflito (o antigo `pgstudio`) e falharia; --ask=4 inverte essa resposta.
    as_root pacman -U --ask=4 --noconfirm "$dir/$name"
  fi
  ok "PostPilot $version instalado. Abra pelo lançador de aplicativos ou com \`postpilot\`."
}

install_debian() {
  local tag=$1 version=$2 dir=$3 name current
  current=$(dpkg-query -W -f='${Status} ${Version}' postpilot 2>/dev/null |
    awk '$3 == "installed" { print $4 }') || true
  if [ -n "$current" ] && [ "$current" = "$version" ] && [ -z "$FORCE" ]; then
    ok "O PostPilot $version já está instalado. Use --force para reinstalar."
    return
  fi
  name=$(awk '$2 ~ /^\*?postpilot_.*_amd64\.deb$/ { sub(/^\*/, "", $2); print $2; exit }' "$dir/SHA256SUMS")
  [ -n "$name" ] || die "o Release $tag não tem pacote .deb. Tente com --appimage."
  download_verified "$tag" "$name" "$dir"
  # O apt baixa como o usuário _apt: ele precisa conseguir ler o arquivo.
  chmod 755 "$dir"
  chmod 644 "$dir/$name"
  say "Instalando com o apt (pede a senha do sudo)"
  local reinstall=()
  [ -n "$FORCE" ] && reinstall=(--reinstall)
  as_root apt-get install -y "${reinstall[@]}" "$dir/$name"
  ok "PostPilot $version instalado. Abra pelo menu de aplicativos ou com \`postpilot\`."
}

install_appimage() {
  local tag=$1 version=$2 dir=$3 name
  name=$(awk '$2 ~ /^\*?PostPilot-.*-x86_64\.AppImage$/ { sub(/^\*/, "", $2); print $2; exit }' "$dir/SHA256SUMS")
  [ -n "$name" ] || die "o Release $tag não tem AppImage."
  download_verified "$tag" "$name" "$dir"
  mkdir -p "$BIN_DIR" "$(dirname "$DESKTOP_FILE")" "$(dirname "$ICON_FILE")"
  chmod 755 "$dir/$name"
  # Troca pelo nome fixo, sem versão: o próprio app se atualiza depois por cima
  # deste arquivo (Ajuda > Verificar se Há Atualizações).
  mv -f "$dir/$name" "$APPIMAGE_PATH"
  ln -sf "$APPIMAGE_PATH" "$BIN_DIR/postpilot"
  # Ícone: extrair do AppImage não precisa de FUSE.
  if (cd "$dir" && "$APPIMAGE_PATH" --appimage-extract postpilot.png >/dev/null 2>&1) &&
    [ -f "$dir/squashfs-root/postpilot.png" ]; then
    cp -f "$dir/squashfs-root/postpilot.png" "$ICON_FILE"
  else
    warn "não consegui tirar o ícone do AppImage; o atalho fica sem ícone."
  fi
  cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=PostPilot
GenericName=PostgreSQL Management Studio
Comment=Administre bancos PostgreSQL como no SSMS
Exec="$APPIMAGE_PATH" %F
Icon=postpilot
Terminal=false
Categories=Development;Database;
Keywords=postgres;postgresql;sql;database;ssms;
MimeType=application/sql;
StartupWMClass=postpilot
EOF
  command -v update-desktop-database >/dev/null 2>&1 &&
    update-desktop-database "$(dirname "$DESKTOP_FILE")" >/dev/null 2>&1 || true
  ok "PostPilot $version instalado em $APPIMAGE_PATH, com atalho no menu de aplicativos."
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "$BIN_DIR não está no PATH; abra pelo menu ou com $APPIMAGE_PATH." ;;
  esac
  if ! ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
    warn "o AppImage precisa da libfuse2 para abrir (fuse2 no Arch e no Fedora, libfuse2 no Debian e no Ubuntu)."
    warn "Sem ela: $APPIMAGE_PATH --appimage-extract-and-run"
  fi
}

uninstall() {
  local removed=''
  if [ -e "$APPIMAGE_PATH" ] || [ -e "$DESKTOP_FILE" ]; then
    rm -f "$APPIMAGE_PATH" "$DESKTOP_FILE" "$ICON_FILE"
    [ -L "$BIN_DIR/postpilot" ] && rm -f "$BIN_DIR/postpilot"
    ok "AppImage e atalho removidos."
    removed=1
  fi
  if command -v pacman >/dev/null 2>&1 && pacman -Q postpilot >/dev/null 2>&1; then
    say "Removendo o pacote com o pacman"
    if have_tty; then as_root pacman -R postpilot </dev/tty; else as_root pacman -R --noconfirm postpilot; fi
    removed=1
  elif command -v dpkg-query >/dev/null 2>&1 &&
    dpkg-query -W -f='${Status}' postpilot 2>/dev/null | grep -q 'ok installed'; then
    say "Removendo o pacote com o apt"
    as_root apt-get remove -y postpilot
    removed=1
  fi
  [ -n "$removed" ] || ok "Não achei o PostPilot instalado por este script."
  echo "Suas configurações e conexões ficam em ~/.config/PostPilot; apague essa pasta se quiser."
}

main() {
  local mode='' version='' tag dir
  FORCE=''
  while [ $# -gt 0 ]; do
    case $1 in
      --appimage) mode=appimage ;;
      --version)
        [ $# -ge 2 ] || die "--version precisa de um número (ex.: --version 0.1.0)."
        version=${2#v}
        shift
        ;;
      --version=*) version=${1#--version=} version=${version#v} ;;
      --force) FORCE=1 ;;
      --uninstall)
        uninstall
        return
        ;;
      -h | --help)
        usage
        return
        ;;
      *) die "opção desconhecida: $1 (veja --help)" ;;
    esac
    shift
  done

  [ "$(uname -s)" = Linux ] ||
    die "este instalador é para Linux. No Windows, baixe o .msi em $GITHUB/releases/latest"
  case $(uname -m) in
    x86_64 | amd64) ;;
    *) die "por enquanto o PostPilot só tem pacotes para x86_64 (este computador é $(uname -m))." ;;
  esac
  command -v sha256sum >/dev/null 2>&1 || die "preciso do sha256sum (coreutils) para conferir o download."

  if [ -n "$version" ]; then
    tag="v$version"
  else
    say "Procurando a versão mais recente"
    tag=$(latest_tag) || die "não consegui descobrir a versão mais recente em $RELEASES/latest"
    version=${tag#v}
  fi
  [ -n "$mode" ] || mode=$(detect_system)
  say "PostPilot $version ($(case $mode in arch) echo "pacote do Arch" ;; debian) echo "pacote .deb" ;; *) echo "AppImage" ;; esac))"

  dir=$(mktemp -d "${TMPDIR:-/tmp}/postpilot-install.XXXXXX")
  # shellcheck disable=SC2064 # expande agora, de propósito
  trap "rm -rf '$dir'" EXIT
  fetch "$RELEASES/download/$tag/SHA256SUMS" "$dir/SHA256SUMS" 2>/dev/null ||
    die "não achei o Release $tag (ou ele não tem SHA256SUMS): $GITHUB/releases"

  case $mode in
    arch) install_arch "$tag" "$version" "$dir" ;;
    debian) install_debian "$tag" "$version" "$dir" ;;
    *) install_appimage "$tag" "$version" "$dir" ;;
  esac
}

# Tudo dentro de main: com `curl | bash`, o bash só começa a executar depois de
# ler o script inteiro, então uma conexão cortada no meio não roda meio script.
main "$@"
