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
PECAS_BRANCAS=($W_KING $W_QUEEN $W_ROOK $W_KNIGHT $W_BISHOP $W_PAWN)
PECAS_PRETAS=($B_KING $B_QUEEN $B_ROOK $B_KNIGHT $B_BISHOP $B_PAWN)
TURNO=W #Vou utilizar essa variável para definir de quem é a vez de jogar.
MOV="" #Captura o movimento a ser feito.
declare -A TAB #Tabuleiro

#Reorganiza a variável global TAB com as posições iniciais do tabuleiro.
#Não deu certo colocar a referência a um array de peças dentro da função
#como utilizando: $1[B_ROOK], ficava aparecendo o ícone e o [B_ROOK] na
#impressão, por isso, acabei usando o acesso direto às variáveis globais.
function tabuleiro_inicial() {
  TAB[1]=$B_ROOK
  TAB[2]=$B_KNIGHT
  TAB[3]=$B_BISHOP
  TAB[4]=$B_QUEEN
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
  TAB[61]=$W_KING
  TAB[62]=$W_BISHOP
  TAB[63]=$W_KNIGHT
  TAB[64]=$W_ROOK
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
  read -p "Digite o movimento: " MOV
  if [[ $MOV = "X" ]]; then
    exit
  fi;
  #echo $MOV
  #Os movimentos proibidos em questão de criar uma situação de xeque serão
  #verificados posteriormente.
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
  #Para refatorar as casas, para que elas apenas testem se o movimento é
  #possível, os métodos podem retornar 0 se impossível, e entre 1 e 64 para
  #a casa origem. Para depois limpar a casa origem, e mover a peça para a
  #casa destino.
  if [[ ${#MOV} == 2 ]]; then #Peão
    teste_mov_peao $MOV
    cs_orig=$?
  elif [[ ${MOV:0:1} == "R" ]]; then #Torre
    teste_mov_torre $MOV
    cs_orig=$?
  elif [[ ${MOV:0:1} == "N" ]]; then #Cavalo
    teste_mov_cavalo $MOV
    cs_orig=$?
  elif [[ ${MOV:0:1} == "B" ]]; then #Bispo
    teste_mov_bispo $MOV
    cs_orig=$?
  elif [[ ${MOV:0:1} == "Q" ]]; then #Dama
    teste_mov_dama $MOV
    cs_orig=$?
  elif [[ ${MOV:0:1} == "K" ]]; then #Rei
    teste_mov_rei $MOV
    cs_orig=$?
  fi
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
teste_mov_rei() {
  declare -A cols
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  num_col=${cols[${MOV:1:1}]}
  num_lin=${MOV:2:1}
  posicao=$((64-${MOV:2:1}*8 + $num_col))
  printf "Posicao base: $posicao  \n"
  pos_base=""
  mov_valido=0

  if [[ $TURNO == "W" ]]; then
    peca="$W_KING"
    inimigos=${PECAS_PRETAS[@]}
    amigos=${PECAS_BRANCAS[@]}
  else
    peca="$B_KING"
    amigos=${PECAS_PRETAS[@]}
    inimigos=${PECAS_BRANCAS[@]}
  fi
  printf "Conteudo posicao: ${TAB[$posicao]} \n"
  posicao_disponivel "$amigos" "${TAB[$posicao]}"
  pos_disponivel=$?
  echo "Posicao disponivel -> $pos_disponivel"
  if [[ $pos_disponivel -eq 0 ]]; then
    printf "Movimento inválido - casa destino ocupada \n"
    return
  fi

  #Distâncias relativas: -9 -8 -7 -1 1 7 8 9
  posicoes=(-9 -8 -7 -1 1 7 8 9)
  dist=0 #Distancia está ok ou não
  for ((i=0; i < 8; i++)) do
    casa=$(($posicao + ${posicoes[$i]}))
    if [[ "${TAB[$casa]}" == "$peca" ]]; then
      pos_base=$casa
      dist=1
      break
    fi
  done

  if [[ $dist -eq 0 ]]; then
    printf "Posicao impossivel - distancia incorreta \n"
    return
  fi

  posicao_em_xeque $posicao
  pos_xeque=$?

  if [[ $pos_xeque -eq 0 ]]; then
    TAB[$pos_base]=""
    TAB[$posicao]="$peca"
    troca_turno
  else
    printf "Movimento impossivel - casa em xeque \n"
  fi
}

#Verifica se uma posicao do tabuleiro esta em xeque.
#Posso utilizar todos os testes das outras peças, mas para isso vou precisar
#refatorar o código, para que fique mais modular. Simplesmente, vou testar a
#movimentação de cada peça para a casa pretendida.
#Parametros: $1 -> casa que vai ser verificada.
posicao_em_xeque() {
  posicao="$1"



}

#Verifica se a posição em questão está disponível para ser usada, ou seja, a
#casa não está ocupada por um dos reis ou por uma peça aliada.
#Retorna 1 se disponível e 0 se não disponível.
#Parâmetros: $2 -> lista de peças aliadas.
#$3 -> posição a ser verificada
posicao_disponivel() {
  existe_na_posicao "$1" "$2"
  casa_tomada=$?
  if [[ $casa_tomada -eq 1  ||
      "${TAB[$posicao]}" == "$B_KING" ||
      "${TAB[$posicao]}" == "$W_KING" ]]; then
    return 0
  else
    return 1
  fi
}


#Teste de movimentação para a dama: ela se move quantas casas quiser, na
#direção que quiser, só não pula casas.
teste_mov_dama() {
  declare -A cols
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  num_col=${cols[${MOV:1:1}]}
  num_lin=${MOV:2:1}
  posicao=$((64-${MOV:2:1}*8 + $num_col))
  printf "Posicao base: $posicao  \n"
  pos_base=""
  mov_valido=0

  if [[ $TURNO == "W" ]]; then
    peca="$W_QUEEN"
    inimigos=${PECAS_PRETAS[@]}
    amigos=${PECAS_BRANCAS[@]}
  else
    peca="$B_QUEEN"
    amigos=${PECAS_PRETAS[@]}
    inimigos=${PECAS_BRANCAS[@]}
  fi
  printf "Conteudo posicao: ${TAB[$posicao]} \n"
  posicao_disponivel "$amigos" "${TAB[$posicao]}"
  pos_disponivel=$?
  echo "Posicao disponivel -> $pos_disponivel"
  if [[ $pos_disponivel -eq 0 ]]; then
    printf "Movimento inválido - casa destino ocupada \n"
    return
  fi

  #Movimento horizontal ->
  itr_tst=$(($num_col+1))
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
  printf "Movimento: $mov_valido \n"

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
    done
    itr_tst=$(($itr_tst-1))
  fi

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
   while [ $pos_tst > 0 ]; do
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

  if [[ $mov_valido -eq 0 ]]; then
    diag_col=(-1 -1 1  1)
    diag_lin=(-1  1 1 -1)
    iteradores=(7 -7 -9 9)
    for ((a=0; a < 4; a++)) do
      col_itr=${diag_col[$a]}
      lin_itr=${diag_lin[$a]}
      col_tst=$(($num_col + ${diag_col[$a]}))
      lin_tst=$(($num_lin + ${diag_lin[$a]}))
      itr=${iteradores[$a]}
      pos_tst=$(($posicao + $itr))
      while [[ $col_tst -gt 0  &&  $col_tst -lt 9  &&  $lin_tst -gt 0  &&
               $lin_tst -lt 9 ]]; do
        if [[ "${TAB[$pos_tst]}" == "$peca" ]]; then
          pos_base=$pos_tst
          mov_valido=1
          break
        elif [[ "${TAB[$pos_tst]}" != "" ]]; then
          mov_valido=0
          printf "Casa ocupada \n"
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

  if [[ $mov_valido -eq 1 ]]; then
    TAB[$pos_base]=""
    TAB[$posicao]="$peca"
    troca_turno
  else
    printf "Movimento impossivel \n"
  fi
}

#Método que analisa a movimentação do cavalo (Knight). Para isso deve ser
#checado se existe um cavalo na posição em uma combinação de 2 colunas e 1
#linha ou vice-versa, positivo ou negativo. Não é preciso checar casas
#intermediárias, pq o cavalo é a unica peça que  pode pular outras peças.
teste_mov_cavalo() {
  declare -A cols
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  num_col=${cols[${MOV:1:1}]}
  num_lin=${MOV:2:1}
  posicao=$((64-${MOV:2:1}*8 + $num_col))
  pos_base=""
  mov_valido=0
  if [[ $TURNO == "W" ]]; then
    peca="$W_KNIGHT"
    inimigos=${PECAS_PRETAS[@]}
    amigos=${PECAS_BRANCAS[@]}
  else
    peca="$B_KNIGHT"
    amigos=${PECAS_PRETAS[@]}
    inimigos=${PECAS_BRANCAS[@]}
  fi
  existe_na_posicao "$amigos" "${TAB[$posicao]}"
  casa_tomada=$?
  if [[ $casa_tomada -eq 1  ||
      "${TAB[$posicao]}" == "$B_KING" ||
      "${TAB[$posicao]}" == "$W_KING" ]]; then
    printf "Movimento inválido - casa destino ocupada \n"
    return
  fi
  colunas_teste=(-2 -2  -1 1 2 2 -1 1)
  linhas_teste=(1 -1 -2 -2 -1 1 2 2)
  for ((i = 0; i < 8; i++)) do
    cl=$(( ${colunas_teste[$i]} + $num_col))
    ln=$(( ${linhas_teste[$i]} + $num_lin))
    ct_col=${colunas_teste[$i]}
    ct_lin=${linhas_teste[$i]}
    if [[ $cl -gt 0 && $cl -lt  9 && $ln -gt 0 && $ln -lt 9 ]]; then
     if [[ "${TAB[$(($posicao + $ct_col + $ct_lin * 8))]}" == "$peca" ]]; then
       TAB[$(($posicao + $ct_col + $ct_lin * 8))]=""
       TAB[$posicao]="$peca"
       troca_turno;
       return
     fi
    fi
  done
  printf "Movimento inválido - posicao nao e possivel \n"

}

#Método que analisa a movimentação da torre: a torre se move na vertical ou
#na horizontal, quantas casas quiser, não pode pular peças, e pode capturar
#qualquer peça. Nessa movimentação temos que verificar se a casa destino não
#é a ocupada pelo rei inimigo.
teste_mov_torre() {
  declare -A cols
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  num_col=${cols[${MOV:1:1}]}
  num_lin=${MOV:2:1}
  posicao=$((64-${MOV:2:1}*8 + $num_col))
  pos_base=""

  if [[ $TURNO == "W" ]]; then
    peca="$W_ROOK"
    inimigos=${PECAS_PRETAS[@]}
    amigos=${PECAS_BRANCAS[@]}
  else
    peca="$B_ROOK"
    amigos=${PECAS_PRETAS[@]}
    inimigos=${PECAS_BRANCAS[@]}
  fi
  existe_na_posicao "$amigos" "${TAB[$posicao]}"
  casa_tomada=$?
  mov_valido=0
  if [ $casa_tomada -eq 1 ]; then
    echo "Movimento inválido - casa destino ocupada \n"
    return
  fi
  #Testamos se existe uma torre disponível, primeiro na horizontal,
  #depois na vertical.
  teste_col=$(($num_col-1))
  while [ $teste_col -gt 0 ];
  do
    pol=$((64-$num_lin*8 + $teste_col))
    if [[ "${TAB[$pol]}" == "" ]]; then
      teste_col=$(($teste_col-1))
    elif [[ "${TAB[$pol]}" == "$peca" ]]; then
      mov_valido=1
      pos_base=$(($pol))
      break
    else
      break
    fi
  done

  echo $num_lin
  if [[ $mov_valido -eq 0 ]]; then
    teste_col=$(($num_col+1))
    while [ $teste_col -lt 9 ];
    do
      pol=$((64-$num_lin*8 + $teste_col))
      if [[ "${TAB[$pol]}" == "" ]]; then
        teste_col=$(($teste_col+1))
      elif [[ "${TAB[$pol]}" == "$peca" ]]; then
        mov_valido=1
        pos_base=$(($pol))
        break
      else #movimento invalido, encontrou uma peça aliada no caminho
        break
      fi
    done
  fi

  if [[ $mov_valido -eq 0 ]]; then
    teste_lin=$(($num_lin+1))
    while [ $teste_lin -lt 9 ];
    do
      pol=$((64-$teste_lin*8 + $num_col))
      if [[ "${TAB[$pol]}" == "" ]]; then
        teste_lin=$(($teste_lin+1))
      elif [[ "${TAB[$pol]}" == "$peca" ]]; then
        mov_valido=1
        pos_base=$(($pol))
        break
      else #movimento invalido, encontrou uma peça aliada no caminho
        break
      fi
    done
  fi

  if [[ $mov_valido -eq 0 ]]; then
    teste_lin=$(($num_lin-1))
    while [ $teste_lin -gt 0 ];
    do
      pol=$((64-$teste_lin*8 + $num_col))
      if [[ "${TAB[$pol]}" == "" ]]; then
        teste_lin=$(($teste_lin-1))
      elif [[ "${TAB[$pol]}" == "$peca" ]]; then
        mov_valido=1
        pos_base=$(($pol))
        break
      else #movimento invalido, encontrou uma peça aliada no caminho
        break
      fi
    done
  fi

  if [ $mov_valido == 1 ]; then
    troca_turno;
    TAB[$(($posicao))]="$peca"
    TAB[$(($pos_base))]=""
  else
    echo "Movimento inválido"
  fi
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
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  num_col=${cols[${MOV:1:1}]}
  num_lin=${MOV:2:1}
  posicao=$((64-${MOV:2:1}*8 + $num_col))
  if [[ $TURNO == "W" ]]; then
    peca="$W_BISHOP"
    inimigos=${PECAS_PRETAS[@]}
  else
    peca="$B_BISHOP"
    inimigos=${PECAS_BRANCAS[@]}
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
    troca_turno;
    TAB[$(($posicao))]="$peca"
  else
    echo "Movimento inválido"
  fi
}

teste_mov_peao() {
  declare -A cols
  cols=([A]=1 [B]=2 [C]=3 [D]=4 [E]=5 [F]=6 [G]=7 [H]=8)
  num_col=${cols[${MOV:0:1}]}
  posicao=$((64-${MOV:1:1}*8 + $num_col))
  if [[ $TURNO == "W" ]]; then
    saida=8
    saida_dupla=16
    peca="$W_PAWN"
    peca_inv="$B_PAWN"
    pos_inic=$((48+$num_col))
    inimigos=${PECAS_PRETAS[@]}
  else
    saida=-8
    saida_dupla=-16
    peca="$B_PAWN"
    peca_inv="$W_PAWN"
    pos_inic=$((8+$num_col))
    inimigos=${PECAS_BRANCAS[@]}
  fi
  existe_na_posicao "$inimigos" "${TAB[$posicao]}"
  casa_tomada=$?
  #Saida de duas casas.
  if [ "${TAB[$(($posicao + $saida_dupla))]}" == $peca ]  &&
     [ "$(($posicao + $saida_dupla))" == "$pos_inic" ]  &&
     [ "${TAB[$posicao]}" == "" ]  &&
       [ "${TAB[$(($posicao + $saida))]}" == "" ]; then
    TAB[$(($posicao + $saida_dupla))]=""
    TAB[$(($posicao))]="$peca"
    troca_turno;
  #Movimento de uma casa.
  elif [ "${TAB[$(($posicao + $saida))]}" == $peca ] &&
       [ "${TAB[$posicao]}" == "" ]; then
    TAB[$(($posicao + $saida))]=""
    TAB[$(($posicao))]="$peca"
    troca_turno;
  #Tomada de peça.
  elif [ $casa_tomada -eq 1 ]; then
    if [ "${TAB[$(($posicao + $saida + 1))]}" == $peca ]; then
      TAB[$(($posicao + $saida + 1))]=""
      TAB[$(($posicao))]="$peca"
      troca_turno;
    elif [ "${TAB[$(($posicao + $saida - 1))]}" == $peca ]; then
      TAB[$(($posicao + $saida - 1))]=""
      TAB[$(($posicao))]="$peca"
      troca_turno;
    else
      printf "Movimento inválido \n"
    fi
  else
    printf "Movimento inválido \n"
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


