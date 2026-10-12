# disco-livre 🧹

**Seu Mac nunca mais fica sem espaço do nada.**

O `disco-livre` mostra o que está comendo o seu disco (inclusive as pastas que o Finder esconde), limpa só o que é lixo de verdade e fica de olho em segundo plano. Quando o espaço livre fica abaixo da sua meta, ele te avisa.

Ele funciona sozinho, direto no Terminal. E também vem com uma **skill pro Claude Code e pro Codex**: é só falar "meu Mac tá sem espaço" que a IA roda a análise e te explica tudo em português.

---

## Por que isso existe

Num dia normal, o Mac ficou com **9 GB livres de 228 GB**. Os culpados:

- **16 GB de relatórios de crash.** Um app entrou em loop e gerou quase 200 mil arquivos em 3 dias, numa pasta que ninguém vê.
- **A pasta "Filmes" pesava 4 GB e aparecia vazia.** Eram stills do DaVinci Resolve guardados numa pasta oculta.
- **8 GB de cache do Lightroom** no SSD.
- **"Meu Chrome perdeu todos os perfis."** Uma automação instalou uma tarefa que abria um Chrome separado e reabria ele toda vez que era fechado. Os perfis estavam lá, intactos.

Em uma tarde voltaram **mais de 35 GB** sem apagar nada importante. Esta ferramenta é tudo isso empacotado, pra não acontecer de novo.

---

## Instalar

### Jeito fácil: pela sua IA

Abra o Claude Code, o Codex ou o Cursor e cole:

> Instale o disco-livre pra mim: https://github.com/Willclaf/disco-livre — siga o AGENTS.md do repositório.

A IA baixa o projeto, pergunta a sua meta de espaço, instala tudo e confere se funcionou. Você só aprova o que ela pedir.

### Jeito manual: pelo Terminal

```bash
git clone https://github.com/Willclaf/disco-livre.git
cd disco-livre
./install.sh
```

O instalador pergunta:
1. Quantos GB livres você quer manter no mínimo (padrão: **30 GB**)
2. Se quer ligar a vigilância automática
3. Se quer que ele limpe o lixo seguro sozinho quando passar da meta

Pra instalar sem perguntas: `./install.sh --sim --meta 30 --vigia sim --auto-limpeza nao`

Requisitos: macOS 13 ou mais novo (Intel ou Apple Silicon). Com as ferramentas de linha de comando da Apple, o app da barra compila; se o compilador não tiver os macros SwiftUI, o build usa uma versão AppKit leve. O painel completo em SwiftUI requer um toolchain com suporte a esses macros.

---

## O app da barra de menus

Um ícone pequeno de disco mostra quantos GB você tem livres. Clique para abrir o menu com **Analisar armazenamento**, **Escolher itens para limpar**, **Atualizar agora** e **Sair**. A limpeza permite marcar um, vários ou todos os itens seguros; mostra a seleção e o total e só apaga após confirmação final. A versão AppKit leve não precisa abrir o Terminal e atualiza o espaço livre a cada minuto. A limpeza libera espaço de armazenamento no disco, não memória RAM.

Quando o toolchain oferece os macros SwiftUI, o build mantém o painel completo abaixo:

O resumo mostra só quatro coisas:

| | |
|---|---|
| 🟢 **Espaço livre** | anel colorido (verde, laranja ou vermelho) com um tique marcando a sua meta |
| 🚩 **Meta** | − / + pra ajustar quantos GB livres você quer manter |
| 👁 **Vigia** | liga e desliga a vigilância automática |
| ✨ **Pra limpar** | quanto lixo seguro existe, com o botão **Limpar** |

O **Ver mais** abre os detalhes: alertas (app crashando, tarefa que reabre app sozinha, com botão **Pausar**), o que exatamente dá pra limpar, as maiores pastas (inclusive as ocultas) e os ajustes.

Quando o espaço livre fica abaixo da meta, o ícone fica vermelho.

---

## Usar no Terminal

```bash
disco-livre                     # resumo: espaço livre, meta, vigilância
disco-livre analisar            # raio-x completo
disco-livre limpar              # mostra o lixo seguro (só simula)
disco-livre limpar --executar   # apaga o lixo seguro (pede confirmação)
disco-livre limpar --item <caminho> # simula só um item seguro (pode repetir)
disco-livre mover <pasta> <HD>  # manda uma pasta pro HD externo e deixa um atalho
```

### O raio-x (`disco-livre analisar`)

```
1. Lixo seguro (é recriado sozinho)
  948 MB    Logs com mais de 7 dias
  8.5 GB    Cache do Chrome (feche o app pra limpar)
  8.0 GB    Cache do Camera Raw (Lightroom/Photoshop)
  Total: 10.9 GB

2. Apps crashando em massa
  ✗ Codex gerou 194975 relatórios de crash (16.0 GB)

3. Maiores pastas pra revisar
  10.7 GB   ~/.lmstudio (oculta no Finder)
            ↳ Modelos de IA locais. Apague os que não usa ou mova pro HD externo
  3.4 GB    ~/Movies/.gallery (oculta no Finder)
            ↳ Stills da galeria do DaVinci Resolve. disco-livre mover pro HD externo

4. Tarefas em segundo plano
  ⚠ com.exemplo.chrome abre Google Chrome sozinho e reabre se você fechar

5. Navegadores com controle remoto
  ⚠ Google Chrome está com controle remoto ligado (porta 9222)
```

### Configuração

```bash
disco-livre config                     # ver tudo
disco-livre config meta 30             # espaço livre mínimo (GB)
disco-livre config auto-limpeza sim    # limpar sozinho quando passar da meta
disco-livre config intervalo 3         # vigiar a cada 3 horas
disco-livre ativar / desativar         # liga/desliga a vigilância
```

### A vigilância avisa quando

- o espaço livre fica **abaixo da sua meta**
- o disco perde **mais de 10 GB em 24 h** (algo novo está enchendo)
- um app entra em **loop de crash** (os relatórios são apagados sozinhos)

Tudo o que ele apaga fica anotado em `~/Library/Logs/disco-livre.log`.

### Tarefas em segundo plano

```bash
disco-livre pausar-tarefa com.exemplo.tarefa    # para e não volta ao reiniciar
disco-livre religar-tarefa com.exemplo.tarefa   # desfaz
```

---

## O que ele apaga (e o que nunca apaga)

**Apaga só lixo que se recria sozinho:**
relatórios de crash · logs com mais de 7 dias · cache do npm, pip, uv, Yarn e Homebrew · Xcode DerivedData · cache do Chrome, Edge, Brave e Opera GX · cache do Camera Raw · atualizações de apps já baixadas

**Nunca apaga:**
seus arquivos · fotos · projetos · perfis de navegador · modelos de IA · nada fora da sua pasta pessoal

Caches de apps abertos são pulados. Ele pede pra você fechar o app primeiro.
O `mover` só apaga o original depois de conferir que a cópia tem o mesmo número de arquivos e os mesmos bytes.

---

## Skill pro Claude Code / Codex

O `install.sh` copia a skill pra `~/.claude/skills/` e `~/.codex/skills/` (se existirem). Depois disso, é só pedir:

> "Meu Mac tá sem espaço, me ajuda"

A IA roda o raio-x, investiga as pastas estranhas, explica o que é cada coisa e **pede sua permissão** antes de mexer em qualquer coisa.

---

## Desinstalar

```bash
./uninstall.sh
```

Licença MIT. Feito com raiva de "Dados do Sistema: 63 GB". 😤
