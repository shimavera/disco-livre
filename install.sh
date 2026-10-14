#!/bin/zsh
# Instala o disco-livre: ferramenta de terminal + app da barra de menus + skill pra IA + vigilância.
#
#   ./install.sh                         pergunta a meta e as opções
#   ./install.sh --sim                   instala com os padrões, sem perguntar (bom pra IA)
#   ./install.sh --meta 30 --vigia sim --auto-limpeza nao --sem-app
set -e
cd "${0:A:h}"

B=$'\e[1m' G=$'\e[32m' Y=$'\e[33m' N=$'\e[0m'
[[ -t 1 ]] || B= G= Y= N=
BIN="$HOME/.local/bin"

META= VIGIA= AUTO= SEM_APP= PERGUNTAR=1
[[ -t 0 ]] || PERGUNTAR=0
while (( $# )); do
  case $1 in
    --sim|-y)       PERGUNTAR=0 ;;
    --meta)         META=$2; shift ;;
    --vigia)        VIGIA=$2; shift ;;
    --auto-limpeza) AUTO=$2; shift ;;
    --sem-app)      SEM_APP=1 ;;
    -h|--help)      sed -n '2,6p' "$0"; exit 0 ;;
    *) print -r -- "opção desconhecida: $1" >&2; exit 1 ;;
  esac
  shift
done

print -r -- "${B}Instalando o disco-livre${N}"
[[ $(uname) == Darwin ]] || { print -r -- "O disco-livre só funciona no macOS."; exit 1; }

# 1. Ferramenta de terminal
mkdir -p "$BIN"
cp bin/disco-livre "$BIN/disco-livre"
chmod +x "$BIN/disco-livre"
print -r -- "${G}✓${N} Ferramenta em ~/.local/bin/disco-livre"

if [[ ":$PATH:" != *":$BIN:"* ]] && ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
  print -r -- '' >> "$HOME/.zshrc"
  print -r -- '# disco-livre' >> "$HOME/.zshrc"
  print -r -- 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  print -r -- "${G}✓${N} ~/.local/bin adicionado ao PATH (vale em terminais novos)"
fi

# 2. Skill pro Claude Code / Codex
for dir in "$HOME/.claude" "$HOME/.codex"; do
  if [[ -d $dir ]]; then
    mkdir -p "$dir/skills"
    rm -rf "$dir/skills/disco-livre"
    cp -R skill/disco-livre "$dir/skills/disco-livre"
    print -r -- "${G}✓${N} Skill em ${dir/#$HOME/~}/skills/disco-livre"
  fi
done

# 3. Configuração
if (( PERGUNTAR )); then
  print -r -- ""
  [[ -z $META ]]  && { read -r "META?Quantos GB livres você quer manter no mínimo? [30] "; }
  [[ -z $VIGIA ]] && { read -r "VIGIA?Ligar a vigilância automática (avisa quando passar da meta)? [S/n] "; }
  if [[ $VIGIA != [nN]* && -z $AUTO ]]; then
    read -r "AUTO?Quando passar da meta, limpar o lixo seguro sozinho? [s/N] "
  fi
fi
[[ $META == <1-> ]] || META=30
[[ $VIGIA == [nN]* ]] && VIGIA=nao || VIGIA=sim
[[ $AUTO == [sSyY]* ]] && AUTO=sim || AUTO=nao

"$BIN/disco-livre" config meta "$META" >/dev/null
"$BIN/disco-livre" config auto-limpeza "$AUTO" >/dev/null
print -r -- "${G}✓${N} Meta: $META GB livres · limpeza automática: $AUTO"
if [[ $VIGIA == sim ]]; then
  "$BIN/disco-livre" ativar
else
  "$BIN/disco-livre" desativar >/dev/null
fi

# 4. App da barra de menus (precisa das Ferramentas de Linha de Comando da Apple)
APP_OK=
if [[ -z $SEM_APP ]]; then
  if command -v swiftc >/dev/null 2>&1; then
    print -r -- "Compilando o app Disco Livre (uns 30 segundos)…"
    if app/build.sh >/dev/null 2>&1; then
      DEST=/Applications
      [[ -w $DEST ]] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
      pkill -x DiscoLivre 2>/dev/null || true
      rm -rf "$DEST/Disco Livre.app"
      cp -R "app/build/Disco Livre.app" "$DEST/"
      print -r -- "${G}✓${N} App em ${DEST/#$HOME/~}/Disco Livre.app"
      # Inicia o app de menu em cada login do usuário, sem alterar a vigilância.
      APP_PLIST="$HOME/Library/LaunchAgents/com.disco-livre.app.plist"
      mkdir -p "$HOME/Library/LaunchAgents"
      cat > "$APP_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.disco-livre.app</string>
  <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-a</string><string>$DEST/Disco Livre.app</string></array>
  <key>RunAtLoad</key><true/>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
EOF
      launchctl bootout "gui/$UID/com.disco-livre.app" 2>/dev/null || true
      launchctl enable "gui/$UID/com.disco-livre.app"
      launchctl bootstrap "gui/$UID" "$APP_PLIST"
      print -r -- "${G}✓${N} Abertura automática configurada para o início da sessão"
      APP_OK=1
    else
      print -r -- "${Y}!${N} Não consegui compilar o app. A ferramenta de terminal funciona normalmente."
    fi
  else
    print -r -- "${Y}!${N} Pra ter o app da barra de menus, instale as ferramentas da Apple e rode ./install.sh de novo:"
    print -r -- "    xcode-select --install"
  fi
fi

print -r -- ""
print -r -- "${G}Pronto!${N} No terminal: ${B}disco-livre analisar${N}"
if [[ -n $APP_OK ]]; then
  open "$DEST/Disco Livre.app"
  print -r -- "O app está aberto: passe o mouse no ícone de disco na barra de menus (lá em cima, à direita)."
fi
