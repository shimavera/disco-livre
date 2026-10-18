# Story: Limpeza seletiva da Lixeira e capturas antigas

**Status:** Ready
**Tipo:** Funcionalidade

## História

Como pessoa que acompanha o armazenamento pela barra de menus, quero revisar itens da Lixeira e capturas de tela antigas da Mesa e de Downloads, selecionar exatamente o que remover e confirmar a seleção, para liberar espaço sem apagar arquivos pessoais por engano.

## Critérios de aceite

- A lista de limpeza seletiva apresenta cada item diretamente dentro de `~/.Trash` como uma opção individual, com tamanho e identificação legível.
- A lista apresenta capturas de tela reconhecidas por nomes comuns do macOS, localizadas diretamente na Mesa ou em Downloads, cada uma como opção individual.
- A limpeza não percorre nem apaga outros arquivos da Mesa ou Downloads, nem arquivos dentro de subpastas desses locais.
- Itens de revisão manual nunca são apagados pela limpeza automática, pela limpeza geral do app ou por `disco-livre limpar --executar` sem seleção explícita.
- Após selecionar, a pessoa vê a lista/tamanho escolhidos e precisa confirmar novamente antes da exclusão.
- A execução valida novamente que cada caminho continua elegível e confinado ao local esperado; caminhos arbitrários e seleções obsoletas são recusados.
- A Lixeira permanece como diretório; somente os filhos selecionados são removidos.
- O comportamento funciona na versão AppKit leve mostrada no menu e a documentação explica a nova lista e seus limites.
- Testes/verificações cobrem sintaxe, simulação, seleção permitida e exclusão manual usando diretório de teste, sem apagar dados reais do usuário.

## Escopo

### IN

- Adicionar entradas manuais individuais para filhos imediatos da Lixeira do usuário e capturas com nomes reconhecidos na raiz de Mesa e Downloads.
- Estender a seleção e validação da ferramenta CLI existente, preservando as confirmações do app.
- Impedir que itens de revisão manual participem de rotinas automáticas ou de limpeza geral não seletiva.
- Atualizar o app AppKit, documentação e verificações automatizadas/localmente simuladas.

### OUT

- Esvaziar a Lixeira inteira sem seleção item a item.
- Procurar recursivamente ou identificar imagens por conteúdo visual.
- Apagar arquivos comuns, pastas de projeto ou notebooks da Mesa/Downloads.
- Apagar arquivos reais do Mac durante desenvolvimento ou validação.
- Alterar o comportamento das categorias atuais de cache, logs e relatórios de crash.
