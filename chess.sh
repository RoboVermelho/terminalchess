#!/bin/bash
# Script para jogos de xadrez no terminal. Apenas utilizando UTF-8 para
# as peças. Além de receber comandos pelo terminal.
#Alguns detalhes sobre o shell que não conhecia:
#não dá suporte para arrays multidimensionais.
#funções retornam apenas valores inteiros que variam de 0 a 255 (ou seja
#apenas um byte. Porém, acessam livremente variáveis de contexto global, o
#que me faz pensar que talvez não exista nem contexto (depois é melhor
#testar, criando uma variável dentro de uma função e posteriormente tentar
#acessá-la no nível mais externo.

DEBUG=1
## Peças do tabuleiro
W_KING="\u2654"
W_QUEEN="\u2655"
W_ROOK="\u2656"
W_BISHOP="\u2657"
W_KNIGHT="\u2658"
W_PAWN="\u2659"

B_KING="\u265A"
B_QUEEN="\u265B"
B_ROOK="\u265C"
B_BISHOP="\u265D"
B_KNIGHT="\u265E"
B_PAWN="\u265F"
#NÃO MODIFICAR A ORDEM DAS PEÇAS!!! - UTILIZADO EM VERIFICA_DEFESA_REI
PECAS_BRANCAS=($W_KING $W_QUEEN $W_ROOK $W_KNIGHT $W_BISHOP $W_PAWN)
PECAS_PRETAS=($B_KING $B_QUEEN $B_ROOK $B_KNIGHT $B_BISHOP $B_PAWN)
COLS=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
TURNO=W #Vou utilizar essa variável para definir de quem é a vez de jogar.
MOV="" #Captura o movimento a ser feito.
POSICAO="" #Armazena uma posição do tabuleiro no formato [A-H][1-8]
ATAQUE_AO_REI=() #Array que armazena peças atacantes ao rei no formato
BLACK=1
WHITE=0
POS_KG_BLACK=0
POS_KG_WHITE=0
#numérico
declare -A TAB #Tabuleiro

#Reorganiza a variável global TAB com as posições iniciais do tabuleiro.
#Não deu certo colocar a referência a um array de peças dentro da função
#como utilizando: $1[B_ROOK], ficava aparecendo o ícone e o [B_ROOK] na
#impressão, por isso, acabei usando o acesso direto às variáveis globais.
function tabuleiro_inicial() {
  TAB[1]=$B_ROOK
  TAB[33]=$B_ROOK
  TAB[2]=$B_KNIGHT
  TAB[3]=$B_BISHOP
  TAB[22]=$B_QUEEN
  #TAB[4]=$B_QUEEN
  TAB[5]=$B_KING
  TAB[6]=$B_BISHOP
  TAB[7]=$B_KNIGHT
  TAB[8]=$B_ROOK

  TAB[9]=$B_PAWN
  TAB[10]=$B_PAWN
  TAB[11]=$B_PAWN
  TAB[12]=$B_PAWN
  TAB[13]=$B_PAWN
  TAB[14]=$B_PAWN
  TAB[15]=$B_PAWN
  TAB[16]=$B_PAWN
  TAB[37]=$B_PAWN
  POS_KG_BLACK=5

  TAB[49]=$W_PAWN
  TAB[50]=$W_PAWN
  TAB[51]=$W_PAWN
  TAB[52]=$W_PAWN
  TAB[53]=$W_PAWN
  TAB[54]=$W_PAWN
  TAB[55]=$W_PAWN
  TAB[56]=$W_PAWN

  TAB[57]=$W_ROOK
  TAB[58]=$W_KNIGHT
  TAB[59]=$W_BISHOP
  TAB[60]=$W_QUEEN
  TAB[46]=$W_KING
  #TAB[61]=$W_KING
  TAB[62]=$W_BISHOP
  TAB[63]=$W_KNIGHT
  TAB[64]=$W_ROOK
  POS_KG_WHITE=46
}

tabuleiro_inicial;

#Esta função imprime a atual configuração do tabuleiro de acordo com a
#posição das peças na variável global TAB.
imprimir_tabuleiro() {
  #clear
  cont=8
  printf "   "
  for i in A B C D E F G H; do
    printf "$i "
  done
  for i in {1..64}; do
    if [[ $(($i % 8)) = 1 ]]; then
      printf "\n$cont |"
      cont=$(($cont-1))
    fi
    if [[ "${TAB[$i]}" = "" ]]; then
      printf " |"
    else
      printf "${TAB[$i]}|"
    fi
  done
  printf "\n"
}

#Aguarda o movimento e valida.
#Vou começar a analisar os movimentos primeiro apenas levando em
#consideração as pretas, e analisando cada movimento peça por peça.
#Primeiro deve ser encontrado quem joga.
#Depois qual a peça que foi indicada -
#depois a casa, e verificar qual peça pode ser movida para a posição
#indicada.
recebe_movimento() {
    #echo $MOV
  #Supondo que o movmento é de peão (não aparece designação de peça).
  #Movimentos permitidos: peão só à frente, ou fazendo a tomada de
  #passagem. (Tomando pelo lado em diagonal). Apenas no movimento de saída
  #ele pode avançar duas casas.
  #Desta forma, ao se encontrar a coluna do movimento, podemos levar em
  #consideração que apenas o peão da própria coluna ou das colunas laterais
  #podem tentar executar o movimento.
  #O movimento mais comum é o avanço de uma casa em frente, que pode acontecer quando:
  #a casa do meio não está empedida.
  #Depois a saída com duas casas que só pode acontecer se o peão está na
  #segunda linha de cada um dos lados (linha 7 para pretas e linha 2 para
  #brancas.
  #Bispos só se movimentam em diagonal
  #Cavalo se movimenta em L.
  #Torres em linha reta.
  #Dama se movimenta quantas casas quiser na posição que quiser
  #Rei anda em qualquer direção mas só uma casa por vez e não pode se
  #colocar em cheque.
  #Além destas regras, nenhuma peça pode colocar o rei em posição de
  #cheque.
  #Quando existe o xeque, a próxima jogada tem que tirar o  rei da posição
  #de cheque obrigatoriamente. Quando não há jogada possível para tirar o
  #rei da posição de xeque, é definido o xeque-mate.
  #Correção dos métodos: verificar sempre se a casa destino é uma casa em
  #branco ou se é uma casa das peças inimigas.
  #

  local tst=0
  tst=$(( 7 - 10 )) | tr -d -
  echo $tst
  local pos_rei=0
  local pos_num_rei=0
  local em_xeque=0
  local mate=0
  if [[ "$TURNO" == "W" ]]; then
    pos_num_rei=$POS_KG_WHITE
  else
    pos_num_rei=$POS_KG_BLACK
  fi
  deb "Posicao numerica antes movimento"
  referencia_posicao_numerica $pos_num_rei
  pos_rei=$POSICAO

  read -p "Digite o movimento: " MOV
  if [[ $MOV = "X" ]]; then
    exit
  fi;

  #Extrai apenas o código da posição destino
  if [[ ${#MOV} == 2 ]]; then
    pos_dest_cod=$MOV
  elif [[ ${#MOV} == 3 ]]; then
    pos_dest_cod=${MOV:1:2}
  fi

  if [[ ${#MOV} == 2 ]]; then #Peão
    teste_mov_peao $MOV
    pos_orig=$?
  elif [[ ${MOV:0:1} == "R" ]]; then #Torre
    teste_mov_torre ${MOV:1:2}
    pos_orig=$?
  elif [[ ${MOV:0:1} == "N" ]]; then #Cavalo
    teste_mov_cavalo ${MOV:1:2}
    pos_orig=$?
  elif [[ ${MOV:0:1} == "B" ]]; then #Bispo
    teste_mov_bispo ${MOV:1:2}
    pos_orig=$?
  elif [[ ${MOV:0:1} == "Q" ]]; then #Dama
    teste_mov_dama ${MOV:1:2}
    pos_orig=$?
  elif [[ ${MOV:0:1} == "K" ]]; then #Rei
    teste_mov_rei ${MOV:1:2}
    pos_orig=$?
  fi

  deb "Movimento selecionado"
  if [[ $pos_orig -gt 0 ]]; then
    posicao_disponivel $pos_orig
    local pos_disp=$?

    if [[ $pos_disp -eq 0 ]]; then
      printf "Movimento impossivel - casa ocupada \n"
      continue
    fi

    num_posicao $pos_dest_cod
    pos_dest=$?
    move_peca $pos_orig $pos_dest

    posicao_em_xeque $pos_rei
    em_xeque=$?

    if [[ $em_xeque -eq 1 ]]; then
      xeque_mate $pos_rei
      mate=$?
      if [[ $xeque_mate -eq 1 ]]; then
        print "Xeque mate, fim de jogo \n"
        exit
      else
        print "Seu rei esta em xeque, a posicao e invalida \n"
        move_peca $pos_dest $pos_orig #Desfaz movimento
      fi
    else
      troca_turno;
    fi
  fi
}

#Retorna o código UTF8 da peça movimentada de acordo com o turno e o código
#recebido no primeiro parâmetro. Que pode ser  [ RNBQK]
move_peca() {
  local ps_orig=$1
  local ps_dest=$2
  TAB[$ps_dest]="${TAB[$ps_orig]}"
  TAB[$ps_orig]=""
}

#Este método converte uma posição no formato [A-H][1-8] para a casa
#numérica, (que varia de 1 à 64). A contagem começa do topo do tabuleiro
#(A8) até a parte de baixo (G1)
num_posicao() {
  local pos="$1"
  declare -A cols
  local cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  local num_col=${cols[${pos:0:1}]}
  local num_lin=${pos:1:1}
  local posicao=$((64- $num_lin *8 + $num_col))
  return $posicao
}

#Teste do movimento do rei. Neste movimento, o rei pode andar apenas uma
#casa, em qualquer direção, porém a casa não pode estar em cheque, o mais
#complicado é verificar se a casa está em cheque.
#O mais simples é verificar se existem peças com movimentos permitidos que
#podem dar cheque ou seja:
#Peões: diagonais superiores.
#Torre: se está na mesma coluna ou mesma linha e não há peças no meio do
#caminho.
#Cavalo:  -2 colunas e (+-) 1 linha, +2 linhas e (+-)  linha
#-2 linhas e (+-) 1 coluna e  +2 linhas e (+-) 1 coluna.
#Bispo: na diagonal da casa (mesma diferença de colunas e linhas e casas
#vazias no caminho.
#Dama: o mesmo de torre e peão.
#Se a casa pretendida estiver em cheque o rei não pode se mover para a casa.
#Rei: todas as casas a uma casa de distância.
#Parametros:
#1 - Casa destino no formato [A-H][1-8]
teste_mov_rei() {
  local mov=$1
  declare -A cols
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  local num_col=${cols[${mov:0:1}]}
  local num_lin=${mov:1:1}
  local posicao=$((64-${mov:1:1}*8 + $num_col))
  local pos_base=""
  local mov_valido=0
  local pos=0
  local dist=0

  if [[ $TURNO == "W" ]]; then
    local peca="$W_KING"
    local inimigos=${PECAS_PRETAS[@]}
    local amigos=${PECAS_BRANCAS[@]}
  else
    local peca="$B_KING"
    local amigos=${PECAS_PRETAS[@]}
    local inimigos=${PECAS_BRANCAS[@]}
  fi
  posicao_disponivel "$amigos" "${TAB[$posicao]}"
  local pos_disponivel=$?
  if [[ $pos_disponivel -eq 0 ]]; then
    printf "Movimento inválido - casa destino ocupada \n"
    return 0
  fi

  #Distâncias relativas: -9 -8 -7 -1 1 7 8 9
  local posicoes=(-9 -8 -7 -1 1 7 8 9)
  local dist=0 #Distancia está ok ou não
  for ((i=0; i < 8; i++)) do
    pos=$(($posicao + ${posicoes[$i]}))
    if [[ "${TAB[$pos]}" == "$peca" ]]; then
      pos_base=$pos
      dist=1
      break
    fi
  done

  if [[ $dist -eq 0 ]]; then
    printf "Posicao impossivel - distancia incorreta \n"
    return 0
  fi

  posicao_em_xeque $1;
  pos_xeque=$?
  local posicao_em_xeque=0

  if [[ $pos_xeque -eq 0 ]]; then
    TAB[$pos_base]=""
    TAB[$posicao]="$peca"
    if [[ $TURNO == "W" ]]; then
      POS_KG_WHITE="$mov"
    else
      POS_KG_BLACK="$mov"
    fi

    troca_turno
  else
    printf "Movimento impossivel - casa em xeque \n"
    return 0
  fi
}

#Verifica se o rei do turno atual sofreu xeque-mate, para isso, a condição
#necessária é que: a posição está em xeque, o rei não pode se mover para
#nenhuma das casas possíveis, e que nenhuma outra peça aliada pode bloquear
#o xeque. Para verificar se uma peça tem a possibilidade de bloquear o
#ataque, primeiro armazeno todas as casas de trajetoria (caminhos de torre,
#bispo e dama, casas dos cavalos e dos peões), depois verifico se elas são
#acessiveis pelo jogador ameaçado. Se uma das casas é acessível, verifico se
#mesmo depois da ação a posição do rei continua em xeque. Se mesmo depois de
#todos os testes a posição continua em xeque, então é xeque-mate.
#Parametros: $1 -> posição do rei
#Retorno: 1 se xeque-mate 0 se não.
xeque_mate() {
  local xeque=0
  local pos_rei=$1
  posicao_em_xeque $pos_rei
  xeque=$?

  if [[ $xeque -eq 0 ]]; then
    return 0
  fi

  movimentos_rei $pos_rei #lista de movimentos do rei.
  if [[ $? -gt 0 ]]; then
    return 0
  fi
  #Carrega todas as casas que estão atacando o rei no array ATAQUE_AO_REI
  carrega_atacantes_rei $pos_rei

  #Verifica se uma das peças consegue bloquear o mate bloqueando um dos
  #atacantes, se depois de uma peça ser bloqueada o mate continua, então o
  #bloqueio não é efetivo.
  verifica_defesa_rei $pos_rei
  defesa_pos=$?

  if [[ $defesa_pos -eq 1 ]]; then
    return 0
  fi

  return 1 #O rei está em mate, não é possível movê-lo e não há como
  #bloquear as ameaças de forma efetiva, xeque-mate.
}

#Lista todos os atacantes de ATAQUE_AO_REI, e verifica de cada um deles se
#é possivel bloquear, se for possível, verifica se a posição continua em
#xeque mesmo após o bloqueio, se a mesma situação acontece com todas as
#peças, então não é possível defender o rei.
###################################
#Tipos de bloqueios:
#peão: bloquear o peão é ter a possibilidade de captura-lo, ja que ele dá
#xeque quando fica colado na diagonal.
#Torre: Se for um xeque em linha (as posições divididas por 8 tem o mesmo
#resultado). Verifica-se se as casas intermediarias da torre até o rei.
#Se na vertical (a divisão tem o mesmo resto) - se as casas em incremento de
#8 são acessíveis até a posição do rei.
#Cavalo: se alguem pode atacar a posição do cavalo.
#Bispo: verificar se a diferença de posições é multipla de 7 ou 9 e depois
#verificar as casas intermediárias como no caso da torre.
#Dama: fazer as verificações da torre e depois as do bispo.
###################################
#Parametros:
#1 - Posição do rei, formato [A-H][1-8]
#2 - Se o rei é preto ou branco.
#Retorno:
#1 se a defesa é possivel, 0 se não
#TODO: Continuar o método daqui.
verifica_defesa_rei() {
  local pc_atq="" #Armazena o tipo de peça que está atacando.
  local ps_rei=$1
  local cor_rei=$2
  local pecas=()
  declare -A indices
  local indices=([KING]=0 [QUEEN]=1 [ROOK]=2 [KNIGHT]=3 [BISHOP]=4 [PAWN]=5)
  local idx_tp_peca=0
  local lst_pc_atq=$ATAQUE_AO_REI
  local pos_bkp=0
  local prg_rei=0
  local bloqueio=""
  
  if [[ $cor_rei -eq $BLACK ]]; then
    pecas=$PECAS_BRANCAS
  else
    pecas=$PECAS_PRETAS
  fi
  bloqueio="${pecas[PAWN]}" #Um peão vai fingir ser o bloqueio.

  #printf "Lista de pecas: ${#lst_pc_atq[@]} \n"
  for i in "${ATAQUE_AO_REI[@]}"
  do
    printf "Valor de i -> $i \n"
    pc_atq=${TAB[$i]}
    #Teste do peão
    idx_tp_peca=${indices[PAWN]}
    if [[ "${TAB[$pc_atq]}" == "${pecas[$idx_tp_peca]}" ]]; then
      pos_bkp=$pc_atq
      TAB[$pc_atq]=""
      posicao_em_xeque $ps_rei
      prg_rei=$?
      if [[ $prg_rei -eq 0 ]]; then
        return 0
      else
        TAB[$pc_atq]="${pecas[$idx_tp_peca]}"
      fi
    fi

    idx_tp_peca=${indices[KNIGHT]}
    if [[ "${TAB[$pc_atq]}" == "${pecas[$idx_tp_peca]}" ]]; then
      pos_bkp=$pc_atq
      TAB[$pc_atq]=""
      posicao_em_xeque $ps_rei
      prg_rei=$?
      TAB[$pc_atq]="${pecas[$idx_tp_peca]}"
      if [[ $prg_rei -eq 0 ]]; then
        return 0
      fi
    fi

    local dist_torre=0
    local pos_num_rei=0
    num_posicao $pos_rei;
    pos_num_rei=$?

    idx_tp_peca=${indices[ROOK]}
    if [[ "${TAB[$pc_atq]}" == "${pecas[$idx_tp_peca]}" ]]; then
      dist_torre=$(( $pos_num_rei - $pc_atq ))
      if [[ $dist_torre -gt 7 ]]; then
        for i in $(seq $pc_atq $pos_num_rei)
        do
          pos_bkp=TAB[$i]
          TAB[$i]=$bloqueio
          posicao_em_xeque $ps_rei
          prg_rei=$?
          TAB[$i]=$pos_bkp
          if [[ $prg_rei -eq 0 ]]; then
            return 0
          fi
        done
      else
        for i in $(seq 8 $pc_atq $pos_num_rei)
        do
          pos_bkp=TAB[$i]
          TAB[$i]=$bloqueio
          posicao_em_xeque $ps_rei
          prg_rei=$?
          TAB[$i]=$pos_bkp
          if [[ $prg_rei -eq 0 ]]; then
            return 0
          fi
        done
      fi
    fi

    #Teste de bispo
    local dist_pc=0
    idx_tp_peca=${indices[BISHOP]}
    if [[ "${TAB[$pc_atq]}" == "${pecas[$idx_tp_peca]}" ]]; then
      dist_pc=$(( $pos_num_rei - $pc_atq ))
      if [[ $(( $dist_pc % 7)) -eq 0 ]]; then
        for i in $(seq $pc_atq 7 $pos_num_rei)
        do
          pos_bkp=TAB[$i]
          TAB[$i]=$bloqueio
          posicao_em_xeque $ps_rei
          prg_rei=$?
          TAB[$i]=$pos_bkp
          if [[ $prg_rei -eq 0 ]]; then
            return 0
          fi
        done
      else
        for i in $(seq 9 $pc_atq $pos_num_rei)
        do
          pos_bkp=TAB[$i]
          TAB[$i]=$bloqueio
          posicao_em_xeque $ps_rei
          prg_rei=$?
          TAB[$i]=$pos_bkp
          if [[ $prg_rei -eq 0 ]]; then
            return 0
          fi
        done
      fi
    fi

    #Teste de dama 
    local dist_pc=0
    idx_tp_peca=${indices[QUEEN]}
    if [[ "${TAB[$pc_atq]}" == "${pecas[$idx_tp_peca]}" ]]; then
      dist_pc=$(( $pos_num_rei - $pc_atq ))
      if [[ $(( $dist_pc % 7)) -eq 0 ]]; then
        for i in $(seq $pc_atq 7 $pos_num_rei)
        do
          pos_bkp=TAB[$i]
          TAB[$i]=$bloqueio
          posicao_em_xeque $ps_rei
          prg_rei=$?
          TAB[$i]=$pos_bkp
          if [[ $prg_rei -eq 0 ]]; then
            return 0
          fi
        done
      elif [[ $(( $dist_pc % 9)) -eq 0 ]]; then
        for i in $(seq 9 $pc_atq $pos_num_rei)
        do
          pos_bkp=TAB[$i]
          TAB[$i]=$bloqueio
          posicao_em_xeque $ps_rei
          prg_rei=$?
          TAB[$i]=$pos_bkp
          if [[ $prg_rei -eq 0 ]]; then
            return 0
          fi
        done
      elif [[ $(( $dist_pc % 8)) -eq 0 ]]; then
        for i in $(seq  $pc_atq 8 $pos_num_rei)
        do
          pos_bkp=TAB[$i]
          TAB[$i]=$bloqueio
          posicao_em_xeque $ps_rei
          prg_rei=$?
          TAB[$i]=$pos_bkp
          if [[ $prg_rei -eq 0 ]]; then
            return 0
          fi
        done
      else
        for i in $(seq $pc_atq $pos_num_rei)
        do
          pos_bkp=TAB[$i]
          TAB[$i]=$bloqueio
          posicao_em_xeque $ps_rei
          prg_rei=$?
          TAB[$i]=$pos_bkp
          if [[ $prg_rei -eq 0 ]]; then
            return 0
          fi
        done
      fi
    fi
  done
  return 1
}

#Carrega todas as posições que estão atacando a casa indicada no array
#ATAQUE_AO_REI
#Parâmetros:
#1 - Casa posição do rei no formato [A-H][1-8]
carrega_atacantes_rei() {
  ATAQUE_AO_REI=()
  declare pos_rei=$1
  teste_mov_dama $pos_rei
  printf "Ataque ao rei: ${#ATAQUE_AO_REI[@]} \n"
  teste_mov_bispo $pos_rei
  printf "Ataque ao rei: ${#ATAQUE_AO_REI[@]} \n"
  teste_mov_cavalo $pos_rei
  printf "Ataque ao rei: ${#ATAQUE_AO_REI[@]} \n"
  teste_mov_torre $pos_rei
  printf "Ataque ao rei: ${#ATAQUE_AO_REI[@]} \n"
  teste_ataque_peao $pos_rei
  printf "Ataque ao rei: ${#ATAQUE_AO_REI[@]} \n"
}

#Verifica quais são os movimentos possíveis do rei, baseado em sua posição
#atual, verificando casas disponíveis que não estão em xeque.
#Parametros:
#1 - Posição atual do rei no formato [A-H][1-8]
#Retorno:
#1 - Quantidade de casas possíveis para o rei se mover.
movimentos_rei() {
  printf "Teste movimentos rei \n"
  local cols=("A" "B" "C" "D" "E" "F" "G" "H")
  local pos_rei=$1
  local num_movs=0
  local pos_col=${cols[${pos_rei:0:1}]}
  local pos_lin=${pos_rei:1:1}
  local pos_num=0 #Posicao numerica à ser calculada.
  local pos_ref="" #Posicao referencial que será calculada
  local pos_xeque=0

  local itr_col=(-1  0  1 -1 1 -1 0 1)
  local itr_lin=(-1 -1 -1  0 0  1 1 1)

  for ((i=0; i < 8; i++)) do
    if [[ $(( $pos_col + ${itr_col[$i]})) -lt 9 ]] &&
       [[ $(( $pos_col + ${itr_col[$i]})) -gt 0 ]] &&
       [[ $(( $pos_lin + ${itr_lin[$i]})) -gt 9 ]] &&
       [[ $(( $pos_lin + ${itr_lin[$i]})) -gt 0 ]]; then
    pos_num=$(( ($pos_lin + ${itr_lin[$i]}) * 8 + $pos_col +
    ${itr_col[$i]} ))
    referencia_posicao_numerica $pos_num;
    posicao_em_xeque $POSICAO;
    pos_xeque=$?

    if [[ $pos_xeque -eq 0 ]]; then
      num_movs=$(( $num_movs+ 1 ))
    fi
  fi
  done
  return $num_movs
}

#Recebe uma posição numérica do tabuleiro - variando entre 1 e 64 - e
#carrega a variavel global POSICAO com a referência no padrão [A-H][1-8].
#Parâmetros:
#$1 -> Valor numérico entre 1 e 64.
referencia_posicao_numerica() {
  local cols=("A" "B" "C" "D" "E" "F" "G" "H")
  local pos_num=$1
  local pos_lin=$((8 - $pos_num / 8 ))
  local pos_num_col=$(( $pos_num % 8 ))
  if [[ $pos_num_col -gt 0 ]]; then
    pos_num_col=$(( $pos_num_col - 1))
  else
    pos_num_col=8
  fi
  POSICAO="${cols[$pos_num_col]}$pos_lin"
}

#Verifica se uma posicao do tabuleiro esta em xeque.
#Posso utilizar todos os testes das outras peças, mas para isso vou precisar
#refatorar o código, para que fique mais modular. Simplesmente, vou testar a
#movimentação de cada peça para a casa pretendida.
#Parametros: $1 -> posição à ser verificada no formato [A-H][1-8]
posicao_em_xeque() {
  local posicao="$1"
  troca_turno;
  teste_mov_dama $posicao
  local pos_em_xeque=$?
  if [[ $pos_em_xeque -gt 0 ]]; then
    troca_turno;
    return 1
  fi

  teste_mov_torre "$1"
  pos_em_xeque=$?
  if [[ $pos_em_xeque -gt 0 ]]; then
    troca_turno;
    return 1
  fi

  teste_mov_cavalo "$1"
  pos_em_xeque=$?
  if [[ $pos_em_xeque -gt 0 ]]; then
    printf "Ameaca cavalo \n"
    troca_turno;
    return 1
  fi

  teste_mov_bispo $1
  pos_em_xeque=$?
  if [[ $pos_em_xeque -gt 0 ]]; then
    printf "Ameaca bispo \n"
    troca_turno;
    return 1
  fi

  local mv=$1
  teste_ataque_peao "$1"
  pos_em_xeque=$?
  if [[ $pos_em_xeque -gt 0 ]]; then
    printf "Ameaca peao \n"
    troca_turno;
    return 1
  fi

  troca_turno;
  return 0
}

#Verifica se a posição em questão está disponível para ser usada, ou seja, a
#casa não está ocupada por uma peça aliada. Ainda sendo necessário
#posteriormente verificar se a casa não está ocupada por um rei
#Retorna 1 se disponível e 0 se não disponível.
#Parâmetros: $2 -> lista de peças aliadas.
#$3 -> posição a ser verificada
posicao_disponivel() {
  existe_na_posicao "$1" "$2"
  casa_tomada=$?
  if [[ $casa_tomada -eq 1 ]]; then
    return 0
  else
    return 1
  fi
}


#Teste de movimentação para a dama: ela se move quantas casas quiser, na
#direção que quiser, só não pula casas.
teste_mov_dama() {
  declare -A cols
  local mov=$1
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  local num_col=${cols[${mov:0:1}]}
  local num_lin=${mov:1:1}
  #local posicao=$((64-$num_lin *8 + $num_col))
  num_posicao $mov
  posicao=$?
  local pos_base=""
  local mov_valido=0

  if [[ $TURNO == "W" ]]; then
    printf "Turno branco \n"
    local peca="$W_QUEEN"
    local inimigos=${PECAS_PRETAS[@]}
    local amigos=${PECAS_BRANCAS[@]}
  else
    printf "Turno preto \n"
    local peca="$B_QUEEN"
    local amigos=${PECAS_PRETAS[@]}
    local inimigos=${PECAS_BRANCAS[@]}
  fi
  posicao_disponivel "$amigos" "${TAB[$posicao]}"
  local pos_disponivel=$?
  if [[ $pos_disponivel -eq 0 ]]; then
    printf "Movimento inválido - casa destino ocupada \n"
    return 0
  fi

  #Movimento horizontal ->
  local itr_tst=$(($num_col+1))
  local pos_tst=$(($posicao + $itr_tst))
  while [ $itr_tst -lt 9 ]; do
    pos_tst=$(($posicao + $itr_tst))
    if [[ "${TAB[$pos_tst]}" == "$peca" ]]; then
      pos_base=$pos_tst
      mov_valido=1
      break
    elif [[ "${TAB[$pos_tst]}" != "" ]]; then
      mov_valido=0
      break
    fi
    itr_tst=$(($itr_tst+1))
  done

  #Movimento horizontal <--
  if [[ $mov_valido -eq 0 ]]; then
    itr_tst=$(($num_col-1))
    while [ $itr_tst -gt 0 ]; do
      pos_tst=$(($posicao - $itr_tst))
      if [[ "${TAB[$pos_tst]}" == "$peca" ]]; then
        pos_base=$pos_tst
        mov_valido=1
        break
      elif [[ "${TAB[$pos_tst]}" != "" ]]; then
        mov_valido=0
        break
      fi
      itr_tst=$(($itr_tst-1))
    done
  fi
  printf "Movimento horizontal \n"

  #Teste de movimentos - Vertical
  if [[ $mov_valido -eq 0 ]]; then
    pos_tst=$(( $posicao + 8))
    while [ $pos_tst -lt 65 ]; do
      if [[ "${TAB[$pos_tst]}" == "$peca" ]]; then
        pos_base=$pos_tst
        mov_valido=1
        break
      elif [[ "${TAB[$pos_tst]}" != "" ]]; then
        mov_valido=0
        break
      fi
      pos_tst=$(( $pos_tst + 8))
    done
  fi

  if [[ $mov_valido -eq 0 ]]; then
   pos_tst=$(( $posicao - 8))
   while [ $pos_tst -gt 0 ]; do
      if [[ "${TAB[$pos_tst]}" == "$peca" ]]; then
        pos_base=$pos_tst
        mov_valido=1
        break
      elif [[ "${TAB[$pos_tst]}" != "" ]]; then
        mov_valido=0
        break
      fi
      pos_tst=$(( $pos_tst - 8))
    done
  fi

  printf "Movimento vertical \n"
  #Teste de diagonais
  if [[ $mov_valido -eq 0 ]]; then
    local diag_col=(-1 -1 1  1)
    local diag_lin=(-1  1 1 -1)
    local iteradores=(7 -7 -9 9)
    for ((a=0; a < 4; a++)) do
      local col_itr=${diag_col[$a]}
      local lin_itr=${diag_lin[$a]}
      local col_tst=$(($num_col + ${diag_col[$a]}))
      local lin_tst=$(($num_lin + ${diag_lin[$a]}))
      local itr=${iteradores[$a]}
      local pos_tst=$(($posicao + $itr))
      while [[ $col_tst -gt 0  &&  $col_tst -lt 9  &&  $lin_tst -gt 0  &&
               $lin_tst -lt 9 ]]; do
        if [[ "${TAB[$pos_tst]}" == "$peca" ]]; then
          pos_base=$pos_tst
          mov_valido=1
          break
        elif [[ "${TAB[$pos_tst]}" != "" ]]; then
          mov_valido=0
          break
        fi
        col_tst=$(($col_tst + $col_itr))
        lin_tst=$(($lin_tst + $lin_itr))
        pos_tst=$((pos_tst + $itr))
      done #Fim while.
        if [[ $mov_valido -eq 1 ]]; then
          break
        fi
    done
  fi
  printf "Teste de diagonais terminado \n"

  if [[ $mov_valido -eq 1 ]]; then
    ATAQUE_AO_REI+=($pos_base)
    return $pos_base
  else
    return 0
  fi
}

#Método que analisa a movimentação do cavalo (Knight). Para isso deve ser
#checado se existe um cavalo na posição em uma combinação de 2 colunas e 1
#linha ou vice-versa, positivo ou negativo. Não é preciso checar casas
#intermediárias, pq o cavalo é a unica peça que  pode pular outras peças.
teste_mov_cavalo() {
  local mov=$1
  declare -A cols
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  local num_col=${cols[${mov:0:1}]}
  local num_lin=${mov:1:1}
  #local posicao=$((64-${mov:2:1}*8 + $num_col))
  num_posicao $mov
  local pos_base=""
  local mov_valido=0
  if [[ $TURNO == "W" ]]; then
    local peca="$W_KNIGHT"
    local inimigos=${PECAS_PRETAS[@]}
    local amigos=${PECAS_BRANCAS[@]}
  else
    local peca="$B_KNIGHT"
    local amigos=${PECAS_PRETAS[@]}
    local inimigos=${PECAS_BRANCAS[@]}
  fi
  existe_na_posicao "$amigos" "${TAB[$posicao]}"
  local casa_tomada=$?
  if [[ $casa_tomada -eq 1  ||
      "${TAB[$posicao]}" == "$B_KING" ||
      "${TAB[$posicao]}" == "$W_KING" ]]; then
    printf "Movimento inválido - casa destino ocupada \n"
    return 0
  fi
  colunas_teste=(-2 -2  -1 1 2 2 -1 1)
  linhas_teste=(1 -1 -2 -2 -1 1 2 2)
  for ((i = 0; i < 8; i++)) do
    cl=$(( ${colunas_teste[$i]} + $num_col))
    ln=$(( ${linhas_teste[$i]} + $num_lin))
    ct_col=${colunas_teste[$i]}
    ct_lin=${linhas_teste[$i]}
    if [[ $cl -gt 0 && $cl -lt  9 && $ln -gt 0 && $ln -lt 9 ]]; then
     pos_base=$(($posicao + $ct_col + $ct_lin * 8))
     if [[ "${TAB[$pos_base]}" == "$peca" ]]; then
       ATAQUE_AO_REI+=($pos_base)
       mov_valido=$pos_base
     fi
    fi
  done
  if [[ $mov_valido -eq 0 ]]; then
    printf "Movimento inválido - posicao nao e possivel \n"
  fi
  return $mov_valido
}

#Método que analisa a movimentação da torre: a torre se move na vertical ou
#na horizontal, quantas casas quiser, não pode pular peças, e pode capturar
#qualquer peça. Nessa movimentação temos que verificar se a casa destino não
#é a ocupada pelo rei inimigo.
teste_mov_torre() {
  printf "Continuando teste \n"
  local mov=$1
  declare -A cols
  local cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  local num_col=${cols[${mov:0:1}]}
  local num_lin=${mov:1:1}
  num_posicao $mov
  local posicao=$?
  local pos_base=0
  local mov_valido=0
  local pol=0

  if [[ $TURNO == "W" ]]; then
    local peca="$W_ROOK"
  else
    local peca="$B_ROOK"
  fi
  #existe_na_posicao "$amigos" "${TAB[$posicao]}"
  #casa_tomada=$?

  #if [ $casa_tomada -eq 1 ]; then
  #  echo "Movimento inválido - casa destino ocupada \n"
  #  return 0
  #fi

  #Testamos se existe uma torre disponível, primeiro na horizontal,
  #depois na vertical.
  teste_col=$(($num_col-1))
  while [ $teste_col -gt -1 ];
  do
    pol=$((64-$num_lin*8 + $teste_col))
    if [[ "${TAB[$pol]}" == "" ]]; then
      teste_col=$(($teste_col-1))
    elif [[ "${TAB[$pol]}" == "$peca" ]]; then
      ATAQUE_AO_REI+=($pol)
      mov_valido=1
      pos_base=$pol
      break
    else
      break
    fi
  done

  #Continua fazendo testes para ver se mais de uma casa pode atacar.
  teste_col=$(($num_col+1))
  while [ $teste_col -lt 9 ];
  do
    pol=$((64-$num_lin*8 + $teste_col))
    if [[ "${TAB[$pol]}" == "" ]]; then
      teste_col=$(($teste_col+1))
    elif [[ "${TAB[$pol]}" == "$peca" ]]; then
      ATAQUE_AO_REI+=($pol)
      mov_valido=1
      pos_base=$pol
      break
    else #movimento invalido, encontrou uma peça aliada no caminho
      break
    fi
  done

  teste_lin=$(($num_lin+1))
  while [ $teste_lin -lt 9 ];
  do
    pol=$((64-$teste_lin*8 + $num_col))
    if [[ "${TAB[$pol]}" == "" ]]; then
      teste_lin=$(($teste_lin+1))
    elif [[ "${TAB[$pol]}" == "$peca" ]]; then
      ATAQUE_AO_REI+=($pol)
      mov_valido=1
      pos_base=$pol
      break
    else #movimento invalido, encontrou uma peça aliada no caminho
      break
    fi
  done

  teste_lin=$(($num_lin-1))
  while [ $teste_lin -gt -1 ];
  do
    pol=$((64-$teste_lin*8 + $num_col))
    if [[ "${TAB[$pol]}" == "" ]]; then
      teste_lin=$(($teste_lin-1))
    elif [[ "${TAB[$pol]}" == "$peca" ]]; then
      ATAQUE_AO_REI+=($pol)
      mov_valido=1
      pos_base=$pol
      break
    else #movimento invalido, encontrou uma peça aliada no caminho
      break
    fi
  done
  return $pos_base
}

#Com este método, vamos verificar a movimentação do bispo. 
#O bispo se movimenta em diagonal, quantas casas ele quiser, porém não pode
#pular peças, podendo capturar as peças que estiverem na sua área de
#movimento. Desta forma, temos o movimento normal, e a captura:
#movimento normal: se a diferença de colunas E a diferença de linhas entre a
#posição inicial e final são iguais E se não existem casas ocupadas nas
#posições intermediárias.
#movimento de captura: igual ao movimento normal, porém a ultima casa deve
#estar ocupada por uma casa inimiga.
#Para testarmos à partir da definição, temos que iterar as quatro diagonais
#da posição e verificar se alguma delas chega até um bispo.
#TODO: Continuar a fazer os testes com bispo, verificar o numero da coluna
#se não pode acontecer o bug do tabuleiro enrolado.
teste_mov_bispo() {
  declare -A cols
  local mov=$1
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  local num_col=${cols[${mov:1:1}]}
  local num_lin=${mov:2:1}
  num_posicao $mov
  local posicao=$?
  if [[ $TURNO == "W" ]]; then
    local peca="$W_BISHOP"
    local inimigos=${PECAS_PRETAS[@]}
  else
    local peca="$B_BISHOP"
    local inimigos=${PECAS_BRANCAS[@]}
  fi
  existe_na_posicao "$inimigos" "${TAB[$posicao]}"
  casa_tomada=$?
  mov_valido=0
  test_col=$num_col-1
  test_lin=$num_lin-1
  teste=$(($posicao-9))
  while [ $teste -gt 0 ];
  do
    if [ "${TAB[$teste]}" == $peca ]; then
      mov_valido=1
      break
    elif [ "${TAB[$teste]}" != "" ]; then
      break;
    fi
    teste=$(($teste-9))
  done

  if [ $mov_valido == 0 ]; then
    teste=$(($posicao-7))
    while [ $teste -gt 0 ];
      do
        if [ "${TAB[$teste]}" == $peca ]; then
          mov_valido=1
          break
        elif [ "${TAB[$teste]}" != "" ]; then
          break;
        fi
        teste=$(($teste-7))
    done
  fi

  if [ $mov_valido == 0 ]; then
    teste=$(($teste+7))
    while [ $teste -lt 64 ] || [ $teste -eq 64 ];
      do
        if [ "${TAB[$teste]}" == $peca ]; then
          mov_valido=1
          break
        elif [ "${TAB[$teste]}" != "" ]; then
          break;
        fi
        teste=$(($teste+7))
    done
  fi
  if [ $mov_valido == 0 ]; then
    teste=$(($teste+9))
    while [ $teste -lt 64 ] || [ $teste -eq 64 ];
      do
        if [ "${TAB[$teste]}" == $peca ]; then
          mov_valido=1
          break
        elif [ "${TAB[$teste]}" != "" ]; then
          break;
        fi
        teste=$(($teste+9))
    done
  fi

  if [ $mov_valido == 1 ]; then
    ATAQUE_AO_REI+=($mov_valido)
    return $teste
  else
    return 0
  fi
}

#Testa apaenas as casas de ataque do peão. Este método é utilizado para
#verificar casas em xeque.
#Parametros:
#1 - Casa destino no formato [A-H][1-8]
teste_ataque_peao() {
  num_posicao $1
  local posicao=$?
  local linha_itr=0
  local pos_ret=0 #Posição original que vai ser retornada.
  if [[ $TURNO == "W" ]]; then
    local peca="$W_PAWN"
    linha_itr=8
  else
    local peca="$B_PAWN"
    linha_itr=-8
  fi

  local pos_teste=$(($posicao + $linha_itr + 1))
  if [ "${TAB[$pos_teste]}" == $peca ]; then
    pos_ret=$(($posicao + $saida + 1))
    ATAQUE_AO_REI+=($pos_ret)
  fi

  local pos_teste=$(($posicao + $linha_itr - 1))
  if [ "${TAB[$pos_teste]}" == $peca ]; then
    pos_ret=$(($posicao + $saida - 1))
    ATAQUE_AO_REI+=($pos_ret)
  fi

return $pos_ret
}


#Recebe um movimento de peão e verifica se é possivel ser executado, se
#possível, retorna a casa destino (1 à 64) caso contrário, retorna  0.
teste_mov_peao() {
  mov=$1
  declare -A cols
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  num_col=${cols[${mov:0:1}]}
  #posicao=$((64-${mov:1:1}*8 + $num_col))
  num_posicao $mov
  local posicao=$?
  pos_ret=0 #Posição original que vai ser retornada.
  if [[ $TURNO == "W" ]]; then
    saida=8
    saida_dupla=16
    local peca="$W_PAWN"
    local peca_inv="$B_PAWN"
    local pos_inic=$((48+$num_col))
    local inimigos=${PECAS_PRETAS[@]}
  else
    saida=-8
    saida_dupla=-16
    local peca="$B_PAWN"
    local peca_inv="$W_PAWN"
    local pos_inic=$((8+$num_col))
    local inimigos=${PECAS_BRANCAS[@]}
  fi
  existe_na_posicao "$inimigos" "${TAB[$posicao]}"
  casa_tomada=$?
  #Saida de duas casas.
  if [ "${TAB[$(($posicao + $saida_dupla))]}" == $peca ]  &&
     [ "$(($posicao + $saida_dupla))" == "$pos_inic" ]  &&
     [ "${TAB[$posicao]}" == "" ]  &&
       [ "${TAB[$(($posicao + $saida))]}" == "" ]; then
    pos_ret=$(($posicao + $saida_dupla))
  #Movimento de uma casa.
  elif [ "${TAB[$(($posicao + $saida))]}" == $peca ] &&
       [ "${TAB[$posicao]}" == "" ]; then
    pos_ret=$(($posicao + $saida))
  #Tomada de peça.
  elif [ $casa_tomada -eq 1 ]; then

    if [ "${TAB[$(($posicao + $saida + 1))]}" == $peca ]; then
      pos_ret=$(($posicao + $saida + 1))
      ATAQUE_AO_REI+=($pos_ret)
    fi

    if [ "${TAB[$(($posicao + $saida - 1))]}" == $peca ]; then
      pos_ret=$(($posicao + $saida + 1))
      ATAQUE_AO_REI+=($pos_ret)
    fi
  fi
  return $pos_ret
}

#Verifica se a posição está disponível, para o movimento ser realizado.
#Parâmetros:
#1 - posição a ser verificada.
#
posicao_disponivel() {
  if [[ $TURNO == "W" ]]; then
    local posicao=$1
    local peca="$W_ROOK"
    local inimigos=${PECAS_PRETAS[@]}
    local amigos=${PECAS_BRANCAS[@]}
  else
    local peca="$B_ROOK"
    local amigos=${PECAS_PRETAS[@]}
    local inimigos=${PECAS_BRANCAS[@]}
  fi
  existe_na_posicao "$amigos" "${TAB[$posicao]}"
  casa_tomada=$?

  if [ $casa_tomada -eq 1 ]; then
    return 0
  else
    return 1
  fi
}

deb() {
  if [[ $DEBUG -eq 1 ]]; then
    printf "$1 \n"
  fi
}

#Recebe uma lista de peças e uma peça específica para verificar se a peça 
#existe dentro da lista, ou seja, é uma função para procurar dentro de uma
#string
existe_na_posicao() {
  str="$2"
  size=${#str}
  if [ $size -eq 0 ]; then
    return 0
  fi
  if echo $1 | grep -q -w "$2"; then
    return 1
  else
    return 0
  fi
}

#Muda o valor da variável TURNO, alternando entre as jogadas das brancas e 
#das pretas.
troca_turno() {
  if [[ $TURNO = "W" ]]; then
    TURNO="B"
  else
    TURNO="W"
  fi
}

while [ "$MOV" != "X" ];
do
  imprimir_tabuleiro;
  recebe_movimento;
done


