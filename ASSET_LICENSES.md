# Licenças de assets

O MVP **não usa nenhum asset externo**: modelos, materiais, estádio, torcida e UI são
gerados proceduralmente em GDScript (primitivas do próprio Godot).

| Item | Origem | Licença | Atribuição exigida |
| --- | --- | --- | --- |
| Todos os modelos/materiais | código do projeto (`scripts/`) | mesma do repositório | não |
| Fonte da UI | fonte padrão do Godot | OFL (embutida na engine) | não |
| Engine | Godot 4.6 | MIT | não (não redistribuímos binários da engine) |

## Regra para assets futuros

Ao adicionar qualquer arquivo externo (modelo, textura, som, fonte, animação), registre
nesta tabela: **arquivo, autor, origem (URL), licença e exigência de atribuição**.
Sem essa linha, o asset não entra no repositório.

Fontes previstas: Kenney (CC0), Poly Pizza, Sketchfab (licença por arquivo), itch.io.
