# Story: Limpeza seletiva da Lixeira e capturas antigas

**Status:** Ready
**Tipo:** Funcionalidade

## História

Como pessoa que acompanha o armazenamento pela barra de menus, quero revisar a Lixeira inteira e capturas de tela reconhecidas na Mesa e em Downloads, selecionar explicitamente o que remover e confirmar a seleção, para liberar espaço sem apagar arquivos pessoais por engano.

## Critérios de aceite

- A lista de limpeza seletiva apresenta uma opção manual para esvaziar a Lixeira inteira, com contagem e tamanho aproximado consultados pelo Finder.
- A lista apresenta capturas de tela reconhecidas por nomes comuns do macOS, localizadas diretamente na Mesa ou em Downloads, cada uma como opção individual.
- A limpeza não percorre nem apaga outros arquivos da Mesa ou Downloads, nem arquivos dentro de subpastas desses locais.
- Itens de revisão manual nunca são apagados pela limpeza automática, pela limpeza geral do app ou por `disco-livre limpar --executar` sem seleção explícita.
- Após selecionar, a pessoa vê a lista/tamanho escolhidos e precisa confirmar novamente antes da exclusão.
- A execução confirma novamente a contagem e o tamanho aproximado da Lixeira antes de esvaziá-la; se o conteúdo mudou desde a prévia, recusa a ação e orienta a abrir a lista novamente.
- O app explica que a consulta usa Apple Events e que o macOS pode solicitar autorização para controlar o Finder.
- A Lixeira só é esvaziada após a seleção da opção específica e a confirmação final no app.
- O comportamento funciona na versão AppKit leve mostrada no menu e a documentação explica a nova lista e seus limites.
- Testes/verificações cobrem sintaxe, simulação, seleção permitida e exclusão manual usando diretório de teste, sem apagar dados reais do usuário.

## Escopo

### IN

- Adicionar uma opção manual para esvaziar a Lixeira pelo Finder e entradas individuais para capturas com nomes reconhecidos na raiz de Mesa e Downloads.
- Estender a seleção e validação da ferramenta CLI existente, preservando as confirmações do app.
- Impedir que itens de revisão manual participem de rotinas automáticas ou de limpeza geral não seletiva.
- Atualizar o app AppKit, documentação e verificações automatizadas/localmente simuladas.

### OUT

- Enumerar os itens internos da Lixeira via acesso direto do shell.
- Procurar recursivamente ou identificar imagens por conteúdo visual.
- Apagar arquivos comuns, pastas de projeto ou notebooks da Mesa/Downloads.
- Apagar arquivos reais do Mac durante desenvolvimento ou validação.
- Alterar o comportamento das categorias atuais de cache, logs e relatórios de crash.
