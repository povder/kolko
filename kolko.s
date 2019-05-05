# Copyright 2009 Krzysztof Pado

# The program doesn't use any C libs

.equ    WRITE,   0x04    # system functions
.equ    READ,    0x03    #
.equ    EXIT,    0x01    #

.equ    KERNEL,  0x80

.equ    STDOUT,  0x01
.equ    STDIN,   0x00

.equ    FIRSTPOS,    41    # position of the first field
.equ    DIST,        28    # distance between fields in a row
.equ    NEWLINEDIST, 50    # distance between last field in a row and the first one in the next row


.equ    ROW1,     0
.equ    ROW2,     1
.equ    ROW3,     2
.equ    COL1,     3
.equ    COL2,     4
.equ    COL3,     5
.equ    CROSS159, 6 # diagonal \
.equ    CROSS357, 7 # diagonal /

.equ    FIELD1, 0
.equ    FIELD2, 1
.equ    FIELD3, 2
.equ    FIELD4, 3
.equ    FIELD5, 4
.equ    FIELD6, 5
.equ    FIELD7, 6
.equ    FIELD8, 7
.equ    FIELD9, 8

.equ    OID,    1    # O identifier
.equ    XID,    4    # X identifier
.equ    OSUM,   3    # line sum when O is a winner
.equ    XSUM,   12   # line sum when X is a winner

.equ    BLUE,   '4'
.equ    GREEN,  '2'
.equ    RED,    '1'

# ------------------------------------------------------------------------------------------------------------- #

.data

mode:
.byte 0     # 0 - human vs human
            # 1 - human vs computer, human starts
            # 2 - human vs computer, computer starts

modestr1:
.ascii "Choose game mode:\n0) 2 players\n1) single player\n"
modestr1len:
.long (. - modestr1)

modestr2:
.ascii "Who starts?\n0) human\n1) computer\n"
modestr2len:
.long (. - modestr2)

cursorup10str:
.ascii "\033[10A"
cursorup10len:
.long (. - cursorup10str)

cursorup1str:
.ascii "\033[01A"
cursorup1len:
.long (. - cursorup1str)

selected:    # selected field ID
.ascii "  "

curr:        # current player ID
.byte 'O'

result:      # 0 - draw, 1 - some player won
.byte 0

turnstr:
.ascii "\nRound 0, player O\n"
turnstrlen:
.long (. - turnstr)

gameendstr:
.ascii "\nGame over.                                    \n"
gameendstrlen:
.long (. - gameendstr)

resultstr:
.ascii "O  won                                          \n"
resultstrlen:
.long (. - resultstr)

drawstr:
.ascii "Draw.                                           \n"
drawstrlen:
.long (. - drawstr)

gridstr:
.ascii "\033[1;37m+-----------------+\n"
.ascii "|  \033[0m\033[1;30m1\033[0m\033[1;37m  |  \033[0m\033[1;30m2\033[0m\033[1;37m  |  \033[0m\033[1;30m3\033[0m\033[1;37m  |\n"
.ascii "|-----+-----+-----|\n"
.ascii "|  \033[0m\033[1;30m4\033[0m\033[1;37m  |  \033[0m\033[1;30m5\033[0m\033[1;37m  |  \033[0m\033[1;30m6\033[0m\033[1;37m  |\n"
.ascii "|-----+-----+-----|\n"
.ascii "|  \033[0m\033[1;30m7\033[0m\033[1;37m  |  \033[0m\033[1;30m8\033[0m\033[1;37m  |  \033[0m\033[1;30m9\033[0m\033[1;37m  |\n"
.ascii "+-----+-----+-----+\n\033[0m"
gridstrlen:
.long (. - gridstr)

requeststr:
.ascii "Select a field:                                    \033[35D"
requeststrlen:
.long (. - requeststr)

nookstr:
.ascii "Selected field is not empty. "
nookstrlen:
.long (. - nookstr)

array:                              # state of the grid
.byte 0, 0, 0, 0, 0, 0, 0, 0, 0

sumarray:                           # sums of lines
.byte 0, 0, 0, 0, 0, 0, 0, 0


# ------------------------------------------------------------------------------------------------------------- #

.text
.globl _start
_start:

CALL    choosemode      # game mode selection
MOVB    %al, mode

MOVL    $9, %ecx        # max 9 rounds

theloop:
PUSHL   %ecx            # %ecx will be modified by called functions, pushing it to the stack

CMPB    $0, mode        # if human vs human
JE      player          # then jump to player label, human's turn

CMPB    $'O', curr      # if it's O's turn
JE      curro
CMPB    $1, mode        # if it's X's turn and human started, jump to player
JNE     player          # player's turn
JMP     doai            # if computer started, it's computer's turn

curro:
CMPB    $2, mode        # if it's not the computer's turn
JNE     player

doai:                   # computer's turn
MOVB    mode, %al       # game mode goes to %al
CALL    ai              # call ai, computer selects a field
CALL    processchoice
JMP     ok


player:                 # human's turn

CALL    dispturn
CALL    dispgrid

request:
CALL    disprequest
CALL    processchoice
CMPB    $0, %al         # if %al is 0, selected field was empty
JE      playerok        # so jump
CALL    dispnook        # if the field was not empty, display a message
JMP     request         # and go back

playerok:

MOVL    $WRITE, %eax            # move cursor 10 lines up
MOVL    $STDOUT, %ebx           #
MOVL    $cursorup10str, %ecx    #
MOVL    cursorup10len, %edx     #
INT     $KERNEL                 #

ok:

CALL    getresult   # check if somebody has won
CMPB    $0, %al     # if %al != 0, somebody won
JNE     someonewon

theloop_end:
POPL    %ecx        # restore %ecx to the value from the beginning of the loop
LOOP    theloop

MOVB    $1, result  # put 'draw' information into the result
JMP     end

someonewon:
MOVB    %ah, %al    # put ID of "winning" line to %al
CALL    markline    # mark the line red
MOVB    $0, result

end:

CALL    dispgameend
CALL    dispgrid
MOVB    result, %al
CALL    dispresult


MOVL    $EXIT, %eax
INT     $KERNEL


# ------------------------------------------------------------------------------------------------------------- #




# setcharat function ---------------------------------
#
# puts a character to the selected field in the grid
# and sets color
#
# parameters:
# %al <- field ID
# %ah <- character to put (-1 won't modify existing value)
# %bl <- color ('1'-'6' - ascii)
#
# returns:
# void

.type setcharat, @function
setcharat:
MOVL    $gridstr, %edi
ADDL    $FIRSTPOS, %edi

CMPB    $FIELD1, %al
JNG     setcharat_end
ADDL    $DIST, %edi

CMPB    $FIELD2, %al
JNG     setcharat_end
ADDL    $DIST, %edi

CMPB    $FIELD3, %al 
JNG     setcharat_end
ADDL    $NEWLINEDIST, %edi

CMPB    $FIELD4, %al 
JNG     setcharat_end
ADDL    $DIST, %edi

CMPB    $FIELD5, %al 
JNG     setcharat_end
ADDL    $DIST, %edi

CMPB    $FIELD6, %al 
JNG     setcharat_end
ADDL    $NEWLINEDIST, %edi

CMPB    $FIELD7, %al 
JNG     setcharat_end
ADDL    $DIST, %edi

CMPB    $FIELD8, %al 
JNG     setcharat_end
ADDL    $DIST, %edi

setcharat_end:
CMPB    $-1, %ah        # if the character should be unchanged
JE      setcharat_color # then change the color only
MOVB    %ah, (%edi)     # otherwise put the character into the field
setcharat_color:
SUBL    $2, %edi
MOVB    %bl, (%edi)

RET

# setcharat function end -------------------------



# setxat function --------------------------------
#
# puts O to given field
#
# parameters:
# %al <- field ID
#
# returns:
# void

.type setxat, @function
setxat:

MOVB    $'X', %ah
MOVB    $BLUE, %bl
CALL    setcharat

XORL    %ebx, %ebx
MOVB    %al, %bl

MOVB    $XID, array(,%ebx,1)    # array[%ebx] = XID
MOVB    $XID, %ah        
CALL    addtosums

MOVB    $'O', curr              # next turn is Os

RET

# setxat function end -----------------------------



# setoat function ---------------------------------
#
# puts X to given field
#
# parameters:
# %al <- field ID
#
# returns:
# void

.type setoat, @function
setoat:

MOVB    $'O', %ah
MOVB    $GREEN, %bl
CALL    setcharat

XORL    %ebx, %ebx
MOVB    %al, %bl

MOVB    $OID, array(,%ebx,1)
MOVB    $OID, %ah
CALL    addtosums

MOVB    $'X', curr

RET

# setoat function end -------------------------------



# getresult function --------------------------------
#
# checks if somebody has won
#
# parameters:
# none
#
# returns:
# %al <- 0 - draw
#        1 - Os win
#        2 - Xs win
# %ah <- ID of the "winning" line

.type getresult, @function
getresult:

MOVL    $sumarray, %edi
MOVL    $8, %ecx
MOVB    $OSUM, %al
REPNE   SCASB
JNE     getresult_checkx    # if OSUM is not found searching for XSUM

                            # OSUM was found, one of the lines has three Os
SUBL    $7, %ecx
NEG     %ecx
MOVB    %cl, %ah

MOVB    $1, %al             # if Os won return 1 in %al
RET

getresult_checkx:
MOVL    $sumarray, %edi
MOVL    $8, %ecx
MOVB    $XSUM, %al
REPNE   SCASB
JNE     getresult_draw      # if XSUM was not found then there's draw

SUBL    $7, %ecx
NEG     %ecx
MOVB    %cl, %ah

MOVB    $2, %al
RET

getresult_draw:
MOVB    $0, %al
RET

# getresult function end -----------------------------




# markline function -----------------------------------
#
# marks given line red
#
# parameters:
# %al <- line ID
#
# returns:
# void

.type markline, @function
markline:
MOVB    %al, %bh    # line ID to %bh
MOVB    $-1, %ah    # don't change the character in the field
MOVB    $RED, %bl   # paint it red

CMPB    $ROW1, %bh
JNE     markline2
MOVB    $FIELD1, %al
CALL    setcharat
MOVB    $FIELD2, %al
CALL    setcharat
MOVB    $FIELD3, %al
CALL    setcharat
RET

markline2:
CMPB    $ROW2, %bh
JNE     markline3
MOVB    $FIELD4, %al
CALL    setcharat
MOVB    $FIELD5, %al
CALL    setcharat
MOVB    $FIELD6, %al
CALL    setcharat
RET

markline3:
CMPB    $ROW3, %bh
JNE     markline4
MOVB    $FIELD7, %al
CALL    setcharat
MOVB    $FIELD8, %al
CALL    setcharat
MOVB    $FIELD9, %al
CALL    setcharat
RET

markline4:
CMPB    $COL1, %bh
JNE     markline5
MOVB    $FIELD1, %al
CALL    setcharat
MOVB    $FIELD4, %al
CALL    setcharat
MOVB    $FIELD7, %al
CALL    setcharat
RET

markline5:
CMPB    $COL2, %bh
JNE     markline6
MOVB    $FIELD2, %al
CALL    setcharat
MOVB    $FIELD5, %al
CALL    setcharat
MOVB    $FIELD8, %al
CALL    setcharat
RET

markline6:
CMPB    $COL3, %bh
JNE     markline7
MOVB    $FIELD3, %al
CALL    setcharat
MOVB    $FIELD6, %al
CALL    setcharat
MOVB    $FIELD9, %al
CALL    setcharat
RET

markline7:
CMPB    $CROSS159, %bh
JNE     markline8
MOVB    $FIELD1, %al
CALL    setcharat
MOVB    $FIELD5, %al
CALL    setcharat
MOVB    $FIELD9, %al
CALL    setcharat
RET

markline8:
MOVB    $FIELD3, %al
CALL    setcharat
MOVB    $FIELD5, %al
CALL    setcharat
MOVB    $FIELD7, %al
CALL    setcharat
RET

# markline function end ------------------------



# dispgrid function ----------------------------
#
# displays the grid
#
# parameters:
# none
#
# returns:
# void

.type dispgrid, @function
dispgrid:

MOVL    $WRITE, %eax
MOVL    $STDOUT, %ebx
MOVL    $gridstr, %ecx
MOVL    gridstrlen, %edx
INT     $KERNEL

RET

# dispgrid function end -----------------------



# dispturn function -----------------------------
#
# displays turn number and whose turns it is
#
# parameters:
# none
#
# returns:
# void

.type dispturn, @function
dispturn:

MOVL    $turnstr, %edi
ADDL    $17, %edi        # set %edi to the character - player ID
MOVB    curr, %al        # put player ID in current round to %al
MOVB    %al, (%edi)      # and to the string

MOVL    $WRITE, %eax     # display the message
MOVL    $STDOUT, %ebx    #
MOVL    $turnstr, %ecx   #
MOVL    turnstrlen, %edx #
INT     $KERNEL          #

ADDL    $7, %ecx         # move %ecx to the round number
MOVB    (%ecx), %al
INCB    %al
MOVB    %al, (%ecx)      # put current round number into the string

RET

# dispturn function end --------------------------



# disprequest function ---------------------------
#
# displays request to select a field
# converts selected field to the number and returns it
#
# parameters:
# none
#
# returns:
# %al <- ID of the selected field

.type disprequest, @function
disprequest:

MOVL    $WRITE, %eax
MOVL    $STDOUT, %ebx
MOVL    $requeststr, %ecx
MOVL    requeststrlen, %edx
INT     $KERNEL

MOVL    $READ, %eax
MOVL    $STDIN, %ebx
MOVL    $selected, %ecx
MOVL    $2, %edx
INT     $KERNEL

MOVB    selected, %al
SUBB    $'0', %al        # convert to int
DECB    %al              # make 0 based

RET

# disprequest function end --------------------------



# dispnook function ---------------------------------
#
# displays a message saying that the selected field is
# non empty
#
# parameters:
# none
#
# returns:
# void

.type dispnook, @function
dispnook:

MOVL    $WRITE, %eax
MOVL    $STDOUT, %ebx
MOVL    $cursorup1str, %ecx
MOVL    cursorup1len, %edx
INT     $KERNEL

MOVL    $WRITE, %eax
MOVL    $STDOUT, %ebx
MOVL    $nookstr, %ecx
MOVL    nookstrlen, %edx
INT     $KERNEL

RET

# dispnook function end --------------------------


# dispgameend function ---------------------------
#
# displays a message about game end
#
# parameters:
# none
# 
# returns:
# void

.type dispgameend, @function
dispgameend:

MOVL    $WRITE, %eax
MOVL    $STDOUT, %ebx
MOVL    $gameendstr, %ecx
MOVL    gameendstrlen, %edx
INT     $KERNEL

RET

# dispgameend function end -----------------------



# dispresult function ----------------------------
#
# displays the result
#
# parameters:
# %al <- result (1 - draw, 0 - somebody won)
# 
# returns:
# void

.type dispresult, @function
dispresult:

CMPB    $1, %al            # if draw
JE      dresult_draw

MOVL    $resultstr, %edi
MOVB    curr, %al
CMPB    $'X', %al        
JE      dresult_changetoo
dresult_changetox:
MOVB    $'X', %al
JMP     dresult_put
dresult_changetoo:
MOVB    $'O', %al

dresult_put:
MOVB    %al, (%edi)
MOVL    $resultstr, %ecx
MOVL    resultstrlen, %edx
JMP     dresult_do

dresult_draw:
MOVL    $drawstr, %ecx
MOVL    drawstrlen, %edx

dresult_do:
MOVL    $WRITE, %eax
MOVL    $STDOUT, %ebx

INT     $KERNEL

RET

# dispresult function koniec ------------------------



# processchoice function ----------------------------
#
# checks if a selected field is empty and if so,
# puts X or O to the grid
#
# parameters:
# %al <- field ID
#
# returns:
# %al <- 0 - field empty, 1 - field non empty

.type processchoice, @function
processchoice:
CBW                         # %al to %eax conversion
CWDE                        #
CMPB    $0, array(,%eax,1)  # if array[%eax] == 0 field is empty
JNE     processchoice_bad   # if not, jump

CMPB    $'X', curr          # if it's not Xs' turn
JNE     processchoice_o     # then jump
CALL    setxat              # put X to the field
MOVB    $0, %al             # signal OK
RET

processchoice_o:
CALL    setoat
MOVB    $0, %al
RET

processchoice_bad:
MOVB    $1, %al             # signal field non empty
RET

# processchoice function end ----------------------



# choosemode function -----------------------------
#
# asks for choosing game mode
#
# parameters:
# none
#
# returns:
# %al <- game mode: 0 - 2 players
#                   1 - single player: human starts
#                   2 - single player: computer starts

.type choosemode, @function
choosemode:

MOVL    $WRITE, %eax
MOVL    $STDOUT, %ebx
MOVL    $modestr1, %ecx
MOVL    modestr1len, %edx
INT     $KERNEL

MOVL    $READ, %eax
MOVL    $STDIN, %ebx
MOVL    $selected, %ecx
MOVL    $2, %edx
INT     $KERNEL

MOVB    selected, %al
CMPB    $'0', %al       # if single player ask further
JNE     choosemode_2

MOVB    $0, %al         # if two players
RET

choosemode_2:
MOVL    $WRITE, %eax        # ask who starts
MOVL    $STDOUT, %ebx       #
MOVL    $modestr2, %ecx     #
MOVL    modestr2len, %edx   #
INT     $KERNEL             #

MOVL    $READ, %eax
MOVL    $STDIN, %ebx
MOVL    $selected, %ecx
MOVL    $2, %edx
INT     $KERNEL

MOVB    selected, %al
SUBB    $47, %al            # convert to int

RET

# choosemode function end -------------------------



# ai ;) -------------------------------------------
#
#
# parameters:
# %al <- game mode (1 - computer is X, 2 - computer is O)
#
# returns:
# %al <- field chosen by the computer

.type ai, @function
ai:

CMPB    $1, %al
JE    ai_comp_x

ai_comp_o:
MOVB    $XID, %bl
MOVB    $OID, %bh
JMP    ai_do

ai_comp_x:
MOVB    $OID, %bl
MOVB    $XID, %bh

ai_do:
MOVB    %bh, %al
MOVB    $2, %cl
MULB    %cl

MOVL    $7, %ecx
ai_loop1:
CMPB    %al, sumarray(,%ecx,1)    
JE      ai_end
DECL    %ecx
CMPL    $-1, %ecx
JNE     ai_loop1

MOVB    %bl, %al
MOVB    $2, %cl
MULB    %cl

MOVL    $7, %ecx
ai_loop2:
CMPB    %al, sumarray(,%ecx,1)
JE      ai_end
DECL    %ecx
CMPL    $-1, %ecx
JNE     ai_loop2

MOVB    %bh, %al


MOVL    $7, %ecx
ai_loop3:            
CMPB    %al, sumarray(,%ecx,1)
JE      ai_end
DECL    %ecx
CMPL    $-1, %ecx
JNE     ai_loop3

MOVB    $0, %al


MOVL    $7, %ecx
ai_loop4:
CMPB    %al, sumarray(,%ecx,1)
JE      ai_end
DECL    %ecx
CMPL    $-1, %ecx
JNE     ai_loop4

MOVB    %bl, %al


MOVL    $7, %ecx
ai_loop5:
CMPB    %al, sumarray(,%ecx,1)
JE      ai_end
DECL    %ecx
CMPL    $-1, %ecx
JNE     ai_loop5

ai_end:

CMPL    $ROW1, %ecx
JNE     ai_2
MOVL    $FIELD1, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD2, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD3, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2

ai_2:
CMPL    $ROW2, %ecx
JNE     ai_3
MOVL    $FIELD4, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD5, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD6, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2

ai_3:
CMPL    $ROW3, %ecx
JNE    ai_4
MOVL    $FIELD7, %eax
CMPB    $0, array(,%eax,1)
JE    ai_end2
MOVL    $FIELD8, %eax
CMPB    $0, array(,%eax,1)
JE    ai_end2
MOVL    $FIELD9, %eax
CMPB    $0, array(,%eax,1)
JE    ai_end2

ai_4:
CMPL    $COL1, %ecx
JNE     ai_5
MOVL    $FIELD1, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD4, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD7, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2

ai_5:
CMPL    $COL2, %ecx
JNE     ai_6
MOVL    $FIELD2, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD5, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD8, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2

ai_6:
CMPL    $COL3, %ecx
JNE     ai_7
MOVL    $FIELD3, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD6, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD9, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2

ai_7:
CMPL    $CROSS159, %ecx
JNE     ai_8
MOVL    $FIELD1, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD5, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD9, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2

ai_8:
MOVL    $FIELD3, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD5, %eax
CMPB    $0, array(,%eax,1)
JE      ai_end2
MOVL    $FIELD7, %eax

ai_end2:

RET

# ai function end --------------------------------



# addtosums function -----------------------------
#
# after adding a character to the grid
# adds values to sum array
#
# parameters:
# %al <- field ID
# %ah <- character ID
#
# returns:
# void

.type addtosums, @function
addtosums:

CMPB    $FIELD1, %al
JNE     addtosums2
MOVL    $ROW1, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $COL1, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $CROSS159, %ebx
ADDB    %ah, sumarray(,%ebx,1)
RET

addtosums2:
CMPB    $FIELD2, %al
JNE     addtosums3
MOVL    $ROW1, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $COL2, %ebx
ADDB    %ah, sumarray(,%ebx,1)
RET

addtosums3:
CMPB    $FIELD3, %al
JNE     addtosums4
MOVL    $ROW1, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $COL3, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $CROSS357, %ebx
ADDB    %ah, sumarray(,%ebx,1)
RET

addtosums4:
CMPB    $FIELD4, %al
JNE     addtosums5
MOVL    $ROW2, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $COL1, %ebx
ADDB    %ah, sumarray(,%ebx,1)
RET

addtosums5:
CMPB    $FIELD5, %al
JNE     addtosums6
MOVL    $ROW2, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $COL2, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $CROSS159, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $CROSS357, %ebx
ADDB    %ah, sumarray(,%ebx,1)
RET

addtosums6:
CMPB    $FIELD6, %al
JNE     addtosums7
MOVL    $ROW2, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $COL3, %ebx
ADDB    %ah, sumarray(,%ebx,1)
RET

addtosums7:
CMPB    $FIELD7, %al
JNE     addtosums8
MOVL    $ROW3, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $COL1, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $CROSS357, %ebx
ADDB    %ah, sumarray(,%ebx,1)
RET

addtosums8:
CMPB    $FIELD8, %al
JNE     addtosums9
MOVL    $ROW3, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $COL2, %ebx
ADDB    %ah, sumarray(,%ebx,1)
RET

addtosums9:
MOVL    $ROW3, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $COL3, %ebx
ADDB    %ah, sumarray(,%ebx,1)
MOVL    $CROSS159, %ebx
ADDB    %ah, sumarray(,%ebx,1)

RET

# addtosums function end ---------------------------


# EOF -------------------------------------------------------------------------------------- #  
