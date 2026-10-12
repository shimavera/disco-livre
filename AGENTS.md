# AGENTS.md — instruções para assistentes de IA

Você é um assistente de IA (Claude Code, Codex, Cursor etc.) e a pessoa pediu pra instalar ou usar o **disco-livre**. Siga este guia. A pessoa provavelmente **não é técnica**: fale em português simples e explique cada pedido de permissão antes de fazer.

## O que é

- `bin/disco-livre`: ferramenta de terminal (zsh puro, sem dependências) que analisa o disco, limpa lixo seguro e vigia o espaço livre.
- `app/`: app da barra de menus "Disco Livre" (SwiftUI quando o toolchain oferece macros; caso contrário, usa `DiscoLivreFallback.swift` com AppKit).
- `skill/disco-livre/SKILL.md`: skill pro Claude Code / Codex usar a ferramenta.
- `install.sh` / `uninstall.sh`: instalação e remoção.

Só funciona em **macOS 13 ou mais novo** (Intel ou Apple Silicon).

## Instalar (passo a passo)

1. **Confirme que é um Mac:** `uname` deve retornar `Darwin`. Se não for, avise que o disco-livre é só pra macOS e pare.

2. **Pergunte à pessoa** (uma pergunta só, com os padrões sugeridos):
   - Quantos GB livres ela quer manter no mínimo (padrão **30**)
   - Se quer a vigilância automática (padrão **sim**)
   - Se quer que ele limpe o lixo seguro sozinho quando passar da meta (padrão **não**)

3. **Verifique as ferramentas da Apple** (necessárias só pro app visual):
   ```bash
   command -v swiftc
   ```
   Se não existir, explique: "Pra ter o app na barra de menus, o Mac precisa das ferramentas de desenvolvedor da Apple. Vai abrir uma janela da Apple: clique em Instalar. Leva alguns minutos." Depois rode `xcode-select --install` e **espere a pessoa confirmar que terminou**. Se ela não quiser, instale sem o app (`--sem-app`). Se `swiftc` existir, mas a compilação SwiftUI falhar por falta dos macros, `app/build.sh` deve recorrer à versão AppKit leve em vez de omitir o app.

4. **Rode o instalador sem perguntas interativas**, na pasta do repositório:
   ```bash
   ./install.sh --sim --meta 30 --vigia sim --auto-limpeza nao
   ```
   (troque os valores pelo que a pessoa escolheu; acrescente `--sem-app` se não houver `swiftc`)

   O instalador:
   - copia a ferramenta pra `~/.local/bin/disco-livre` e adiciona `~/.local/bin` ao PATH no `~/.zshrc`
   - copia a skill pra `~/.claude/skills/` e `~/.codex/skills/` (se essas pastas existirem)
   - salva a configuração em `~/.config/disco-livre/config`
   - liga a vigilância (LaunchAgent `com.disco-livre.vigia`, roda a cada 3 h)
   - compila o app e copia pra `/Applications/Disco Livre.app` (ou `~/Applications`)

5. **Confira se deu certo:**
   ```bash
   ~/.local/bin/disco-livre                      # mostra espaço livre, meta e "Vigilância: ligada"
   launchctl print gui/$(id -u)/com.disco-livre.vigia | grep "last exit"   # deve ser 0
   ls -d "/Applications/Disco Livre.app" ~/Applications/"Disco Livre.app" 2>/dev/null
   ```

6. **Diga à pessoa o que fazer agora:**
   - O ícone de disco com os GB livres aparece na **barra de menus** (lá em cima, à direita). No menu, **Analisar armazenamento** abre um relatório e **Limpeza manual segura** mostra uma simulação e pede confirmação antes de apagar.
   - O painel SwiftUI completo mostra também ajustes e detalhes; a versão AppKit leve inclui análise e limpeza manual, atualizando o espaço a cada minuto.
   - Ela vai receber notificações do Mac quando o espaço passar da meta. Na primeira vez, o macOS pode pedir permissão pra notificações (do "Editor de Scripts"): é só permitir.

## Permissões que podem aparecer

| Quando | O que a pessoa vê | O que dizer |
|---|---|---|
| `xcode-select --install` | Janela da Apple pedindo pra instalar ferramentas | "É da própria Apple, pode instalar" |
| Primeira notificação | "Editor de Scripts quer enviar notificações" | "É o aviso de pouco espaço, pode permitir" |
| Abrir o app | Nada (é compilado no próprio Mac, não vem da internet) | — |
| Medir pastas | Talvez "Disco Livre quer acessar dados de outros apps" | "É só pra medir o tamanho das pastas, não lê o conteúdo" |

## Usar depois de instalado

Leia `skill/disco-livre/SKILL.md`: tem o fluxo completo de análise e limpeza, as regras de segurança e casos reais.

Regras que valem sempre:
- **Nunca apague arquivos pessoais** sem um "sim" explícito pra aquele item. Prefira `disco-livre mover <pasta> <HD externo>` ou mandar pra Lixeira.
- `disco-livre limpar --executar --sim` só apaga lixo que se recria (cache, logs velhos, relatórios de crash).
- Pra parar tarefas em segundo plano, use `disco-livre pausar-tarefa <label>` (reversível). Não apague o `.plist`.

## Desinstalar

```bash
./uninstall.sh
```

Remove ferramenta, app, skill, configuração e vigilância. Não desfaz nada que já foi limpo.

## Desenvolver

- Ferramenta: `zsh -n bin/disco-livre` checa a sintaxe. `DISCO_LIVRE_DIR=/tmp/x bin/disco-livre ...` usa uma pasta de configuração separada pra testes.
- O app lê os dados com `disco-livre dados resumo` e `disco-livre dados pastas` (JSON).
- App: `app/build.sh` gera `app/build/Disco Livre.app` (universal, assinado ad-hoc). `open "app/build/Disco Livre.app" --args --mostrar` abre já com o resumo aberto.
