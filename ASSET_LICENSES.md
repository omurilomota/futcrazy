# Licenças de assets

O projeto **não usa nenhum asset externo**: modelos, materiais, estádio, torcida, interface,
tipografia e efeitos sonoros são gerados pelo próprio projeto (código ou ferramentas do
repositório).

| Item | Origem | Licença | Atribuição exigida |
| --- | --- | --- | --- |
| Modelos e materiais 3D (`assets/models/*.glb`) | `tools/blender/` (gerados pelo projeto) | mesma do repositório | não |
| Estádio, torcida, jogadores, bola, UI e efeitos | código do projeto (`scripts/`) | mesma do repositório | não |
| Todos os sons (`assets/audio/*.wav`) | síntese por `tools/gen_audio.py` | mesma do repositório | não |
| Tipografia da interface | fonte de fallback embutida na engine Godot, deformada em tempo de execução por `FontVariation` (peso e espaçamento) | OFL (embutida na engine) | não |
| Ícone (`icon.svg`) | desenhado no próprio projeto | mesma do repositório | não |
| Engine | Godot 4.6 | MIT | não (não redistribuímos binários da engine) |

Os `.wav` e os `.glb` são artefatos reproduzíveis: qualquer pessoa regenera com
`python3 tools/gen_audio.py` (síntese com semente fixa; o ruído pode variar entre versões do
Python) e com os scripts de `tools/blender/`.

## Regra para assets futuros

Ao adicionar qualquer arquivo externo (modelo, textura, som, fonte, animação), registre
nesta tabela: **arquivo, autor, origem (URL), licença e exigência de atribuição**.
Sem essa linha, o asset não entra no repositório.

Fontes previstas: Kenney (CC0), Poly Pizza, Sketchfab (licença por arquivo), itch.io.

## Licença do repositório

**Pendente de decisão do proprietário.** Não existe arquivo `LICENSE` no repositório e este
trabalho não escolhe uma licença por conta própria. Enquanto não houver decisão, trate o
código como "todos os direitos reservados". Como não há asset de terceiros, a escolha fica
livre — MIT ou Apache-2.0 são as opções mais simples para o código.
