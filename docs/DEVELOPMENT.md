# Desenvolvimento, depuração e manutenção

Guia para quem vai abrir o FutCrazy na Godot e continuar o trabalho. Todos os comandos e
caminhos abaixo foram executados neste repositório.

## 1. Requisitos

- **Godot 4.6** (o projeto foi verificado em `4.6.3.stable.official`). `godot --version`
  deve responder `4.6.x`.
- Nada além disso: sem plugins, sem addons, sem dependência externa em tempo de execução.
- Python 3 é opcional, só para regerar áudio (`tools/gen_audio.py`) e modelos
  (`tools/blender/`).

## 2. Abrir o projeto

```bash
godot --path .          # abre o jogo direto (F5 equivalente)
godot -e --path .       # abre o editor
godot --headless --path . --import   # reimporta assets sem abrir janela
```

O `--import` é o que você roda depois de puxar assets novos ou trocar `.wav`/`.glb`/`.png`.

## 3. Cena principal e árvore de nós

Cena principal: **`main.tscn`** (`run/main_scene` em `project.godot`). Ela **não é vazia** —
a hierarquia é explícita e inspecionável:

```
Main                (Node3D)  scripts/game.gd      orquestra partida, estados e testes
├─ WorldEnvironment (WorldEnvironment)              céu e luz ambiente (recurso embutido)
├─ Camera           (Camera3D)                      ortográfica, enquadramento do campo
├─ Stadium          (Node3D)  scripts/stadium.gd   estádio procedural
├─ Ball             (RigidBody3D) scripts/ball.gd  bola
├─ Sfx              (Node)    scripts/audio.gd     efeitos + torcida
├─ Events           (Node)    scripts/event_manager.gd
├─ Hud              (CanvasLayer) scripts/ui/hud.gd
└─ Menu             (CanvasLayer) scripts/ui/menu.gd
```

`game.gd` referencia esses nós por caminho fixo e tipado (`@onready var stadium: Stadium = $Stadium`).
No topo de `scripts/game.gd` está a lista; se renomear um nó na cena, atualize ali (o parser
tipado avisa na hora).

**Jogadores não estão na cena.** Eles são criados em `_spawn_players()` porque a quantidade
muda com o modo (2 no arcade, 10 no campo todo). Nomes em tempo de execução:
`T0_field_0`, `T1_gk_0`, etc. (`T<time>_<papel>_<índice>`). Para vê-los, use a **Árvore de
cena remota** com o jogo rodando (seção 5).

No editor, o estádio, a bola e os jogadores de prévia aparecem porque `game.gd`, `stadium.gd`
e `ball.gd` são `@tool`. Esses nós de prévia **não são salvos** na cena (são criados em tempo
de execução, sem `owner`). `hud.gd` e `menu.gd` não são `@tool`: no editor eles aparecem como
`CanvasLayer` vazios, e constroem a interface quando o jogo roda.

## 4. Rodar cenas individuais (F6)

| Cena | Para que serve |
| --- | --- |
| `main.tscn` | jogo completo, começando no menu |
| `scenes/dev/ui_gallery.tscn` | todas as telas de UI sem jogar (ajustar layout/cores) |
| `scenes/dev/sandbox.tscn` | entra direto no campo todo (5x5), herdando `main.tscn` |

```bash
godot --path . scenes/dev/ui_gallery.tscn   # F6 na galeria
godot --path . scenes/dev/sandbox.tscn      # F6 no sandbox
```

**Galeria de UI** (`scripts/dev/ui_gallery.gd`): `0` mostra só o HUD, `1` menu, `2` modos,
`3` opções, `4` controles, `5` créditos, `6` pausa, `7` resultado, `ESC` volta. O HUD e o menu
nunca aparecem juntos (como no jogo), e o estádio fica ao fundo para você conferir contraste
e legibilidade no cenário real.

**Sandbox** é uma cena herdada de `main.tscn` com uma única sobrescrita no Inspector:
`Autostart Mode = Campo todo`. Para entrar direto em outro modo, abra
`scenes/dev/sandbox.tscn`, selecione o nó raiz e mude `Autostart Mode` no Inspector
(`Menu`, `1 jogador`, `2 jogadores`, `Campo todo`). O mesmo vale para qualquer cópia de
`main.tscn`: duplique, mude a propriedade e rode com F6.

## 5. Depurar

Fluxo normal, com o jogo rodando (`F5`):

1. **Árvore de cena remota** (Depurador → *Remote Scene Tree*): veja `Main`, os jogadores
   criados, o estádio montado e o `Hud`/`Menu`. Selecione um jogador e veja no Inspector
   `linear_velocity`, `stun_left`, `modifiers`, `is_human`, `role`.
2. **Breakpoints**: clique na margem do script. Pontos úteis:
   - `game.gd` → `start_match()`, `_on_goal()`, `_end_match()`, `_pause()`
   - `player.gd` → `_kick()`, `_check_hits()`, `_stand_up()`
   - `event_manager.gd` → `_activate()`, `_deactivate()`
   - `settings.gd` → `set_value()`
3. **Colisões**: Depurador → *Visible Collision Shapes*. Mostra as caixas dos jogadores, a
   esfera da bola, traves e chão.
4. **Monitores** (Depurador → *Monitors*): FPS, objetos, nós, memória. Útil no 5x5 com
   eventos combinados.
5. **Profiler** (Depurador → *Profiler*): confirme antes de otimizar. A física
   (`_physics_process`) é onde praticamente tudo acontece.
6. **Output**: o jogo imprime marcadores estáveis —
   `[PARTIDA] modo: ...`, `[GOL] time ...`, `[EVENTO] aviso/ativo`, `[FIM] ...`,
   `[SMOKE] ...`. Use como trilha de execução sem breakpoint.
7. **Vazamentos**: se aparecer `ObjectDB instances leaked`, rode com `--verbose` para ver os
   objetos. O caminho de saída normal (`_finish_and_quit`, `_notification`) já para o áudio e
   espera o AudioServer reciclar playbacks. Atenção: `--quit-after N` encerra à força e
   **por isso** pode imprimir esse aviso — não é vazamento do jogo.

### Armadilhas conhecidas

- **Estádio procedural**: a geometria só existe em tempo de execução. No editor você vê os
  nós, não o gramado completo. Rode `F5` e use a árvore remota.
- **`Cfg.field_half` é estático e muda por modo.** `_apply_layout()` troca o valor e remonta
  o estádio (`stadium.clear()` + `stadium.build()`). Se mexer em medidas, lembre disso.
- **UI é construída em código**, não em `.tscn`. Está em `scripts/ui/`; o tema e a paleta
  ficam em `ui_theme.gd`. Para ver o resultado use a galeria (`F6`) ou `--shot-*`.
- **Teclas** vivem no `InputMap` e são reconstruídas por `Settings.apply_input_map()`. Não
  leia teclas cruas com `Input.is_physical_key_pressed` no gameplay: use as ações `p1_*`/`p2_*`.
- **Pausa**: `match_state == "paused"` é o que trava o relógio e os eventos. `ball.freeze` e
  `player.freeze` são restaurados por `_resume()`.

## 6. Autoload

| Nome | Script | Responsabilidade |
| --- | --- | --- |
| `Settings` | `scripts/settings.gd` | configurações, persistência (`user://futcrazy.cfg`), buses de áudio, `InputMap`, aplicação de vídeo |

É o único autoload. `Settings` existe antes de qualquer cena; por isso `Hud`, `Menu` e `Sfx`
podem ler valores no `_ready()` sem depender de `Main`.

O arquivo de configuração do jogador fica em
`~/.local/share/godot/app_userdata/FutCrazy/futcrazy.cfg` no Linux. Apague-o para voltar ao
padrão (ou use `RESTAURAR PADRÕES` na tela de opções).

## 7. Sistemas e onde encontrá-los

| Sistema | Arquivo | Comece por |
| --- | --- | --- |
| estados da partida, gols, kickoff, pausa, resultado | `scripts/game.gd` | `_physics_process()` e `start_match()` |
| física e ações do jogador | `scripts/player.gd` | `_move()`, `_kick()`, `_balance()` |
| bola e modificadores de evento | `scripts/ball.gd` | `_refresh()` |
| IA de linha e goleiro | `scripts/bot_brain.gd` | `_think_field()`, `_think_gk()` |
| aviso → ativação → limpeza de eventos | `scripts/event_manager.gd` | `tick()`, `_activate()` |
| um evento | `scripts/events/*.gd` | `apply()` / `clear()` |
| estádio | `scripts/stadium.gd` | `build()` |
| áudio | `scripts/audio.gd` | `play()`, `shutdown()` |
| configurações | `scripts/settings.gd` | `DEFAULTS`, `apply_*()` |
| telas | `scripts/ui/menu.gd` | `_build_*()` |
| HUD | `scripts/ui/hud.gd` | `_build_scoreboard()`, `set_active_events()` |
| identidade visual | `scripts/ui/ui_theme.gd` | constantes de cor e `display_font()` |
| regras e medidas | `scripts/cfg.gd` | — |
| efeitos | `scripts/fx.gd` | `dust()`, `trail()` |

## 8. Fluxo de telas e estados

`match_state`: `menu` → `countdown` → `play` ⇄ `goal` → `end`, mais `paused` a partir de
`play`/`countdown`/`goal` (guarda `prev_state`).

```
Menu ──JOGAR──> Modos ──> start_match(mode) ──> countdown ──> play
                                                             ├─ gol → goal → play
                                                             ├─ ESC → paused
                                                             └─ tempo 0 → end (resultado)
paused: CONTINUAR → prev_state · REINICIAR → start_match · MENU → _open_menu
end: REVANCHE → start_match · MENU → _open_menu
```

Quem abre/fecha telas é `MenuScreen._open()`; o `game.gd` só reage aos sinais
`mode_selected`, `resume_requested`, `restart_requested`, `menu_requested`, `quit_requested`.

## 9. Testes

```bash
godot --headless --path . --import
godot --headless --path . -- --smoke        # arcade: eventos, gol, 2P, tempo ereto
godot --headless --path . -- --smoke-campo  # 5x5: 10 jogadores, 2 goleiros, gol, evento
godot --headless --path . -- --smoke-ui     # telas, persistência, teclas, eventos, áudio
```

Saída com código 0 = passou; 1 = falhou, com linhas `FALHA: ...`. O `--smoke-ui` percorre os
fluxos reais (não depende de teclado nem de sorte da física) e é o mais indicado ao mexer em
UI, opções ou estado da partida.

Capturas (salvam `.preview/preview.png`):

```bash
godot --path . -- --shot          # gameplay arcade
godot --path . -- --shot-campo    # gameplay 5x5
godot --path . -- --shot-menu     # menu
godot --path . -- --shot-modes    # modos
godot --path . -- --shot-options  # opções
godot --path . -- --shot-controls # controles
godot --path . -- --shot-credits  # créditos
godot --path . -- --shot-pause    # pausa
godot --path . -- --shot-result   # resultado
```

Se o ambiente não deixar capturar a janela (X sem compositor, CI gráfico), use o Movie Maker
do próprio Godot — ele renderiza pelo engine e não depende do sistema de janelas:

```bash
godot --path . --write-movie /tmp/clip.avi --quit-after 90 scenes/dev/ui_gallery.tscn
ffmpeg -loglevel error -i /tmp/clip.avi -vf "select=eq(n\,70)" -frames:v 1 -y .preview/gallery.png
```

## 10. Receitas

### Adicionar um evento

1. `scripts/events/meu_evento.gd` estendendo `GameEvent`, com `id`, `title`, `color`,
   `duration`.
2. `apply()` liga o efeito (`p.add_modifier(id, {...})`, `game.ball.add_modifier(...)`,
   `game.slope = ...`).
3. `clear()` desliga **só** o que ligou. Se mexeu na dica do HUD, chame `game.restore_hint()`.
4. Registre o script no `POOL` de `scripts/event_manager.gd`.
5. `--smoke` (que força a sequência do pool) já cobre o disparo; `--smoke-ui` valida que
   nenhum modificador fica residual.

### Adicionar uma opção

1. Declare a chave em `DEFAULTS` de `scripts/settings.gd` e um getter tipado.
2. Aplique o efeito no sistema que ela controla (ex.: `apply_audio()`, ou leitura no
   `game.gd`/`bot_brain.gd`).
3. Adicione a linha em `_build_*_section()` de `scripts/ui/menu.gd`
   (`_add_slider`, `_add_toggle`, `_add_choice` já cuidam de persistir e atualizar).
4. Cubra com uma verificação em `_run_ui_smoke()` (`scripts/game.gd`).

### Adicionar uma cena

1. Crie em `scenes/` (jogo) ou `scenes/dev/` (ferramenta de desenvolvimento).
2. Nomeie os nós pelo que eles são (`Camera`, `Ball`, `Hud`), não por tipo genérico.
3. Se a cena for o jogo, adicione o nó em `main.tscn` **e** a referência `@onready` em
   `scripts/game.gd`.
4. Rode com F6 e confirme que abre sozinha, sem depender de estado deixado por outra cena.

### Ajustar o visual da interface

`scripts/ui/ui_theme.gd` é a fonte única: cores, tipografia e caixas. Depois de mexer, rode
`scenes/dev/ui_gallery.tscn` (F6) e percorra as telas com `1`..`7`; para o HUD, aperte `H` e
compare com `--shot`.

## 11. Git e estilo

Gitflow + gitmoji — veja [`CONTRIBUTING.md`](../CONTRIBUTING.md). Antes de abrir PR, rode os
três testes headless. Não commite `.preview/` (já ignorado) nem `export_presets.cfg`.

## 12. Limitações conhecidas

- A UI é montada em código; não há `.tscn` por tela. Foi uma escolha para os testes headless
  exercitarem as telas reais. Se o `menu.gd` crescer, divida por tela.
- O ragdoll real (`PhysicalBoneSimulator3D`) não existe: o corpo é caixa rígida.
- Não há presets de exportação no repositório.
- A licença do repositório ainda está pendente (veja `ASSET_LICENSES.md`).
