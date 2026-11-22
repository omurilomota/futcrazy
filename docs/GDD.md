# GDD — FutCrazy (MVP)

## Pitch

**Não é um simulador de futebol. É um jogo de comédia física cujo cenário é uma partida de futebol.**
A partida começa normal e vai perdendo a seriedade. A diversão vem antes do realismo:
bugs físicos, animações desajeitadas e situações inesperadas são features.

## Decisões fechadas para o MVP

| Decisão | Escolha | Motivo |
| --- | --- | --- |
| Câmera | arcade lateral fixa (ortográfica, campo inteiro visível) | leitura imediata da física, sem custo de câmera |
| Controle | física livre estilo Gang Beasts: impulso, torque, cambaleio | o corpo é a piada |
| Adversário | 1 jogador (teclado) x bot simples | testável sozinho hoje, sem custo de netcode |
| Visual | low-poly cartunesco com primitivas, tudo por código | MVP sem depender de pipeline de modelagem |
| Eventos | os 7 do conceito, com combos | é o coração do jogo |

## Core loop

1. Partida 1x1, 2 minutos, gol em qualquer lado (campo curto: 16m de comprimento).
2. Correr, pular, chutar, dar carrinho. Tudo por física: chutar forte empurra quem chutou.
3. A cada 10–16s um evento é avisado (`⚠ PREPARE-SE`) e ativado por ~10s.
4. Combos (35%) fazem dois eventos ao mesmo tempo.
5. Gol → banner, tremor de câmera, kickoff. Fim do tempo → vencedor e `R` para reiniciar.

## Pilares

- **Legibilidade**: evento sempre anunciado antes de mudar as regras.
- **Independência**: cada evento liga/desliga só o seu efeito (modificadores aditivos por id).
- **Controle apesar do caos**: o jogador nunca fica sem controle por mais de ~1s (stun curto e volta de pé).
- **Física como piada**: nada de ragdoll permanente.

## Sistemas do MVP

- Física 2.5D: corpos rígidos em 3D com deslocamento travado em Z (profundidade) e rotação livre só no plano da tela.
- Jogador: RigidBody3D + cápsula (corpo) + esfera (cabeça), controle por velocidade com aceleração limitada, torque de inclinação, torque de reequilíbrio, stun com flail e "levantar com pulinho".
- Chute: impulso na bola com recuo no jogador, alcance e potência moduláveis por evento.
- Carrinho/pancada: dash + verificação de alcance, impulso e stun no alvo.
- Bola: RigidBody3D, bounce 0.62, arrasto baixo, limite de 36 m/s, squash visual no impacto.
- Eventos: `EventManager` com aviso, ativação, duração, combos e limpeza.
- Estádio procedural: gramado listrado, gols com trave colidível, arquibancada, torcida em MultiMesh, placas, nuvens.

## Fora do escopo do MVP

Áudio, multiplayer, goleiros, modelos no Blender, ragdoll real (`PhysicalBoneSimulator3D`),
narração, modos de jogo extras, seleção de eventos, placar persistente.

## Roadmap sugerido

1. **0.2 — Sabor**: áudio (chute, torcida, gol), vibração de tela, comemoração, replay simples.
2. **0.3 — Corpo**: humanoide articulado no Blender + ragdoll real nas pancadas.
3. **0.4 — Gente**: 2 jogadores locais, bot preenchendo time.
4. **0.5 — Mais caos**: novos eventos, eventos específicos por time, editor de eventos.
5. **1.0 — Online**: netcode, matchmaking, ranking.
