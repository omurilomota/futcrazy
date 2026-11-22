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

Escopos usados: `player`, `ball`, `bot`, `eventos`, `hud`, `stadium`, `game`, `git`, `docs`.

## Qualidade mínima antes de abrir PR

```bash
godot --headless --path . -- --smoke
```
