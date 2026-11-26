# GDD — FutCrazy

## Pitch

**Não é um simulador de futebol. É um jogo de comédia física cujo cenário é uma partida de futebol.**
A partida começa normal e vai perdendo a seriedade. A diversão vem antes do realismo:
trombadas, animações desajeitadas e situações inesperadas são features.

## Decisões fechadas

| Decisão | Escolha | Motivo |
| --- | --- | --- |
| Câmera | arcade lateral fixa; aberta no campo todo | leitura imediata da física, sem custo de câmera |
| Controle | física livre: impulso, torque, cambaleio, stun | o corpo é a piada |
| Adversário | bot simples; 2P local; time no campo todo | testável sozinho, sem netcode |
| Visual 3D | low-poly cartunesco com primitivas e GLB do próprio projeto | sem pipeline de modelagem externa |
| Visual 2D | cartaz de várzea + transmissão de TV, tudo por código | identidade própria sem asset de UI |
| Áudio | sintetizado por script | som sem licença de asset |
| Eventos | eventos independentes com combos, sobrevivem ao gol | é o coração do jogo |
| Configurações | um gerenciador central persistido em `user://` | uma fonte de verdade, testável |

## Identidade visual

Direção: **futebol de várzea + transmissão esportiva + cartaz de campeonato local**.

- Paleta: verde escuro de campo, creme envelhecido (papel), amarelo de arbitragem (destaque),
  azul e vermelho dos times, preto esverdeado para contraste.
- Tipografia: fonte de fallback da engine deformada em `FontVariation` (peso alto + tracking +
  inclinação leve). Títulos em caixa alta com contorno escuro; corpo em caixa alta só em
  rótulos curtos.
- Formas: canto vivo, borda grossa, barra de destaque à esquerda dos botões, placar com cantos
  chanfrados e aba de cronômetro.
- Regras: nada de glassmorphism, gradiente em tudo, cartão arredondado genérico ou emoji como
  ícone. Nenhum elemento decorativo sem relação com futebol.
- Componentes reutilizáveis: `UiTheme` (paleta/tema), `FcButton`, `FcPoster`, `FcLogo`.
  A UI é montada por código — decisão consciente para permitir os testes headless percorrerem
  as telas reais; o custo é a árvore construída em `_ready()`.

## Modos

| Modo | Campo | Times | Controle |
| --- | --- | --- | --- |
| **1 x BOT** | 16 m, câmera fixa | 1 x 1 | você x bot |
| **2 JOGADORES** | 16 m, câmera fixa | 1 x 1 | teclado compartilhado |
| **CAMPO TODO** | 24 m, câmera aberta | 5 x 5 com goleiros | você + 4 bots x 5 bots |

No campo todo, o humano controla sempre o jogador de linha azul mais perto da bola
(seta amarela), com troca automática e histerese de 1,4 m + cooldown de 0,6 s. Os bots
restantes mantêm formação deslocada pela bola; o mais próximo da bola persegue.

## Core loop

1. Partida de 2 minutos (1 ou 3 nas opções), gol em qualquer lado, kickoff com contagem.
2. Correr, pular, chutar, dar carrinho. Tudo por física: chutar forte empurra quem chutou.
3. A cada 10–16 s um evento é avisado (`PREPARE-SE`) e ativado por ~10 s.
4. Combos (35%) fazem dois eventos ao mesmo tempo; o evento continua valendo após o gol.
5. Gol → placar, flash, tremor, kickoff. Fim do tempo → tela de resultado com estatísticas,
   revanche e volta ao menu.

## Fluxo de telas

```
Menu principal
 ├─ JOGAR → Seleção de modo → preparação → contagem → partida
 ├─ OPÇÕES → (volta para o menu)
 ├─ CONTROLES → (volta para o menu)
 ├─ CRÉDITOS → (volta para o menu)
 └─ SAIR

Partida
 ├─ ESC → Pausa
 │   ├─ CONTINUAR → partida
 │   ├─ REINICIAR (confirma) → partida
 │   ├─ CONTROLES / OPÇÕES → volta para a pausa
 │   └─ VOLTAR AO MENU (confirma) → menu principal
 └─ fim do tempo → Resultado
     ├─ REVANCHE → partida
     └─ MENU PRINCIPAL → menu principal
```

Durante a pausa o relógio, a física e os eventos param; o áudio continua no estado em que
estava (sem loop de tensão). Nenhuma tela sobrepõe a outra: cada `_open()` esconde as demais.

## Pilares

- **Legibilidade**: evento sempre anunciado antes de mudar as regras.
- **Independência**: cada evento liga/desliga só o seu efeito (modificadores por id).
- **Controle apesar do caos**: stun curto e volta de pé garantida.
- **Física como piada**: nada de ragdoll permanente.
- **Personalidade**: a interface deve ser reconhecível sem ler o nome do jogo.

## Sistemas

- Física 2.5D: corpos rígidos 3D com Z travado e rotação livre só no plano da tela.
- Jogador: caixa + esfera de cabeça, centro de massa baixo, torque de reequilíbrio,
  chute com recuo, carrinho com janela de acerto, stun com flail e "levantar com pulinho".
- Papéis: `field` (linha) e `gk` (goleiro, boné amarelo, sempre corta para frente).
- Entrada: ações no `InputMap` (`p1_*`, `p2_*`) definidas pelo gerenciador central; no 1P as
  setas também controlam o P1. Remapeamento com validação de conflito e teclas reservadas.
- Bola: bounce 0.62, limite de 36 m/s, squash, rastro acima de 13 m/s.
- Goleiro: fica na linha, sai até 1,3 m na direção da bola, pula em bola alta e dá
  carrinho quando a bola chega rápida.
- Bots: perseguidor + formação; três níveis de dificuldade (perseguição, carrinho e
  frequência de trapalhadas).
- Eventos: `EventManager` com aviso, ativação, duração, combos, limpeza e fichas no HUD.
- Estádio: gramado listrado, linhas/áreas/círculo central, traves colidíveis, rede,
  arquibancada, torcida em MultiMesh, placas, torres de luz e painel com a marca do jogo.
- Áudio: pool de efeitos no bus `SFX`, torcida no bus `Ambience`, intensidade dinâmica e
  `shutdown()` explícito no encerramento.
- Configurações: áudio, vídeo, acessibilidade e partida, persistidas em `user://futcrazy.cfg`.
- Acessibilidade: intensidade de tremor, intensidade de flashes, partículas e escala da UI.
- Fluxo: menu (3 modos), pausa, resultado; preview `@tool` no editor.

## Regras de borda

- Carrinho não atinge companheiro de time (exceto na briga generalizada).
- Bola fora: volta como lateral perto de onde saiu; bola parada sem ninguém por 6 s
  volta ao centro.
- Evento ativo não é cancelado no gol; só é limpo ao acabar o tempo, reiniciar ou sair.
- Nenhum evento pode deixar modificador ou estado global residual (testado em `--smoke-ui`).

## Fora do escopo atual

Multiplayer online, goleiros controláveis, ragdoll real (`PhysicalBoneSimulator3D`),
seleção de eventos individuais, placar persistente entre sessões, presets de exportação.

## Roadmap

1. **0.1 — Base** ✅: 1x1, 7 eventos, estádio, HUD, smoke test.
2. **0.2 — Sabor** ✅: áudio, 2P local, menu/pausa, partículas.
3. **0.3 — Campo todo** ✅: 5x5 com goleiros, formação, troca de jogador, correções.
4. **0.4 — Identidade** ✅: UI própria, menu/modos/opções/controles/pausa/resultado,
   configurações persistentes, HUD de transmissão, correção do vazamento de áudio, CI.
5. **0.5 — Corpo**: humanoide articulado no Blender + ragdoll real, como protótipo isolado.
6. **0.6 — Mais caos**: eventos por time, modos extras (primeiro a 5), seleção de eventos.
7. **1.0 — Produto**: progressão, online, ranking, presets de exportação.
