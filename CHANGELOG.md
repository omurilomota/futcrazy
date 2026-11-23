# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e
versionamento semântico.

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
