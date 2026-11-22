# FutCrazy 🥅

> **Não é um simulador de futebol. É um jogo de comédia física cujo cenário é uma partida de futebol.**

MVP jogável em Godot 4.6: partida 1x1 com física livre estilo Gang Beasts, câmera arcade
fixa, **7 eventos caóticos**, **2 jogadores no mesmo teclado**, **áudio 100% sintetizado**
e menu com pausa e revanche.

Tudo é gerado por código (primitivas low-poly) ou sintetizado por script: **nenhum asset
externo**, nenhuma dependência de Blender para rodar.

## Rodar

```bash
godot --path .            # abre no jogo, direto no menu
godot -e --path .         # abre no editor
```

Requisitos: Godot 4.6 (renderer GL Compatibility, roda em qualquer máquina).

Os sons são versionados em `assets/audio/`. Para regerar (não precisa de nada instalado
além de Python 3):

```bash
python3 tools/gen_audio.py
godot --headless --path . --import
```

## Menu e modos

Na tela inicial: **`1`** = um jogador contra o bot, **`2`** = dois jogadores no mesmo
teclado. `ESC` pausa durante a partida; no menu da pausa, `ENTER` volta para o início.

| Momento | Tecla |
| --- | --- |
| Começar 1P x bot | `1` (ou `ENTER`) |
| Começar 2 jogadores | `2` |
| Pausar / continuar | `ESC` ou `P` |
| Sair para o menu | `ESC` (no fim) ou `ENTER` (na pausa) |
| Reiniciar partida | `R` |

### Jogador 1 (AZUL, ataca para a direita)

| Ação | 1 jogador | 2 jogadores |
| --- | --- | --- |
| Mover | `A` / `D` ou setas | `A` / `D` |
| Pular | `W` ou `↑` | `W` |
| Chutar | `ESPAÇO` | `ESPAÇO` |
| Carrinho / soco | `SHIFT` ou `J` | `SHIFT` |

### Jogador 2 (VERMELHO, ataca para a esquerda)

| Ação | Tecla |
| --- | --- |
| Mover | `←` / `→` |
| Pular | `↑` |
| Chutar | `ENTER` (ou `ENTER` do teclado numérico) |
| Carrinho / soco | `CTRL` (ou `0` do numérico) |

Partida de 2 minutos. No modo 1 jogador, o vermelho é controlado por um bot que persegue
a bola por trás, chuta, pula em bola alta e às vezes se atrapalha de propósito.

## Eventos

A cada ~10–16s a partida avisa (`⚠ PREPARE-SE`) e ativa um evento por tempo limitado.
Há 35% de chance de **dois eventos ao mesmo tempo**.

| Evento | Efeito |
| --- | --- |
| PERNAS GIGANTES | pernas 3x maiores, alcance e potência de chute absurdos |
| CABEÇÃO | cabeça enorme com colisor real, cabeçadas fortes, equilíbrio péssimo |
| BOLA DE BORRACHA | bola muito mais elástica, leve e rosa |
| CAMPO DE TRAMPOLIM | chão e jogadores quicando sem parar |
| VELOCIDADE ABSURDA | todo mundo 2x mais rápido e muito mais difícil de controlar |
| BRIGA GENERALIZADA | `SHIFT` vira soco; a bola fica no campo, mas ninguém quer jogar |
| INVASÃO DOS GIGANTES | um jogador aleatório (seu ou do adversário) vira um gigante |

## Áudio

Sons sintetizados por `tools/gen_audio.py` (Python puro, sem dependências): chute,
pancada, quique da bola, whoosh de carrinho, apito, gol com torcida, vinheta de evento,
beeps de contagem, clique de menu e uma ambiência de estádio em loop que acompanha a
emoção da partida (sobe no gol, cai no jogo morno).

## Feedback visual

Poeira nos pousos/carrinhos/chutes, rastro na bola veloz, squash nos personagens e na
bola, flash de tela colorido no gol e tremor de câmera proporcional à pancada.

## Teste automatizado

Roda bot x bot acelerado, força os 7 eventos, arremessa uma bola para o gol e valida
tudo no terminal (código de saída 1 em caso de falha):

```bash
godot --headless --path . -- --smoke
```

Ferramentas de desenvolvimento (não afetam o jogo normal):

```bash
godot --path . -- --shot        # salva .preview/preview.png do jogo em câmera lenta
godot --path . -- --shot-menu   # salva .preview/preview.png do menu inicial
```

## Arquitetura

```
main.tscn                 cena raiz (só o script)
scripts/game.gd           partida: estados, menu, pausa, gols, kickoff, câmera, smoke test
scripts/player.gd         corpo físico, chute, carrinho, stun/ragdoll-lite, proporções, teclas
scripts/ball.gd           bola com colisões, rastro e modificadores de evento
scripts/bot_brain.gd      IA simples (persegue por trás, chuta, pula)
scripts/stadium.gd        gramado, gols, arquibancada, torcida, luz
scripts/hud.gd            placar, cronômetro, banner de evento, mensagens, flash
scripts/menu.gd           menu inicial e tela de pausa
scripts/audio.gd          pool de efeitos + torcida em loop com intensidade
scripts/fx.gd             poeira e rastro (CPUParticles3D)
scripts/event_manager.gd  aviso -> ativação -> duração -> limpeza (+ combos)
scripts/events/*.gd       um arquivo por evento
tools/gen_audio.py        síntese de todos os sons (gera assets/audio/*.wav)
```

### Adicionar um evento novo

1. Crie `scripts/events/meu_evento.gd` estendendo `GameEvent`.
2. No `apply()` ligue o efeito (prefira `player.add_modifier(id, {...})` ou `ball.add_modifier`).
3. No `clear()` desligue **só** o que você ligou.
4. Registre o script no `POOL` de `event_manager.gd`.

O gerenciador cuida de aviso, duração, combinação e limpeza.

## Próximos passos

- Modelos e animações no Blender (humanoide com esqueleto + ragdoll real via `PhysicalBoneSimulator3D`).
- Multiplayer online.
- Modos de jogo: primeiro a 5, sobrevivência, treino de chute.
- Mais eventos (campo inclinado, goleiro galinha, bola imã, chuva de bolas) e eventos por time.
- Seleção de eventos e placar persistente.

## Git

Fluxo Gitflow + commits com gitmoji em [`CONTRIBUTING.md`](CONTRIBUTING.md).
