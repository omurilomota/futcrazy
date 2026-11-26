# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e
versionamento semântico.

## [0.4.0] — 2026-11-25

Esta versão é sobre **identidade e acabamento**: o jogo deixa de parecer um protótipo com
elementos padrão da engine e passa a ter interface, fluxo e configurações de produto.

### Adicionado
- **Identidade visual própria** (`scripts/ui/ui_theme.gd`): paleta de várzea (verde de campo,
  creme envelhecido, amarelo de arbitragem, azul e vermelho dos times), tipografia pesada de
  cartaz via `FontVariation` e caixas de canto vivo. Nenhum asset externo.
- **Menu principal reconstruído**: cartaz desenhado por código (`FcPoster`), marca vetorial
  com bola (`FcLogo`), botões reais com hover/pressionado/foco/desabilitado (`FcButton`),
  carimbo inclinado, versão discreta e o estádio 3D ao fundo.
- **Tela de seleção de modo** com três cartões (nome, descrição, característica, formato e
  mini-campo desenhado) e estado de seleção visível.
- **Tela de opções funcional** em quatro abas: áudio (3 sliders), vídeo (tela cheia, VSync,
  escala da interface), acessibilidade (tremor, flashes, partículas) e partida (duração,
  ritmo dos eventos, dificuldade dos bots). Inclui restaurar padrões com confirmação.
- **Tela de controles** com as cinco ações de cada jogador, remapeamento real, validação de
  conflito, recusa de teclas reservadas e restauração do padrão.
- **Tela de pausa completa**: continuar, reiniciar, controles, opções e voltar ao menu, com
  confirmação para o que descarta a partida. O relógio para de verdade.
- **Tela de resultado** estilo transmissão: vencedor, placar, gols, chutes, carrinhos e
  pancadas, com revanche e volta ao menu.
- **HUD de transmissão**: placar em blocos (time / número / time) com aba de cronômetro,
  tarja do modo, banner de evento colorido, fichas de eventos ativos com tempo restante e
  rodapé de controles gerado a partir das teclas configuradas.
- **Gerenciador central de configurações** (`scripts/settings.gd`, autoload `Settings`) com
  persistência em `user://futcrazy.cfg`.
- **Sistema de ações no InputMap** (`p1_*` / `p2_*`), com alças de seta extras no modo 1P.
- **Buses de áudio** `SFX` e `Ambience` criados em tempo de execução; os sliders controlam
  `Master`, `SFX` e `Ambience` de verdade.
- **Níveis de dificuldade dos bots** (`TRANQUILO`, `NORMAL`, `MALVADO`) que mudam perseguição,
  chance de carrinho e frequência de trapalhadas.
- **Teste `--smoke-ui`**: percorre menu, modos, início de partida, pausa, retomada, resultado,
  revanche, volta ao menu, opções, controles, persistência em disco, conflito de teclas,
  limpeza de eventos e encerramento do áudio.
- **Flags de captura** `--shot-modes`, `--shot-options`, `--shot-controls`, `--shot-credits`,
  `--shot-pause` e `--shot-result`.
- **Workflow de CI** (`.github/workflows/ci.yml`): instala Godot 4.6.3, importa e roda os três
  testes headless.

### Mudado
- `project.godot` passa a declarar **Godot 4.6** (era 4.7) e registra o autoload `Settings`.
- O painel do estádio deixou de duplicar o placar ao vivo e agora mostra a marca do jogo e o
  nome do estádio — o placar de verdade é o do HUD.
- A dica de controles da partida é montada a partir das teclas configuradas.
- A contagem/GOL subiu para cima dos jogadores, sem tapar a jogada.
- README, GDD, CONTRIBUTING e ASSET_LICENSES atualizados para o estado real do jogo (três
  modos, dez eventos, opções e testes).

### Alterado
- **`main.tscn` com hierarquia real**: `Main`, `WorldEnvironment`, `Camera`, `Stadium`, `Ball`,
  `Sfx`, `Events`, `Hud` e `Menu` são nós de verdade, e `game.gd` os obtém com `@onready`
  tipado. Estádio, bola e jogadores de prévia aparecem no editor (`@tool`).
- **Cenas de desenvolvimento**: `scenes/dev/ui_gallery.tscn` (todas as telas de UI sobre o
  estádio) e `scenes/dev/sandbox.tscn` (herda a cena principal e entra direto em um modo),
  ambas executáveis com F6.
- **`docs/DEVELOPMENT.md`**: abertura do projeto, cenas, autoloads, breakpoints, colisões,
  monitores, profiler, testes e receitas de manutenção.

### Corrigido
- **Vazamento de áudio no encerramento** (issue P0): `Sfx.shutdown()` para todos os players,
  solta as referências de stream, duplica o recurso da torcida em vez de mutar o cache
  importado e o jogo espera o AudioServer reciclar os playbacks antes de sair. Não há mais
  avisos de `AudioStreamWAV`/`AudioStreamPlaybackWAV`.
- O ritmo dos eventos configurado nas opções não é mais sobrescrito ao iniciar a partida
  (os testes fixam o próprio ritmo com `events_override`).
- Menu e pausa não dependem mais de teclas numéricas escondidas em texto.

### Removido
- `scripts/menu.gd` e `scripts/hud.gd` (substituídos por `scripts/ui/menu.gd` e
  `scripts/ui/hud.gd`).

## [0.3.0] — 2026-11-22

### Adicionado
- **Modo Campo Todo (5x5)** com campo maior (24 m), câmera aberta, formação por time,
  goleiros com IA própria e troca automática do jogador controlado (seta amarela).
- Opção `3` no menu inicial e flag de captura `--shot-campo`.
- Teste automatizado `--smoke-campo`: valida 10 jogadores, 2 goleiros, gol, evento e limites.
- Áreas, círculo central e linhas de fundo no estádio, dimensionados pelo campo ativo.
- Dica de modo no HUD (`CAMPO TODO • 5 x 5 COM GOLEIROS`) e resumo de estatísticas no fim.
- Preview `@tool` no editor: `main.tscn` mostra estádio, bola e jogadores, sem rodar o jogo.

### Corrigido
- Fogo amigo: carrinho não derruba mais companheiro de time (só na briga generalizada).
- Lateral devolve a bola perto de onde saiu, em vez de teleportar para o centro.
- Bola parada sem ninguém por perto volta ao centro após 6 s (não trava a partida).
- Gol não cancela mais os eventos ativos; o efeito continua valendo no kickoff.
- Evento de briga não sobrescreve mais a dica de controles do modo atual.
- Goleiro sempre corta a bola para frente, nunca para o próprio gol.

## [0.2.0] — 2026-11-22

### Adicionado
- Áudio 100% sintetizado (`tools/gen_audio.py`): chute, pancada, quique, whoosh, apito,
  gol com torcida, vinheta de evento, beeps e ambiência em loop com intensidade dinâmica.
- Dois jogadores locais no mesmo teclado, menu inicial e pausa (`ESC`).
- Tela de fim com revanche (`R`) e volta ao menu (`ESC`).
- Poeira em pousos/carrinhos/chutes, rastro na bola veloz e flash de tela no gol.

## [0.1.0] — 2026-11-22

### Adicionado
- Partida 1x1 de 2 minutos com física livre, chute com recuo, carrinho, stun e kickoff.
- 7 eventos com aviso, duração, combos e limpeza independente.
- Estádio procedural, HUD, bot simples e teste automatizado `--smoke`.
