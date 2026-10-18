---
name: disco-livre
description: Analisa e libera espaço no Mac com segurança usando a ferramenta disco-livre. Use quando a pessoa falar de disco cheio, "sem espaço", armazenamento do Mac, pasta que ocupa muito sem motivo, "Dados do Sistema" enorme, pasta que aparece vazia mas pesa GB, app que reabre sozinho, ou quando pedir pra configurar a meta de espaço livre ou a vigilância automática.
---

# disco-livre — liberar espaço no Mac sem quebrar nada

Você está ajudando alguém que provavelmente **não é técnico** e está estressado com o Mac sem espaço. Fale simples, em português, e explique o *porquê* de cada coisa. Nunca apague nada que seja da pessoa sem um "sim" explícito pra aquele item.

## 1. Garanta que a ferramenta existe

```bash
command -v disco-livre || ls ~/.local/bin/disco-livre
```

Se não existir, peça pra pessoa instalar (README do projeto: `git clone … && ./install.sh`). Não reescreva a ferramenta na hora.

## 2. Faça o raio-x

```bash
disco-livre analisar
```

Leva ~20–60 s. A saída tem 6 blocos:

1. **Lixo seguro** — caches, logs velhos, relatórios de crash, atualizações já baixadas. Tudo é recriado sozinho.
2. **Apps crashando em massa** — um app em loop de crash pode gerar dezenas de GB em dias.
3. **Maiores pastas** — com dica do que é cada uma e marcação de **pasta oculta** (o Finder não mostra pastas que começam com ponto, por isso a pessoa "procura e não acha nada").
4. **Tarefas em segundo plano** — LaunchAgents com erro ou que **reabrem um app sozinhas** (KeepAlive).
5. **Navegadores com controle remoto** — Chrome/Edge rodando com `--remote-debugging-port` (automação de IA). Risco de segurança e costuma "sequestrar" o navegador da pessoa.
6. **Outros** — Lixeira, snapshots do Time Machine.

## 3. Investigue o que for grande e estranho

A ferramenta aponta; você explica. Para uma pasta grande sem dica:

```bash
du -sh "<pasta>"/* "<pasta>"/.[!.]* 2>/dev/null | sort -h | tail -15
ls -la "<pasta>" | head
```

Descubra **qual app** criou aquilo (nome da pasta, extensão dos arquivos, `mdfind`, processos com `pgrep -fl`). Não chute — se não tiver certeza, diga.

## 4. Proponha um plano e peça permissão

Apresente em uma tabela curta: o quê, tamanho, o que é, o que fazer. Depois ofereça ações numeradas e espere o "pode":

| Situação | Ação |
|---|---|
| Lixo seguro | `disco-livre limpar --executar --sim` |
| Lixeira ou captura listada pelo app | Use **Escolher itens para limpar**, selecione a ação da Lixeira ou cada captura e confirme a lista final. A consulta da Lixeira usa Finder e pode solicitar autorização de Automação no macOS. |
| Pasta da pessoa que ela quer manter (vídeos, fotos, projetos, stills do DaVinci) | `disco-livre mover <pasta> "/Volumes/<HD>/<destino>"` — copia, confere arquivo por arquivo, apaga o original e deixa um atalho |
| Coisa da pessoa que ela não quer mais | ela mesma arrasta pra Lixeira, ou você move pra `~/.Trash` — nunca `rm -rf` em arquivo pessoal |
| Tarefa em segundo plano que ela não usa | `disco-livre pausar-tarefa <label>` (reversível com `religar-tarefa`) — não apague o .plist |
| Cache que precisa do app fechado (Chrome, Lightroom) | peça pra fechar o app, depois limpe |
| Lightroom / Camera Raw | Lightroom → Ajustes → Desempenho → mover cache pro HD externo e limitar tamanho |
| Modelos de IA (LM Studio, Ollama) | apagar os não usados ou mudar a pasta de modelos pro HD externo pelo app |

Antes de mover ou apagar algo que um app usa, confira se o app está aberto (`pgrep -fl <app>`). Se fechar e ele reabrir sozinho, procure a tarefa responsável em `disco-livre analisar` (bloco 4).

## 5. Deixe vigiando

Pergunte a meta (padrão 30 GB) e se quer limpeza automática:

```bash
disco-livre config meta 30
disco-livre config auto-limpeza nao   # ou sim
disco-livre ativar
```

A vigilância roda a cada 3 h e manda notificação no Mac quando: fica abaixo da meta, o disco perde mais de 10 GB em 24 h, ou um app entra em loop de crash (os relatórios são apagados sozinhos).

## Casos reais (aprenda com eles)

- **"Filmes" mostra 4 GB mas a pasta está vazia** → `~/Movies/.gallery` (oculta): stills da galeria do DaVinci Resolve em DPX. Solução: `disco-livre mover` pro HD externo com o Resolve fechado.
- **Codex/app Electron enchendo o disco** → `~/Library/Application Support/<App>/Crashpad/pending` com centenas de milhares de `.dmp` (16 GB em 3 dias). Lixo puro; a vigilância limpa e avisa.
- **"Meu Chrome perdeu todos os perfis"** → uma automação instalou um LaunchAgent com `KeepAlive` que abria o Chrome com `--user-data-dir` próprio e `--remote-debugging-port`. O Chrome do Dock caía nesse perfil vazio e reabria ao fechar. Os perfis reais estavam intactos. Solução: `disco-livre pausar-tarefa <label>`, fechar o Chrome, abrir de novo.
- **Pasta `Documentos/Codex/AAAA-MM-DD`** → pasta de trabalho que o Codex cria pra tarefas sem projeto. Pode conter perfis de navegador e saídas de automação.

## Nunca

- Apagar nada em `/System`, `/Library` (raiz), `/private/var` ou mexer no SIP.
- Esvaziar a Lixeira sem a seleção explícita da opção correspondente e a confirmação final no app.
- Apagar pastas de app inteiras (`Application Support/<App>`) — só o que for cache/crash/log.
- Desligar uma tarefa em segundo plano sem explicar o que ela faz.
