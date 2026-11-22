# FutCrazy 🥅

> **Não é um simulador de futebol. É um jogo de comédia física cujo cenário é uma partida de futebol.**

MVP jogável em Godot 4.6: partida 1 jogador x bot, física livre estilo Gang Beasts,
câmera arcade fixa e **7 eventos caóticos** que viram a partida do avesso.

Tudo é gerado por código (primitivas low-poly): **nenhum asset externo**, nenhuma
dependência de Blender para rodar o MVP.

## Rodar

```bash
# abrir no editor
godot --path .

# rodar direto
godot --path .
```

Requisitos: Godot 4.6 (renderer GL Compatibility, roda em qualquer máquina).

## Controles

| Ação | Tecla |
| --- | --- |
| Mover | `A` / `D` (ou setas) |
| Pular | `W` |
| Chutar | `ESPAÇO` |
| Carrinho (soco na briga generalizada) | `SHIFT` |
| Reiniciar | `R` |

Partida de 2 minutos. Você é o time **AZUL** (esquerda), o bot é o **VERMELHO**.

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
| INVASÃO DOS GIGANTES | um jogador aleatório (seu ou do bot) vira um gigante |

## Teste automatizado

Roda bot x bot acelerado, força os 7 eventos, arremessa uma bola para o gol e valida
tudo no terminal (código de saída 1 em caso de falha):

```bash
godot --headless --path . -- --smoke
```

## Arquitetura

```
main.tscn                 cena raiz (só o script)
scripts/game.gd           partida: relógio, gols, kickoff, restart, câmera, smoke test
scripts/player.gd         corpo físico, chute, carrinho, stun/ragdoll-lite, proporções
scripts/ball.gd           bola com colisões e modificadores de evento
scripts/bot_brain.gd      IA simples (persegue por trás, chuta, pula)
scripts/stadium.gd        gramado, gols, arquibancada, torcida, luz
scripts/hud.gd            placar, cronômetro, banner de evento, mensagens
scripts/event_manager.gd  aviso -> ativação -> duração -> limpeza (+ combos)
scripts/events/*.gd       um arquivo por evento
```

### Adicionar um evento novo

1. Crie `scripts/events/meu_evento.gd` estendendo `GameEvent`.
2. No `apply()` ligue o efeito (prefira `player.add_modifier(id, {...})` ou `ball.add_modifier`).
3. No `clear()` desligue **só** o que você ligou.
4. Registre o script no `POOL` de `event_manager.gd`.

O gerenciador cuida de aviso, duração, combinação e limpeza.

## Próximos passos

- Modelos e animações no Blender (humanoide com esqueleto + ragdoll real via `PhysicalBoneSimulator3D`).
- Multiplayer local 2P e depois online.
- Áudio: chute, torcida, gol, vinheta de evento (hoje o jogo é mudo).
- Mais eventos (campo inclinado, goleiro galinha, bola imã, chuva de bolas).
- Modos de jogo: primeiro a 5, sobrevivência, treino de chute.

## Git

Fluxo Gitflow + commits com gitmoji em [`CONTRIBUTING.md`](CONTRIBUTING.md).
