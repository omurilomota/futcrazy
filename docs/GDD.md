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
| Visual | low-poly cartunesco com primitivas, tudo por código | sem pipeline de modelagem |
| Áudio | sintetizado por script | som sem licença de asset |
| Eventos | 7 eventos com combos, sobrevivem ao gol | é o coração do jogo |

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

1. Partida de 2 minutos, gol em qualquer lado, kickoff com contagem.
2. Correr, pular, chutar, dar carrinho. Tudo por física: chutar forte empurra quem chutou.
3. A cada 10–16 s um evento é avisado (`⚠ PREPARE-SE`) e ativado por ~10 s.
4. Combos (35%) fazem dois eventos ao mesmo tempo; o evento continua valendo após o gol.
5. Gol → banner, flash, tremor, kickoff. Fim do tempo → vencedor, `R` revanche, `ESC` menu.

## Pilares

- **Legibilidade**: evento sempre anunciado antes de mudar as regras.
- **Independência**: cada evento liga/desliga só o seu efeito (modificadores por id).
- **Controle apesar do caos**: stun curto e volta de pé garantida.
- **Física como piada**: nada de ragdoll permanente.

## Sistemas

- Física 2.5D: corpos rígidos 3D com Z travado e rotação livre só no plano da tela.
- Jogador: caixa + esfera de cabeça, centro de massa baixo, torque de reequilíbrio,
  chute com recuo, carrinho com janela de acerto, stun com flail e "levantar com pulinho".
- Papéis: `field` (linha) e `gk` (goleiro, boné amarelo, sempre corta para frente).
- Bola: bounce 0.62, limite de 36 m/s, squash, rastro acima de 13 m/s.
- Goleiro: fica na linha, sai até 1,3 m na direção da bola, pula em bola alta e dá
  carrinho quando a bola chega rápida.
- Eventos: `EventManager` com aviso, ativação, duração, combos e limpeza.
- Estádio: gramado listrado, linhas/áreas/círculo central, traves colidíveis, rede,
  arquibancada, torcida em MultiMesh, placas e torres de luz — dimensionado pelo campo.
- Áudio: pool de efeitos com pitch variado + ambiência em loop com intensidade.
- Fluxo: menu (3 modos), pausa, fim de jogo; preview `@tool` no editor.

## Regras de borda

- Carrinho não atinge companheiro de time (exceto na briga generalizada).
- Bola fora: volta como lateral perto de onde saiu; bola parada sem ninguém por 6 s
  volta ao centro.
- Evento ativo não é cancelado no gol; só é limpo ao acabar o tempo, reiniciar ou sair.

## Fora do escopo atual

Multiplayer online, goleiros controláveis, modelos no Blender, ragdoll real
(`PhysicalBoneSimulator3D`), seleção de eventos, placar persistente.

## Roadmap

1. **0.1 — Base** ✅: 1x1, 7 eventos, estádio, HUD, smoke test.
2. **0.2 — Sabor** ✅: áudio, 2P local, menu/pausa, partículas.
3. **0.3 — Campo todo** ✅: 5x5 com goleiros, formação, troca de jogador, correções.
4. **0.4 — Corpo**: humanoide articulado no Blender + ragdoll real.
5. **0.5 — Mais caos**: novos eventos, eventos por time, modos extras (primeiro a 5).
6. **1.0 — Produto**: progressão, online, ranking.
