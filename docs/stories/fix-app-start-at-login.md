# Story: Abrir o app Disco Livre ao iniciar sessão

**Status:** Ready
**Tipo:** Correção

## História

Como pessoa que usa o Disco Livre pela barra de menus, quero que o app abra automaticamente ao iniciar sessão no macOS, para que o ícone volte a aparecer depois de reiniciar o computador.

## Critérios de aceite

- A instalação do app cria uma configuração de inicialização do usuário para o `Disco Livre.app` instalado.
- A configuração abre o app no início da sessão gráfica, mantendo-o como app de barra de menus.
- A configuração funciona tanto em `/Applications` quanto em `~/Applications`.
- Reinstalar atualiza a configuração existente sem criar entradas duplicadas.
- Desinstalar descarrega e remove somente a configuração de inicialização do Disco Livre.
- A vigilância de armazenamento existente mantém seu comportamento e seu LaunchAgent.
- A instalação sem app não cria configuração de inicialização do app.

## Escopo

### IN

- Criar e carregar um LaunchAgent dedicado ao app da barra de menus durante a instalação.
- Remover esse LaunchAgent durante a desinstalação.
- Documentar comportamento de inicialização automática.

### OUT

- Alterar o LaunchAgent da vigilância, sua frequência ou suas opções de limpeza.
- Modificar itens de início de sessão do Warp ou de outros aplicativos.
- Alterar configurações locais da sessão atual fora do fluxo de instalação.

## Implementação prevista

O instalador grava `com.disco-livre.app.plist` em `~/Library/LaunchAgents`, com o caminho absoluto do app instalado e execução no início da sessão. O desinstalador descarrega e remove apenas esse arquivo. A configuração é idempotente e reversível.
