class_name Cfg
extends RefCounted

## Dimensões e regras globais do MVP.
## Campo jogado no plano XY (profundidade Z travada) = "2.5D".

const FIELD_HALF := 8.0          ## metade do comprimento do campo (gol em x = +/- FIELD_HALF)
const GOAL_H := 2.9              ## altura da boca do gol
const GOAL_DEPTH := 1.5          ## profundidade da rede
const GOAL_HALF_W := 1.25        ## meia largura da boca do gol em Z (só visual/colisão)
const BALL_RADIUS := 0.32

const MATCH_TIME := 120.0        ## duração da partida em segundos
const START_COUNTDOWN := 3.0
const GOAL_PAUSE := 2.0

const TEAM_A_NAME := "AZUL"
const TEAM_A_COLOR := Color("#3b82f6")
const TEAM_B_NAME := "VERMELHO"
const TEAM_B_COLOR := Color("#ef4444")
