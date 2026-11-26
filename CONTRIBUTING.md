# Contribuindo

Projeto usa **Gitflow** + **Gitmoji**. O hook `_githooks/commit-msg` valida a mensagem.

## Setup (uma vez por clone)

```bash
git config core.hooksPath _githooks
chmod +x _githooks/commit-msg
```

## Gitflow

| Branch | Papel |
| --- | --- |
| `main` | somente versões jogáveis/estáveis, cada merge recebe uma tag `vX.Y.Z` |
| `develop` | integração do dia a dia (branch padrão de trabalho) |
| `feature/<nome>` | uma feature, saindo de `develop`, voltando via merge `--no-ff` |
| `release/<versao>` | estabilização antes de ir para `main` |
| `hotfix/<nome>` | correção urgente, sai de `main` e volta para `main` e `develop` |

Fluxo normal:

```bash
git switch develop
git switch -c feature/evento-bola-de-fogo
# ... commits ...
git switch develop
git merge --no-ff feature/evento-bola-de-fogo
git branch -d feature/evento-bola-de-fogo
```

Publicação de versão:

```bash
git switch -c release/0.2.0 develop
# ajustes finais
git switch main
git merge --no-ff release/0.2.0
git tag -a v0.2.0 -m "v0.2.0"
git switch develop
git merge --no-ff release/0.2.0
```

## Gitmoji

Formato: `<emoji> <tipo>(escopo): descrição no imperativo, minúscula, sem ponto final`

```
✨ feat(player): chute com recuo e cambaleio
🐛 fix(eventos): trampolim não limpa o bounce do chão
📝 docs(readme): controles e tabela de eventos
```

| Emoji | Tipo | Uso |
| --- | --- | --- |
| 🎉 | chore | início de projeto |
| ✨ | feat | nova funcionalidade |
| 🐛 | fix | correção de bug |
| 📝 | docs | documentação |
| 💄 | style | visual/UI sem mudar lógica |
| ♻️ | refactor | reorganização sem mudar comportamento |
| ⚡ | perf | performance |
| ✅ | test | testes |
| 🧪 | test | teste automatizado/experimento |
| 🔧 | chore | configuração |
| 🚧 | chore | trabalho em progresso |
| 🎨 | style | assets/visual |
| 🥅 | feat | regra de jogo/futebol |
| 🔥 | chore | remoção de código |
| 🚀 | chore | release |

Escopos usados: `player`, `ball`, `bot`, `eventos`, `hud`, `menu`, `audio`, `fx`, `stadium`, `game`, `git`, `docs`.

## Qualidade mínima antes de abrir PR

```bash
godot --headless --path . --import          # reimporta assets novos
godot --headless --path . -- --smoke        # arcade: eventos, gol, modo 2P
godot --headless --path . -- --smoke-campo  # campo todo: 5x5, goleiros, gol
godot --headless --path . -- --smoke-ui     # telas, persistência, teclas, áudio
```

O CI (`.github/workflows/ci.yml`) roda exatamente esses passos na Godot 4.6.3. Se algum
teste falhar, corrija a causa — não relaxe a verificação.

Se mexer em `tools/gen_audio.py`, regere e versione os sons:

```bash
python3 tools/gen_audio.py
godot --headless --path . --import
```

## Onde mexer

| Quero mudar... | Arquivo |
| --- | --- |
| cores, tipografia, caixas | `scripts/ui/ui_theme.gd` |
| menu, modos, opções, controles, pausa, resultado | `scripts/ui/menu.gd` |
| placar, banner de evento, mensagens | `scripts/ui/hud.gd` |
| uma opção nova | `scripts/settings.gd` (+ linha em `menu.gd`) |
| regra de partida, estados, gols | `scripts/game.gd` |
| física e ações do jogador | `scripts/player.gd` |
| um evento | `scripts/events/` + `POOL` em `event_manager.gd` |
| ajustar a UI sem jogar | `scenes/dev/ui_gallery.tscn` (F6) |
| entrar direto no 5x5 | `scenes/dev/sandbox.tscn` (F6) |

Antes de caçar no código, [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) tem a árvore de nós
da cena principal, os autoloads, como rodar cenas isoladas, breakpoints úteis e receitas de
debug (colisões, monitores, profiler).

Não adicione opção que não funcione nem botão decorativo: a tela de opções é contrato com
quem joga.
