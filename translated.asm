;X p19
;**********************************************************
;               SARGON
;
;       Sargon is a computer chess playing program designed
; and coded by Dan and Kathe Spracklen. Copyright 1978. All
; rights reserved. No part of this publication may be
; reproduced without the prior written permission.
;**********************************************************

        .686P
        .XMM
        .model  flat
        
;**********************************************************
; EQUATES
;**********************************************************
PAWN     EQU     1
KNIGHT   EQU     2
BISHOP   EQU     3
ROOK     EQU     4
QUEEN    EQU     5
KING     EQU     6
WHITE    EQU     0
BLACK    EQU     80H
BPAWN    EQU     BLACK+PAWN

;**********************************************************
; TABLES SECTION
;**********************************************************
_TABLE   SEGMENT ALIGN(256)
START    DB      100h DUP (?)
TBASE    EQU $
;X TBASE must be page aligned, it needs an absolute address
;X of 0XX00H. The CP/M ZASM Assembler has an ORG of 110H.
;X The relative address START+0F0H becomes the absolute
;X address 200H.
;**********************************************************
; DIRECT --     Direction Table.  Used to determine the dir-
;               ection of movement of each piece.
;**********************************************************
DIRECT   EQU     0
         DB      +09,+11,-11,-09
         DB      +10,-10,+01,-01
         DB      -21,-12,+08,+19
         DB      +21,+12,-08,-19
         DB      +10,+10,+11,+09
         DB      -10,-10,-11,-09
;X p20
;**********************************************************
; DPOINT   --   Direction Table Pointer. Used to determine
;               where to begin in the direction table for any
;               given piece.
;**********************************************************
;DPOINT =        .-TBASE
DPOINT   EQU     18h

         DB      20,16,8,0,4,0,0

;**********************************************************
; DCOUNT   --   Direction Table Counter. Used to determine
;               the number of directions of movement for any
;               given piece.
;**********************************************************
;DCOUNT =        .-TBASE
DCOUNT   EQU     1fh
         DB      4,4,8,4,4,8,8

;**********************************************************
; PVALUE   --   Point Value. Gives the point value of each
;               piece, or the worth of each piece.
;**********************************************************
;PVALUE =        .-TBASE-1
PVALUE   EQU     25h
         DB      1,3,3,5,9,10

;**********************************************************
; PIECES   --   The initial arrangement of the first rank of
;               pieces on the board. Use to set up the board
;               for the start of the game.
;**********************************************************
;PIECES =        .-TBASE
PIECES   EQU     2ch
         DB      4,2,3,5,6,3,2,4
;X p21
;************************************************************
; BOARD --      Board Array. Used to hold the current position
;               of the board during play. The board itself
;               looks like:
;               FFFFFFFFFFFFFFFFFFFF
;               FFFFFFFFFFFFFFFFFFFF
;               FF0402030506030204FF
;               FF0101010101010101FF
;               FF0000000000000000FF
;               FF0000000000000000FF
;               FF0000000000000060FF
;               FF0000000000000000FF
;               FF8181818181818181FF
;               FF8482838586838284FF
;               FFFFFFFFFFFFFFFFFFFF
;               FFFFFFFFFFFFFFFFFFFF
;               The values of FF form the border of the
;               board, and are used to indicate when a piece
;               moves off the board. The individual bits of
;               the other bytes in the board array are as
;               follows:
;               Bit 7 -- Color of the piece
;                       1 -- Black
;                       0 -- White
;               Bit 6 -- Not used
;               Bit 5 -- Not used
;               Bit 4 --Castle flag for Kings only
;               Bit 3 -- Piece has moved flag
;               Bits 2-0 Piece type
;                       1 -- Pawn
;                       2 -- Knight
;                       3 -- Bishop
;                       4 -- Rook
;                       5 -- Queen
;                       6 -- King
;                       7 -- Not used
;                       0 -- Empty Square
;**********************************************************
;BOARD   =       .-TBASE
BOARD    EQU     34h
BOARDA   DB      120 DUP (?)

;p22
;**********************************************************
; ATKLIST --    Attack List. A two part array, the first
;               half for white and the second half for black.
;               It is used to hold the attackers of any given
;               square in the order of their value.
;
; WACT  --      White Attack Count. This is the first
;               byte of the array and tells how many pieces are
;               in the white portion of the attack list.
;
; BACT  --      Black Attack Count. This is the eighth byte of
;               the array and does the same for black.
;**********************************************************
WACT     EQU     ATKLST
BACT     EQU     ATKLST+7
ATKLST   DD      0,0,0,0,0,0,0

;**********************************************************
; PLIST --      Pinned Piece Array. This is a two part array.
;               PLISTA contains the pinned piece position.
;               PLISTD contains the direction from the pinned
;               piece to the attacker.
;**********************************************************
;PLIST   =       .-TBASE-1
PLIST    EQU     0c7h
PLISTD   EQU     PLIST+10
PLISTA   DD      0,0,0,0,0,0,0,0,0,0

;**********************************************************
; POSK  --      Position of Kings. A two byte area, the first
;               byte of which hold the position of the white
;               king and the second holding the position of
;               the black king.
;
; POSQ  --      Position of Queens. Like POSK,but for queens.
;**********************************************************
POSK     DB      24,95
POSQ     DB      14,94
         DB      -1

;X p23
;**********************************************************
; SCORE --      Score Array. Used during Alpha-Beta pruning to
;               hold the scores at each ply. It includes two
;               "dummy" entries for ply -1 and ply 0.
;**********************************************************
SCORE    DD      0,0,0,0,0,0

;**********************************************************
; PLYIX --      Ply Table. Contains pairs of pointers, a pair
;               for each ply. The first pointer points to the
;               top of the list of possible moves at that ply.
;               The second pointer points to which move in the
;               list is the one currently being considered.
;**********************************************************
PLYIX    DD      0,0,0,0,0,0,0,0,0,0
         DD      0,0,0,0,0,0,0,0,0,0

;**********************************************************
; STACK --      Contains the stack for the program.
;**********************************************************
;        .LOC    START+3EFH      ;X START+2FFH
;STACK:
;X Increased stack by 256 bytes. This avoids
;X program crashes on look ahead level 4 and higher.
;Y For this port use standard C stack (if possible)

;X p24
;**********************************************************
; TABLE INDICES SECTION
; M1-M4 --      Working indices used to index into
;               the board array.
; T1-T3 --      Working indices used to index into Direction
;               Count, Direction Value, and Piece Value tables.
; INDX1 --      General working indices. Used for various
; INDX2         purposes.
;
; NPINS --      Number of Pins. Count and pointer into the
;               pinned piece list.
;
; MLPTRI --     Pointer into the ply table which tells
;               which pair of pointers are in current use.
;
; MLPTRJ --     Pointer into the move list to the move that is
;               currently being processed.
;
; SCRIX --      Score Index. Pointer to the score table for
;               the ply being examined.
;
; BESTM --      Pointer into the move list for the move that
;               is currently considered the best by the
;               Alpha-Beta pruning process.
;
; MLLST --      Pointer to the previous move placed in the move
;               list. Used during generation of the move list.
;
; MLNXT --      Pointer to the next available space in the move
;               list.
;**********************************************************
_TABLE   ENDS
_DATA    SEGMENT
                                        ;ORG     START+0
M1       DD      TBASE
M2       DD      TBASE
M3       DD      TBASE
M4       DD      TBASE
T1       DD      TBASE
T2       DD      TBASE
T3       DD      TBASE
INDX1    DD      TBASE
INDX2    DD      TBASE
NPINS    DD      TBASE
MLPTRI   DD      PLYIX
MLPTRJ   DD      0
SCRIX    DD      0
BESTM    DD      0
MLLST    DD      0
MLNXT    DD      MLIST

;X p25
;**********************************************************
; VARIABLES SECTION
;
; KOLOR --      Indicates computer's color. White is 0, and
;               Black is 80H.
;
; COLOR --      Indicates color of the side with the move.
;
; P1-P3 --      Working area to hold the contents of the board
;               array for a given square.
;
; PMATE --      The move number at which a checkmate is
;               discovered during look ahead.
;
; MOVENO --     Current move number.
;
; PLYMAX --     Maximum depth of search using Alpha-Beta
;               pruning.
;
; NPLY  --      Current ply number during Alpha-Beta
;               pruning.
;
; CKFLG --      A non-zero value indicates the king is in check.
;
; MATEF --      A zero value indicates no legal moves.
;
; VALM  --      The score of the current move being examined.
;
; BRDC  --      A measure of mobility equal to the total number
;               of squares white can move to minus the number
;               black can move to.
;
; PTSL  --      The maximum number of points which could be lost
;               through an exchange by the player not on the
;               move.
;
; PTSW1 --      The maximum number of points which could be won
;               through an exchange by the player not on the
;               move.
;
; PTSW2 --      The second highest number of points which could
;               be won through a different exchange by the player
;               not on the move.
;
; MTRL  --      A measure of the difference in material
;               currently on the board. It is the total value of
;               the white pieces minus the total value of the
;               black pieces.
;
; BC0   --      The value of board control(BRDC) at ply 0.
;X p26
;
;
; MV0   --      The value of material(MTRL) at ply 0.
;
; PTSCK --      A non-zero value indicates that the piece has
;               just moved itself into a losing exchange of
;               material.
;
; BMOVES --     Our very tiny book of openings. Determines
;               the first move for the computer.
;
;**********************************************************
KOLOR    DB      0
COLOR    DB      0
P1       DB      0
P2       DB      0
P3       DB      0
PMATE    DB      0
MOVENO   DB      0
PLYMAX   DB      2
NPLY     DB      0
CKFLG    DB      0
MATEF    DB      0
VALM     DB      0
BRDC     DB      0
PTSL     DB      0
PTSW1    DB      0
PTSW2    DB      0
MTRL     DB      0
BC0      DB      0
MV0      DB      0
PTSCK    DB      0
BMOVES   DB      35,55,10H
         DB      34,54,10H
         DB      85,65,10H
         DB      84,64,10H

;X p27
;**********************************************************
; MOVE LIST SECTION
;
; MLIST --      A 2048 byte storage area for generated moves.
;               This area must be large enough to hold all
;               the moves for a single leg of the move tree.
;
; MLEND --      The address of the last available location
;               in the move list.
;
; MLPTR --      The Move List is a linked list of individual
;               moves each of which is 6 bytes in length. The
;               move list pointer(MLPTR) is the link field
;               within a move.
;
; MLFRP --      The field in the move entry which gives the
;               board position from which the piece is moving.
;
; MLTOP --      The field in the move entry which gives the
;               board position to which the piece is moving.
;
; MLFLG --      A field in the move entry which contains flag
;               information. The meaning of each bit is as
;               follows:
;               Bit 7 -- The color of any captured piece
;                       0 -- White
;                       1 -- Black
;               Bit 6 -- Double move flag (set for castling and
;                       en passant pawn captures)
;               Bit 5 -- Pawn Promotion flag; set when pawn
;                       promotes.
;               Bit 4 -- When set, this flag indicates that
;                       this is the first move for the
;                       piece on the move.
;               Bit 3 -- This flag is set is there is a piece
;                       captured, and that piece has moved at
;                       least once.
;               Bits 2-0 Describe the captured piece. A
;                       zero value indicates no capture.
;
; MLVAL --      The field in the move entry which contains the
;               score assigned to the move.
;
;**********************************************************


;*** TEMP TODO BEGIN
MVEMSG   DD      0
MVEMSG_2 DD      0
BRDPOS   DB      1 DUP (?)              ; Index into the board array
ANBDPS   DB      1 DUP (?)              ; Additional index required for ANALYS
LINECT   DB      0                      ; Current line number
;**** TEMP TODO END

;X p28
                                        ;ORG     START+3F0H ;X START+300H
MLIST    DB      2048 DUP (?)
MLEND    DD      0
PTRSIZ  EQU     4
MOVSIZ  EQU     8
MLPTR    EQU     0
MLFRP    EQU     PTRSIZ
MLTOP    EQU     PTRSIZ+1
MLFLG    EQU     PTRSIZ+2
MLVAL    EQU     PTRSIZ+3
         DB      100 DUP (?)
        
shadow_eax  dd   0
shadow_ebx  dd   0
shadow_ecx  dd   0
shadow_edx  dd   0
_DATA    ENDS
        
;**********************************************************
; PROGRAM CODE SECTION
;**********************************************************
_TEXT   SEGMENT        
;
; Miscellaneous stubs
;
FCDMAT:  RET
TBCPMV:  RET
INSPCE:  RET
BLNKER:  RET
CCIR     MACRO                          ;todo
         ENDM
PRTBLK   MACRO   name,len               ;todo
         ENDM
CARRET   MACRO                          ;todo
         ENDM

;
; Z80 Opcode emulation
;         
         
Z80_EXAF MACRO
         lahf
         xchg    eax,shadow_eax
         sahf
         ENDM

Z80_EXX  MACRO
         xchg    ebx,shadow_ebx
         xchg    ecx,shadow_ecx
         xchg    edx,shadow_edx
         ENDM

Z80_RLD  MACRO                          ;a=kx (hl)=yz -> a=ky (hl)=zx
         mov     ah,byte ptr [ebx]      ;ax=yzkx
         ror     al,4                   ;ax=yzxk
         rol     ax,4                   ;ax=zxky
         mov     byte ptr [ebx],ah      ;al=ky [ebx]=zx
         or      al,al                  ;set z and s flags
         ENDM

Z80_RRD  MACRO                          ;a=kx (hl)=yz -> a=kz (hl)=xy
         mov     ah,byte ptr [ebx]      ;ax=yzkx
         ror     ax,4                   ;ax=xyzk
         ror     al,4                   ;ax=xykz
         mov     byte ptr [ebx],ah      ;al=kz [ebx]=xy
         or      al,al                  ;set z and s flags
         ENDM

Z80_LDAR MACRO                          ;to get random number
         pushf                          ;maybe there's entropy in stack junk
         push    ebx
         mov     ebx,ebp
         mov     ax,0
         xor     al,byte ptr [ebx]
         dec     ebx
         jz      $+6
         dec     ah
         jnz     $-7
         pop     ebx
         popf
         ENDM

;Wrap all code in a PROC to get source debugging
SARGON   PROC

         ;Experiments
         ;mov edx,4563h
         ;CALL MLTPLY    ;-> 45h * 63h = 1aafh in al,dh
         ;mov al,1ah
         ;mov edx,0af63h
         ;CALL DIVIDE    ;-> 1aafh / 63h = 45h in dh, 0 remainder in al
    
         ;Implement a kind of system call API, at least for now
         cmp al,0
         jz  INITBD
         cmp al,1
         jz  CPTRMV
         ret
        
;**********************************************************
; BOARD SETUP ROUTINE
;**********************************************************
; FUNCTION:     To initialize the board array, setting the
;               pieces in their initial positions for the
;               start of the game.
;
; CALLED BY:    DRIVER
;
; CALLS:        None
;
; ARGUMENTS:    None
;**********************************************************
INITBD:  MOV     ch,120                 ; Pre-fill board with -1's
         MOV     ebx,offset BOARDA
back01:  MOV     byte ptr [ebx],-1
         LEA     ebx,[ebx+1]
         LAHF
         DEC ch
         JNZ     back01
         SAHF
         MOV     ch,8
         MOV     esi,offset BOARDA
IB2:     MOV     al,byte ptr [esi-8]    ; Fill non-border squares
         MOV     byte ptr [esi+21],al   ; White pieces
         LAHF                           ; Change to black
         OR      al,80h
         SAHF
         MOV     byte ptr [esi+91],al   ; Black pieces
         MOV     byte ptr [esi+31],PAWN ; White Pawns
         MOV     byte ptr [esi+81],BPAWN ; Black Pawns
         MOV     byte ptr [esi+41],0    ; Empty squares
         MOV     byte ptr [esi+51],0
         MOV     byte ptr [esi+61],0
         MOV     byte ptr [esi+71],0
         LEA     esi,[esi+1]
         LAHF
         DEC ch
         JNZ     IB2
         SAHF
         MOV     esi,offset POSK        ; Init King/Queen position list
         MOV     byte ptr [esi+0],25
         MOV     byte ptr [esi+1],95
         MOV     byte ptr [esi+2],24
         MOV     byte ptr [esi+3],94
         RET

;X p29
;**********************************************************
; PATH ROUTINE
;**********************************************************
; FUNCTION:     To generate a single possible move for a given
;               piece along its current path of motion including:
;               Fetching the contents of the board at the new
;               position, and setting a flag describing the
;               contents:
;                       0 --    New position is empty
;                       1 --    Encountered a piece of the
;                               opposite color
;                       2 --    Encountered a piece of the
;                               same color
;                       3 --    New position is off the
;                               board
;
; CALLED BY:    MPIECE
;               ATTACK
;               PINFND
;
; CALLS:        None
;
; ARGUMENTS:    Direction from the direction array giving the
;               constant to be added for the new position.
;
;**********************************************************
PATH:    MOV     ebx,offset M2          ; Get previous position
         MOV     al,byte ptr [ebx]
         ADD     al,cl                  ; Add direction constant
         MOV     byte ptr [ebx],al      ; Save new position
         MOV     esi,[M2]               ; Load board index
         MOV     al,byte ptr [esi+BOARD] ; Get contents of board
         CMP     al,-1                  ; In border area ?
         JZ      PA2                    ; Yes - jump
         MOV     byte ptr [P2],al       ; Save piece
         AND     al,7                   ; Clear flags
         MOV     byte ptr [T2],al       ; Save piece type
         JNZ     skip1                  ; Return if empty
         RET
skip1:
         MOV     al,byte ptr [P2]       ; Get piece encountered
         MOV     ebx,offset P1          ; Get moving piece address
         XOR     al,byte ptr [ebx]      ; Compare
         TEST    al,80h                 ; Do colors match ?
         JZ      PA1                    ; Yes - jump
         MOV     al,1                   ; Set different color flag
         RET                            ; Return
PA1:     MOV     al,2                   ; Set same color flag
         RET                            ; Return
PA2:     MOV     al,3                   ; Set off board flag
         RET                            ; Return

;X p30
;*****************************************************************
; PIECE MOVER ROUTINE
;*****************************************************************
;
; FUNCTION:     To generate all the possible legal moves for a
;               given piece.
;
; CALLED BY:    GENMOV
;
; CALLS:        PATH
;               ADMOVE
;               CASTLE
;               ENPSNT
;
; ARGUMENTS:    The piece to be moved.
;*****************************************************************
MPIECE:  XOR     al,byte ptr [ebx]      ; Piece to move
         AND     al,87H                 ; Clear flag bit
         CMP     al,BPAWN               ; Is it a black Pawn ?
         JNZ     rel001                 ; No-Skip
         DEC     al                     ; Decrement for black Pawns
rel001:  AND     al,7                   ; Get piece type
         MOV     byte ptr [T1],al       ; Save piece type
         MOV     edi,[T1]               ; Load index to DCOUNT/DPOINT
         MOV     ch,byte ptr [edi+DCOUNT] ; Get direction count
         MOV     al,byte ptr [edi+DPOINT] ; Get direction pointer
         MOV     byte ptr [INDX2],al    ; Save as index to direct
         MOV     edi,[INDX2]            ; Load index
MP5:     MOV     cl,byte ptr [edi+DIRECT] ; Get move direction
         MOV     al,byte ptr [M1]       ; From position
         MOV     byte ptr [M2],al       ; Initialize to position
MP10:    CALL    PATH                   ; Calculate next position
         CMP     al,2                   ; Ready for new direction ?
         JNC     MP15                   ; Yes - Jump
         AND     al,al                  ; Test for empty square
         Z80_EXAF                       ; Save result
         MOV     al,byte ptr [T1]       ; Get piece moved
         CMP     al,PAWN+1              ; Is it a Pawn ?
         JC      MP20                   ; Yes - Jump
         CALL    ADMOVE                 ; Add move to list
         Z80_EXAF                       ; Empty square ?
         JNZ     MP15                   ; No - Jump
         MOV     al,byte ptr [T1]       ; Piece type
         CMP     al,KING                ; King ?
         JZ      MP15                   ; Yes - Jump
         CMP     al,BISHOP              ; Bishop, Rook, or Queen ?
         JNC     MP10                   ; Yes - Jump
MP15:    LEA     edi,[edi+1]            ; Increment direction index
         LAHF                           ; Decr. count-jump if non-zerc
         DEC ch
         JNZ     MP5
         SAHF
         MOV     al,byte ptr [T1]       ; Piece type
;X p31
         CMP     al,KING                ; King ?
         JNZ     skip2                  ; Yes - Try Castling
         CALL    CASTLE
skip2:
         RET                            ; Return
; ***** PAWN LOGIC *****
MP20:    MOV     al,ch                  ; Counter for direction
         CMP     al,3                   ; On diagonal moves ?
         JC      MP35                   ; Yes - Jump
         JZ      MP30                   ; -or-jump if on 2 square move
         Z80_EXAF                       ; Is forward square empty?
         JNZ     MP15                   ; No - jump
         MOV     al,byte ptr [M2]       ; Get "to" position
         CMP     al,91                  ; Promote white Pawn ?
         JNC     MP25                   ; Yes - Jump
         CMP     al,29                  ; Promote black Pawn ?
         JNC     MP26                   ; No - Jump
MP25:    MOV     ebx,offset P2          ; Flag address
         LAHF                           ; Set promote flag
         OR      byte ptr [ebx],20h
         SAHF
MP26:    CALL    ADMOVE                 ; Add to move list
         LEA     edi,[edi+1]            ; Adjust to two square move
         DEC     ch
         MOV     ebx,offset P1          ; Check Pawn moved flag
         TEST    byte ptr [ebx],8       ; Has it moved before ?
         JZ      MP10                   ; No - Jump
         JMP     MP15                   ; Jump
MP30:    Z80_EXAF                       ; Is forward square empty ?
         JNZ     MP15                   ; No - Jump
MP31:    CALL    ADMOVE                 ; Add to move list
         JMP     MP15                   ; Jump
MP35:    Z80_EXAF                       ; Is diagonal square empty ?
         JZ      MP36                   ; Yes - Jump
         MOV     al,byte ptr [M2]       ; Get "to" position
         CMP     al,91                  ; Promote white Pawn ?
         JNC     MP37                   ; Yes - Jump
         CMP     al,29                  ; Black Pawn promotion ?
         JNC     MP31                   ; No- Jump
MP37:    MOV     ebx,offset P2          ; Get flag address
         LAHF                           ; Set promote flag
         OR      byte ptr [ebx],20h
         SAHF
         JMP     MP31                   ; Jump
MP36:    CALL    ENPSNT                 ; Try en passant capture
         JMP     MP15                   ; Jump

;X p32
;**********************************************************
; EN PASSANT ROUTINE
;**********************************************************
; FUNCTION:     --      To test for en passant Pawn capture and
;                       to add it to the move list if it is
;                       legal.
;
; CALLED BY:    --      MPIECE
;
; CALLS:        --      ADMOVE
;                       ADJPTR
;
; ARGUMENTS:    --      None
;**********************************************************
ENPSNT:  MOV     al,byte ptr [M1]       ; Set position of Pawn
         MOV     ebx,offset P1          ; Check color
         TEST    byte ptr [ebx],80h     ; Is it white ?
         JZ      rel002                 ; Yes - skip
         ADD     al,10                  ; Add 10 for black
rel002:  CMP     al,61                  ; On en passant capture rank ?
         JNC     skip3                  ; No - return
         RET
skip3:
         CMP     al,69                  ; On en passant capture rank ?
         JC      skip4                  ; No - return
         RET
skip4:
         MOV     esi,[MLPTRJ]           ; Get pointer to previous move
         TEST    byte ptr [esi+MLFLG],10h ; First move for that piece ?
         JNZ     skip5                  ; No - return
         RET
skip5:
         MOV     al,byte ptr [esi+MLTOP] ; Get "to" postition
         MOV     byte ptr [M4],al       ; Store as index to board
         MOV     esi,[M4]               ; Load board index
         MOV     al,byte ptr [esi+BOARD] ; Get piece moved
         MOV     byte ptr [P3],al       ; Save it
         AND     al,7                   ; Get piece type
         CMP     al,PAWN                ; Is it a Pawn ?
         JZ      skip6                  ; No - return
         RET
skip6:
         MOV     al,byte ptr [M4]       ; Get "to" position
         MOV     ebx,offset M2          ; Get present "to" position
         SUB     al,byte ptr [ebx]      ; Find difference
         JP      rel003                 ; Positive ? Yes - Jump
         NEG     al                     ; Else take absolute value
         CMP     al,10                  ; Is difference 10 ?
rel003:  JZ      skip7                  ; No - return
         RET
skip7:
         MOV     ebx,offset P2          ; Address of flags
         LAHF                           ; Set double move flag
         OR      byte ptr [ebx],40h
         SAHF
         CALL    ADMOVE                 ; Add Pawn move to move list
         MOV     al,byte ptr [M1]       ; Save initial Pawn position
         MOV     byte ptr [M3],al
         MOV     al,byte ptr [M4]       ; Set "from" and "to" positions
                        ; for dummy move
;X p33
         MOV     byte ptr [M1],al
         MOV     byte ptr [M2],al
         MOV     al,byte ptr [P3]       ; Save captured Pawn
         MOV     byte ptr [P2],al
         CALL    ADMOVE                 ; Add Pawn capture to move list
         MOV     al,byte ptr [M3]       ; Restore "from" position
         MOV     byte ptr [M1],al

;*****************************************************************
; ADJUST MOVE LIST POINTER FOR DOUBLE MOVE
;*****************************************************************
; FUNCTION: --  To adjust move list pointer to link around
;               second move in double move.
;
; CALLED BY: -- ENPSNT
;               CASTLE
;               (This mini-routine is not really called,
;               but is jumped to to save time.)
;
; CALLS:    --  None
;
; ARGUMENTS: -- None
;*****************************************************************
ADJPTR:  MOV     ebx,[MLLST]            ; Get list pointer
         MOV     edx,-MOVSIZ            ; Size of a move entry
         LEA     ebx,[ebx+edx]          ; Back up list pointer
         MOV     [MLLST],ebx            ; Save list pointer
        mov     dword ptr [ebx],0   ;Zero out link ptr
         RET                            ; Return

;X p34
;*****************************************************************
; CASTLE ROUTINE
;*****************************************************************
; FUNCTION: --  To determine whether castling is legal
;               (Queen side, King side, or both) and add it
;               to the move list if it is.
;
; CALLED BY: -- MPIECE
;
; CALLS:   --   ATTACK
;               ADMOVE
;               ADJPTR
;
; ARGUMENTS: -- None
;*****************************************************************
CASTLE:  MOV     al,byte ptr [P1]       ; Get King
         TEST    al,8                   ; Has it moved ?
         JZ      skip8                  ; Yes - return
         RET
skip8:
         MOV     al,byte ptr [CKFLG]    ; Fetch Check Flag
         AND     al,al                  ; Is the King in check ?
         JZ      skip9                  ; Yes - Return
         RET
skip9:
         MOV     ecx,0FF03H             ; Initialize King-side values
CA5:     MOV     al,byte ptr [M1]       ; King position
         ADD     al,cl                  ; Rook position
         MOV     cl,al                  ; Save
         MOV     byte ptr [M3],al       ; Store as board index
         MOV     esi,[M3]               ; Load board index
         MOV     al,byte ptr [esi+BOARD] ; Get contents of board
         AND     al,7FH                 ; Clear color bit
         CMP     al,ROOK                ; Has Rook ever moved ?
         JNZ     CA20                   ; Yes - Jump
         MOV     al,cl                  ; Restore Rook position
         JMP     CA15                   ; Jump
CA10:    MOV     esi,[M3]               ; Load board index
         MOV     al,byte ptr [esi+BOARD] ; Get contents of board
         AND     al,al                  ; Empty ?
         JNZ     CA20                   ; No - Jump
         MOV     al,byte ptr [M3]       ; Current position
         CMP     al,22                  ; White Queen Knight square ?
         JZ      CA15                   ; Yes - Jump
         CMP     al,92                  ; Black Queen Knight square ?
         JZ      CA15                   ; Yes - Jump
         CALL    ATTACK                 ; Look for attack on square
         AND     al,al                  ; Any attackers ?
         JNZ     CA20                   ; Yes - Jump
         MOV     al,byte ptr [M3]       ; Current position
CA15:    ADD     al,ch                  ; Next position
         MOV     byte ptr [M3],al       ; Save as board index
         MOV     ebx,offset M1          ; King position
         CMP     al,byte ptr [ebx]      ; Reached King ?
;X p35
         JNZ     CA10                   ; No - jump
         SUB     al,ch                  ; Determine King's position
         SUB     al,ch
         MOV     byte ptr [M2],al       ; Save it
         MOV     ebx,offset P2          ; Address of flags
         MOV     byte ptr [ebx],40H     ; Set double move flag
         CALL    ADMOVE                 ; Put king move in list
         MOV     ebx,offset M1          ; Addr of King "from" position
         MOV     al,byte ptr [ebx]      ; Get King's "from" position
         MOV     byte ptr [ebx],cl      ; Store Rook "from" position
         SUB     al,ch                  ; Get Rook "to" position
         MOV     byte ptr [M2],al       ; Store Rook "to" position
         XOR     al,al                  ; Zero
         MOV     byte ptr [P2],al       ; Zero move flags
         CALL    ADMOVE                 ; Put Rook move in list
         CALL    ADJPTR                 ; Re-adjust move list pointer
         MOV     al,byte ptr [M3]       ; Restore King position
         MOV     byte ptr [M1],al       ; Store
CA20:    MOV     al,ch                  ; Scan Index
         CMP     al,1                   ; Done ?
         JNZ     skip10                 ; Yes - return
         RET
skip10:
         MOV     ecx,01FCH              ; Set Queen-side initial values
         JMP     CA5                    ; Jump

;X p36
;**********************************************************
; ADMOVE ROUTINE
;**********************************************************
; FUNCTION: --  To add a move to the move list
;
; CALLED BY: -- MPIECE
;               ENPSNT
;               CASTLE
;
; CALLS: --     None
;
; ARGUMENT: --  None
;**********************************************************
ADMOVE:  MOV     edx,[MLNXT]            ; Addr of next loc in move list
         MOV     ebx,offset MLEND       ; Address of list end
         AND     al,al                  ; Clear carry flag
         SBB     ebx,edx                ; Calculate difference
         JC      AM10                   ; Jump if out of space
         MOV     ebx,[MLLST]            ; Addr of prev. list area
         MOV     [MLLST],edx            ; Save next as previous
         MOV     dword ptr [ebx],edx    ; Store link address
         MOV     ebx,offset P1          ; Address of moved piece
         TEST    byte ptr [ebx],8       ; Has it moved before ?
         JNZ     rel004                 ; Yes - jump
         MOV     ebx,offset P2          ; Address of move flags
         LAHF                           ; Set first move flag
         OR      byte ptr [ebx],10h
         SAHF
rel004:  XCHG    ebx,edx                ; Address of move area
        MOV     dword ptr [ebx],0   ; Store zero in link address
        LEA     ebx,[ebx+4]
         MOV     al,byte ptr [M1]       ; Store "from" move position
         MOV     byte ptr [ebx],al
         LEA     ebx,[ebx+1]
         MOV     al,byte ptr [M2]       ; Store "to" move position
         MOV     byte ptr [ebx],al
         LEA     ebx,[ebx+1]
         MOV     al,byte ptr [P2]       ; Store move flags/capt. piece
         MOV     byte ptr [ebx],al
         LEA     ebx,[ebx+1]
         MOV     byte ptr [ebx],0       ; Store initial move value
         LEA     ebx,[ebx+1]
         MOV     [MLNXT],ebx            ; Save address for next move
         RET                            ; Return
AM10:                                   ;MVI     M,0     ; Abort entry on table ovflow
        ;INX     H
        ;MVI     M,0       ;TODO fix this
        ;DCX     H
         RET

;X p37
;**********************************************************
; GENERATE MOVE ROUTINE
;**********************************************************
; FUNCTION: --  To generate the move set for all of the
;               pieces of a given color.
;
; CALLED BY: -- FNDMOV
;
; CALLS: --     MPIECE
;               INCHK
;
; ARGUMENTS: -- None
;**********************************************************
GENMOV:  CALL    INCHK                  ; Test for King in check
         MOV     byte ptr [CKFLG],al    ; Save attack count as flag
         MOV     edx,[MLNXT]            ; Addr of next avail list space
         MOV     ebx,[MLPTRI]           ; Ply list pointer index
        LEA     ebx,[ebx+PTRSIZ]       ; Increment to next ply
        MOV     dword ptr [ebx],edx    ; Save move list pointer
        LEA     ebx,[ebx+PTRSIZ]       ;
         MOV     [MLPTRI],ebx           ; Save new index
         MOV     [MLLST],ebx            ; Last pointer for chain init.
         MOV     al,21                  ; First position on board
GM5:     MOV     byte ptr [M1],al       ; Save as index
         MOV     esi,[M1]               ; Load board index
         MOV     al,byte ptr [esi+BOARD] ; Fetch board contents
         AND     al,al                  ; Is it empty ?
         JZ      GM10                   ; Yes - Jump
         CMP     al,-1                  ; Is it a boarder square ?
         JZ      GM10                   ; Yes - Jump
         MOV     byte ptr [P1],al       ; Save piece
         MOV     ebx,offset COLOR       ; Address of color of piece
         XOR     al,byte ptr [ebx]      ; Test color of piece
         TEST    al,80h                 ; Match ?
         JNZ     skip11                 ; Yes - call Move Piece
         CALL    MPIECE
skip11:
GM10:    MOV     al,byte ptr [M1]       ; Fetch current board position
         INC     al                     ; Incr to next board position
         CMP     al,99                  ; End of board array ?
         JNZ     GM5                    ; No - Jump
         RET                            ; Return

;X p38
;**********************************************************
; CHECK ROUTINE
;**********************************************************
; FUNCTION: --  To determine whether or not the
;               King is in check.
;
; CALLED BY: -- GENMOV
;               FNDMOV
;               EVAL
;
; CALLS: --     ATTACK
;
; ARGUMENTS: -- Color of King
;**********************************************************
INCHK:   MOV     al,byte ptr [COLOR]    ; Get color
INCHK1:  MOV     ebx,offset POSK        ; Addr of white King position
         AND     al,al                  ; White ?
         JZ      rel005                 ; Yes - Skip
         LEA     ebx,[ebx+1]            ; Addr of black King position
rel005:  MOV     al,byte ptr [ebx]      ; Fetch King position
         MOV     byte ptr [M3],al       ; Save
         MOV     esi,[M3]               ; Load board index
         MOV     al,byte ptr [esi+BOARD] ; Fetch board contents
         MOV     byte ptr [P1],al       ; Save
         AND     al,7                   ; Get piece type
         MOV     byte ptr [T1],al       ; Save
         CALL    ATTACK                 ; Look for attackers on King
         RET                            ; Return

;**********************************************************
; ATTACK ROUTINE
;**********************************************************

; FUNCTION: --  To find all attackers on a given square
;               by scanning outward from the square
;               until a piece is found that attacks
;               that square, or a piece is found that
;               doesn't attack that square, or the edge
;               of the board is reached.
;
;                       In determining which pieces attack a square,
;               this routine also takes into account the ability of
;               certain pieces to attack through another attacking
;               piece. (For example a queen lined up behind a bishop
;               of her same color along a diagonal.) The bishop is
;               then said to be transparent to the queen, since both
;               participate in the attack.
;
;                       In the case where this routine is called by
;               CASTLE or INCHK, the routine is terminated as soon as
;               an attacker of the opposite color is encountered.
;
; CALLED BY: -- POINTS
;               PINFND
;               CASTLE
;               INCHK
;
; CALLS: --     PATH
;               ATKSAV
;
; ARGUMENTS: -- None
;*****************************************************************
ATTACK:  PUSH    ecx                    ; Save Register B
         XOR     al,al                  ; Clear
         MOV     ch,16                  ; Initial direction count
         MOV     byte ptr [INDX2],al    ; Initial direction index
         MOV     edi,[INDX2]            ; Load index
AT5:     MOV     cl,byte ptr [edi+DIRECT] ; Get direction
         MOV     dh,0                   ; Init. scan count/flags
         MOV     al,byte ptr [M3]       ; Init. board start position
         MOV     byte ptr [M2],al       ; Save
AT10:    INC     dh                     ; Increment scan count
         CALL    PATH                   ; Next position
         CMP     al,1                   ; Piece of a opposite color ?
         JZ      AT14A                  ; Yes - jump
         CMP     al,2                   ; Piece of same color ?
         JZ      AT14B                  ; Yes - jump
         AND     al,al                  ; Empty position ?
         JNZ     AT12                   ; No - jump
         MOV     al,ch                  ; Fetch direction count
         CMP     al,9                   ; On knight scan ?
         JNC     AT10                   ; No - jump
AT12:    LEA     edi,[edi+1]            ; Increment direction index
         LAHF                           ; Done ? No - jump
         DEC ch
         JNZ     AT5
         SAHF
         XOR     al,al                  ; No attackers
AT13:    POP     ecx                    ; Restore register B
         RET                            ; Return
AT14A:   TEST    dh,40h                 ; Same color found already ?
         JNZ     AT12                   ; Yes - jump
         LAHF                           ; Set opposite color found flag
         OR      dh,20h
         SAHF
         JMP     AT14                   ; Jump
AT14B:   TEST    dh,20h                 ; Opposite color found already?
         JNZ     AT12                   ; Yes - jump
         LAHF                           ; Set same color found flag
         OR      dh,40h
         SAHF

; ***** DETERMINE IF PIECE ENCOUNTERED ATTACKS SQUARE *****
AT14:    MOV     al,byte ptr [T2]       ; Fetch piece type encountered
         MOV     dl,al                  ; Save
         MOV     al,ch                  ; Get direction-counter
         CMP     al,9                   ; Look for Knights ?
         JC      AT25                   ; Yes - jump
         MOV     al,dl                  ; Get piece type
         CMP     al,QUEEN               ; Is is a Queen ?
         JNZ     AT15                   ; No - Jump
         LAHF                           ; Set Queen found flag
         OR      dh,80h
         SAHF
         JMP     AT30                   ; Jump
AT15:    MOV     al,dh                  ; Get flag/scan count
         AND     al,0FH                 ; Isolate count
         CMP     al,1                   ; On first position ?
         JNZ     AT16                   ; No - jump
         MOV     al,dl                  ; Get encountered piece type
         CMP     al,KING                ; Is it a King ?
         JZ      AT30                   ; Yes - jump
AT16:    MOV     al,ch                  ; Get direction counter
         CMP     al,13                  ; Scanning files or ranks ?
         JC      AT21                   ; Yes - jump
         MOV     al,dl                  ; Get piece type
         CMP     al,BISHOP              ; Is it a Bishop ?
         JZ      AT30                   ; Yes - jump
         MOV     al,dh                  ; Get flags/scan count
         AND     al,0FH                 ; Isolate count
         CMP     al,1                   ; On first position ?
         JNZ     AT12                   ; No - jump
         CMP     al,dl                  ; Is it a Pawn ?
         JNZ     AT12                   ; No - jump
         MOV     al,byte ptr [P2]       ; Fetch piece including color
;X p41
         TEST    al,80h                 ; Is it white ?
         JZ      AT20                   ; Yes - jump
         MOV     al,ch                  ; Get direction counter
         CMP     al,15                  ; On a non-attacking diagonal ?
         JC      AT12                   ; Yes - jump
         JMP     AT30                   ; Jump
AT20:    MOV     al,ch                  ; Get direction counter
         CMP     al,15                  ; On a non-attacking diagonal ?
         JNC     AT12                   ; Yes - jump
         JMP     AT30                   ; Jump
AT21:    MOV     al,dl                  ; Get piece type
         CMP     al,ROOK                ; Is is a Rook ?
         JNZ     AT12                   ; No - jump
         JMP     AT30                   ; Jump
AT25:    MOV     al,dl                  ; Get piece type
         CMP     al,KNIGHT              ; Is it a Knight ?
         JNZ     AT12                   ; No - jump
AT30:    MOV     al,byte ptr [T1]       ; Attacked piece type/flag
         CMP     al,7                   ; Call from POINTS ?
         JZ      AT31                   ; Yes - jump
         TEST    dh,20h                 ; Is attacker opposite color ?
         JZ      AT32                   ; No - jump
         MOV     al,1                   ; Set attacker found flag
         JMP     AT13                   ; Jump
AT31:    CALL    ATKSAV                 ; Save attacker in attack list
AT32:    MOV     al,byte ptr [T2]       ; Attacking piece type
         CMP     al,KING                ; Is it a King,?
         JZ      AT12                   ; Yes - jump
         CMP     al,KNIGHT              ; Is it a Knight ?
         JZ      AT12                   ; Yes - jump
         JMP     AT10                   ; Jump
;p42

;****************************************************************
; ATTACK SAVE ROUTINE
;****************************************************************
; FUNCTION: --  To save an attacking piece value in the
;               attack list, and to increment the attack
;               count for that color piece.
;
;               The pin piece list is checked for the
;               attacking piece, and if found there, the
;               piece is not included in the attack list.
;
; CALLED BY: -- ATTACK
;
; CALLS:     -- PNCK
;
; ARGUMENTS: -- None
;****************************************************************
ATKSAV:  PUSH    ecx                    ; Save Regs BC
         PUSH    edx                    ; Save Regs DE
         MOV     al,byte ptr [NPINS]    ; Number of pinned pieces
         AND     al,al                  ; Any ?
         JZ      skip12                 ; yes - check pin list
         CALL    PNCK
skip12:
         MOV     esi,[T2]               ; Init index to value table
         MOV     ebx,offset ATKLST      ; Init address of attack list
         MOV     ecx,0                  ; Init increment for white
         MOV     al,byte ptr [P2]       ; Attacking piece
         TEST    al,80h                 ; Is it white ?
         JZ      rel006                 ; Yes - jump
         MOV     cl,7                   ; Init increment for black
rel006:  AND     al,7                   ; Attacking piece type
         MOV     dl,al                  ; Init increment for type
         TEST    dh,80h                 ; Queen found this scan ?
         JZ      rel007                 ; No - jump
         MOV     dl,QUEEN               ; Use Queen slot in attack list
rel007:  LEA     ebx,[ebx+ecx]          ; Attack list address
         INC     byte ptr [ebx]         ; Increment list count
         MOV     dh,0
         LEA     ebx,[ebx+edx]          ; Attack list slot address
         MOV     al,byte ptr [ebx]      ; Get data already there
         AND     al,0FH                 ; Is first slot empty ?
         JZ      AS20                   ; Yes - jump
         MOV     al,byte ptr [ebx]      ; Get data again
         AND     al,0F0H                ; Is second slot empty ?
         JZ      AS19                   ; Yes - jump
         LEA     ebx,[ebx+1]            ; Increment to King slot
         JMP     AS20                   ; Jump
AS19:    Z80_RLD                        ; Temp save lower in upper
         MOV     al,byte ptr [esi+PVALUE] ; Get new value for attack list
         Z80_RRD                        ; Put in 2nd attack list slot
         JMP     AS25                   ; Jump
AS20:    MOV     al,byte ptr [esi+PVALUE] ; Get new value for attack list
         Z80_RLD                        ; Put in 1st attack list slot
;X p43
AS25:    POP     edx                    ; Restore DE regs
         POP     ecx                    ; Restore BC regs
         RET                            ; Return

;**********************************************************
; PIN CHECK ROUTINE
;**********************************************************
; FUNCTION:  -- Checks to see if the attacker is in the
;               pinned piece list. If so he is not a valid
;               attacker unless the direction in which he
;               attacks is the same as the direction along
;               which he is pinned. If the piece is
;               found to be invalid as an attacker, the
;               return to the calling routine is aborted
;               and this routine returns directly to ATTACK.
;
; CALLED BY: -- ATKSAV
;
; CALLS:     -- None
;
; ARGUMENTS: -- The direction of the attack. The
;               pinned piece counnt.
;**********************************************************
PNCK:    MOV     dh,cl                  ; Save attack direction
         MOV     dl,0                   ; Clear flag
         MOV     cl,al                  ; Load pin count for search
         MOV     ch,0
         MOV     al,byte ptr [M2]       ; Position of piece
         MOV     ebx,offset PLISTA      ; Pin list address
PC1:     CCIR                           ; Search list for position
         JZ      skip13                 ; Return if not found
         RET
skip13:
         Z80_EXAF                       ; Save search paramenters
         TEST    dl,1                   ; Is this the first find ?
         JNZ     PC5                    ; No - jump
         LAHF                           ; Set first find flag
         OR      dl,1
         SAHF
         PUSH    ebx                    ; Get corresp index to dir list
         POP     esi
         MOV     al,byte ptr [esi+9]    ; Get direction
         CMP     al,dh                  ; Same as attacking direction ?
         JZ      PC3                    ; Yes - jump
         NEG     al                     ; Opposite direction ?
         CMP     al,dh                  ; Same as attacking direction ?
         JNZ     PC5                    ; No - jump
PC3:     Z80_EXAF                       ; Restore search parameters
         JPE     PC1                    ; Jump if search not complete
         RET                            ; Return
PC5:     POP     eax                    ; Abnormal exit
         sahf
         POP     edx                    ; Restore regs.
         POP     ecx
         RET                            ; Return to ATTACK

;X p44
;**********************************************************
; PIN FIND ROUTINE
;**********************************************************
; FUNCTION: --  To produce a list of all pieces pinned
;               against the King or Queen, for both white
;               and black.
;
; CALLED BY: -- FNDMOV
;               EVAL
;
; CALLS: --     PATH
;               ATTACK
;
; ARGUMENTS: -- None
;**********************************************************
PINFND:  XOR     al,al                  ; Zero pin count
         MOV     byte ptr [NPINS],al
         MOV     edx,offset POSK        ; Addr of King/Queen pos list
PF1:     MOV     al,[edx]               ; Get position of royal piece
         AND     al,al                  ; Is it on board ?
         JZ      PF26                   ; No- jump
         CMP     al,-1                  ; At end of list ?
         JNZ     skip14                 ; Yes return
         RET
skip14:
         MOV     byte ptr [M3],al       ; Save position as board index
         MOV     esi,[M3]               ; Load index to board
         MOV     al,byte ptr [esi+BOARD] ; Get contents of board
         MOV     byte ptr [P1],al       ; Save
         MOV     ch,8                   ; Init scan direction count
         XOR     al,al
         MOV     byte ptr [INDX2],al    ; Init direction index
         MOV     edi,[INDX2]
PF2:     MOV     al,byte ptr [M3]       ; Get King/Queen position
         MOV     byte ptr [M2],al       ; Save
         XOR     al,al
         MOV     byte ptr [M4],al       ; Clear pinned piece saved pos
         MOV     cl,byte ptr [edi+DIRECT] ; Get direction of scan
PF5:     CALL    PATH                   ; Compute next position
         AND     al,al                  ; Is it empty ?
         JZ      PF5                    ; Yes - jump
         CMP     al,3                   ; Off board ?
         JZ      PF25                   ; Yes - jump
         CMP     al,2                   ; Piece of same color
         MOV     al,byte ptr [M4]       ; Load pinned piece position
         JZ      PF15                   ; Yes - jump
         AND     al,al                  ; Possible pin ?
         JZ      PF25                   ; No - jump
         MOV     al,byte ptr [T2]       ; Piece type encountered
         CMP     al,QUEEN               ; Queen ?
         JZ      PF19                   ; Yes - jump
         MOV     bl,al                  ; Save piece type
;X p45
         MOV     al,ch                  ; Direction counter
         CMP     al,5                   ; Non-diagonal direction ?
         JC      PF10                   ; Yes - jump
         MOV     al,bl                  ; Piece type
         CMP     al,BISHOP              ; Bishop ?
         JNZ     PF25                   ; No - jump
         JMP     PF20                   ; Jump
PF10:    MOV     al,bl                  ; Piece type
         CMP     al,ROOK                ; Rook ?
         JNZ     PF25                   ; No - jump
         JMP     PF20                   ; Jump
PF15:    AND     al,al                  ; Possible pin ?
         JNZ     PF25                   ; No - jump
         MOV     al,byte ptr [M2]       ; Save possible pin position
         MOV     byte ptr [M4],al
         JMP     PF5                    ; Jump
PF19:    MOV     al,byte ptr [P1]       ; Load King or Queen
         AND     al,7                   ; Clear flags
         CMP     al,QUEEN               ; Queen ?
         JNZ     PF20                   ; No - jump
         PUSH    ecx                    ; Save regs.
         PUSH    edx
         PUSH    edi
         XOR     al,al                  ; Zero out attack list
         MOV     ch,14
         MOV     ebx,offset ATKLST
back02:  MOV     byte ptr [ebx],al
         LEA     ebx,[ebx+1]
         LAHF
         DEC ch
         JNZ     back02
         SAHF
         MOV     al,7                   ; Set attack flag
         MOV     byte ptr [T1],al
         CALL    ATTACK                 ; Find attackers/defenders
         MOV     ebx,WACT               ; White queen attackers
         MOV     edx,BACT               ; Black queen attackers
         MOV     al,byte ptr [P1]       ; Get queen
         TEST    al,80h                 ; Is she white ?
         JZ      rel008                 ; Yes - skip
         XCHG    ebx,edx                ; Reverse for black
rel008:  MOV     al,byte ptr [ebx]      ; Number of defenders
         XCHG    ebx,edx                ; Reverse for attackers
         SUB     al,byte ptr [ebx]      ; Defenders minus attackers
         DEC     al                     ; Less 1
         POP     edi                    ; Restore regs.
         POP     edx
         POP     ecx
         JP      PF25                   ; Jump if pin not valid
PF20:    MOV     ebx,offset NPINS       ; Address of pinned piece count
         INC     byte ptr [ebx]         ; Increment
         MOV     esi,[NPINS]            ; Load pin list index
         MOV     byte ptr [esi+PLISTD],cl ; Save direction of pin
;X p46
         MOV     al,byte ptr [M4]       ; Position of pinned piece
         MOV     byte ptr [esi+PLIST],al ; Save in list
PF25:    LEA     edi,[edi+1]            ; Increment direction index
         LAHF                           ; Done ? No - Jump
         DEC ch
         JNZ     PF27
         SAHF
PF26:    LEA     edx,[edx+1]            ; Incr King/Queen pos index
         JMP     PF1                    ; Jump
PF27:    JMP     PF2                    ; Jump

;X p47
;****************************************************************
; EXCHANGE ROUTINE
;****************************************************************
; FUNCTION: --  To determine the exchange value of a
;               piece on a given square by examining all
;               attackers and defenders of that piece.
;
; CALLED BY: -- POINTS
;
; CALLS: --     NEXTAD
;
; ARGUMENTS: -- None.
;****************************************************************
XCHNG:   Z80_EXX                        ; Swap regs.
         MOV     al,byte ptr [P1]       ; Piece attacked
         MOV     ebx,WACT               ; Addr of white attkrs/dfndrs
         MOV     edx,BACT               ; Addr of black attkrs/dfndrs
         TEST    al,80h                 ; Is piece white ?
         JZ      rel009                 ; Yes - jump
         XCHG    ebx,edx                ; Swap list pointers
rel009:  MOV     ch,byte ptr [ebx]      ; Init list counts
         XCHG    ebx,edx
         MOV     cl,byte ptr [ebx]
         XCHG    ebx,edx
         Z80_EXX                        ; Restore regs.
         MOV     cl,0                   ; Init attacker/defender flag
         MOV     dl,0                   ; Init points lost count
         MOV     esi,[T3]               ; Load piece value index
         MOV     dh,byte ptr [esi+PVALUE] ; Get attacked piece value
         SHL     dh,1                   ; Double it
         MOV     ch,dh                  ; Save
         CALL    NEXTAD                 ; Retrieve first attacker
         JNZ     skip15                 ; Return if none
         RET
skip15:
XC10:    MOV     bl,al                  ; Save attacker value
         CALL    NEXTAD                 ; Get next defender
         JZ      XC18                   ; Jump if none
         Z80_EXAF                       ; Save defender value
         MOV     al,ch                  ; Get attacked value
         CMP     al,bl                  ; Attacked less than attacker ?
         JNC     XC19                   ; No - jump
         Z80_EXAF                       ; -Restore defender
XC15:    CMP     al,bl                  ; Defender less than attacker ?
         JNC     skip16                 ; Yes - return
         RET
skip16:
         CALL    NEXTAD                 ; Retrieve next attacker value
         JNZ     skip17                 ; Return if none
         RET
skip17:
         MOV     bl,al                  ; Save attacker value
         CALL    NEXTAD                 ; Retrieve next defender value
         JNZ     XC15                   ; Jump if none
XC18:    Z80_EXAF                       ; Save Defender
         MOV     al,ch                  ; Get value of attacked piece
;X p48
XC19:    TEST    cl,1                   ; Attacker or defender ?
         JZ      rel010                 ; Jump if defender
         NEG     al                     ; Negate value for attacker
         ADD     al,dl                  ; Total points lost
rel010:  MOV     dl,al                  ; Save total
         Z80_EXAF                       ; Restore previous defender
         JNZ     skip18                 ; Return if none
         RET
skip18:
         MOV     ch,bl                  ; Prev attckr becomes defender
         JMP     XC10                   ; Jump

;****************************************************************
; NEXT ATTACKER/DEFENDER ROUTINE
;****************************************************************
; FUNCTION: --  To retrieve the next attacker or defender
;               piece value from the attack list, and delete
;               that piece from the list.
;
; CALLED BY: -- XCHNG
;
; CALLS: --     None
;
; ARGUMENTS: -- Attack list addresses.
;               Side flag
;               Attack list counts
;****************************************************************
NEXTAD:  INC     cl                     ; Increment side flag
         Z80_EXX                        ; Swap registers
         MOV     al,ch                  ; Swap list counts
         MOV     ch,cl
         MOV     cl,al
         XCHG    ebx,edx                ; Swap list pointers
         XOR     al,al
         CMP     al,ch                  ; At end of list ?
         JZ      NX6                    ; Yes - jump
         DEC     ch                     ; Decrement list count
back03:  LEA     ebx,[ebx+1]            ; Increment list inter
         CMP     al,byte ptr [ebx]      ; Check next item in list
         JZ      back03                 ; Jump if empty
         Z80_RRD                        ; Get value from list
         ADD     al,al                  ; Double it
         LEA     ebx,[ebx-1]            ; Decrement list pointer
NX6:     Z80_EXX                        ; Restore regs.
         RET                            ; Return

;X p49
;****************************************************************
; POINT EVALUATION ROUTINE
;****************************************************************
; FUNCTION: --  To perform a static board evaluation and
;               derive a score for a given board position
;
; CALLED BY: -- FNDMOV
;               EVAL
;
; CALLS: --     ATTACK
;               XCHNG
;               LIMIT
;
; ARGUMENTS: -- None
;****************************************************************
POINTS:  XOR     al,al                  ; Zero out variables
         MOV     byte ptr [MTRL],al
         MOV     byte ptr [BRDC],al
         MOV     byte ptr [PTSL],al
         MOV     byte ptr [PTSW1],al
         MOV     byte ptr [PTSW2],al
         MOV     byte ptr [PTSCK],al
         MOV     ebx,offset T1          ; Set attacker flag
         MOV     byte ptr [ebx],7
         MOV     al,21                  ; Init to first square on board
PT5:     MOV     byte ptr [M3],al       ; Save as board index
         MOV     esi,[M3]               ; Load board index
         MOV     al,byte ptr [esi+BOARD] ; Get piece from board
         CMP     al,-1                  ; Off board edge ?
         JZ      PT25                   ; Yes - jump
         MOV     ebx,offset P1          ; Save piece, if any
         MOV     byte ptr [ebx],al
         AND     al,7                   ; Save piece type, if any
         MOV     byte ptr [T3],al
         CMP     al,KNIGHT              ; Less than a Knight (Pawn) ?
         JC      PT6X                   ; Yes - Jump
         CMP     al,ROOK                ; Rook, Queen or King ?
         JC      PT6B                   ; No - jump
         CMP     al,KING                ; Is it a King ?
         JZ      PT6AA                  ; Yes - jump
         MOV     al,byte ptr [MOVENO]   ; Get move number
         CMP     al,7                   ; Less than 7 ?
         JC      PT6A                   ; Yes - Jump
         JMP     PT6X                   ; Jump
PT6AA:   TEST    byte ptr [ebx],10h     ; Castled yet ?
         JZ      PT6A                   ; No - jump
         MOV     al,+6                  ; Bonus for castling
         TEST    byte ptr [ebx],80h     ; Check piece color
         JZ      PT6D                   ; Jump if white
         MOV     al,-6                  ; Bonus for black castling
;X p50
         JMP     PT6D                   ; Jump
PT6A:    TEST    byte ptr [ebx],8       ; Has piece moved yet ?
         JZ      PT6X                   ; No - jump
         JMP     PT6C                   ; Jump
PT6B:    TEST    byte ptr [ebx],8       ; Has piece moved yet ?
         JNZ     PT6X                   ; Yes - jump
PT6C:    MOV     al,-2                  ; Two point penalty for white
         TEST    byte ptr [ebx],80h     ; Check piece color
         JZ      PT6D                   ; Jump if white
         MOV     al,+2                  ; Two point penalty for black
PT6D:    MOV     ebx,offset BRDC        ; Get address of board control
         ADD     al,byte ptr [ebx]      ; Add on penalty/bonus points
         MOV     byte ptr [ebx],al      ; Save
PT6X:    XOR     al,al                  ; Zero out attack list
         MOV     ch,14
         MOV     ebx,offset ATKLST
back04:  MOV     byte ptr [ebx],al
         LEA     ebx,[ebx+1]
         LAHF
         DEC ch
         JNZ     back04
         SAHF
         CALL    ATTACK                 ; Build attack list for square
         MOV     ebx,BACT               ; Get black attacker count addr
         MOV     al,byte ptr [WACT]     ; Get white attacker count
         SUB     al,byte ptr [ebx]      ; Compute count difference
         MOV     ebx,offset BRDC        ; Address of board control
         ADD     al,byte ptr [ebx]      ; Accum board control score
         MOV     byte ptr [ebx],al      ; Save
         MOV     al,byte ptr [P1]       ; Get piece on current square
         AND     al,al                  ; Is it empty ?
         JZ      PT25                   ; Yes - jump
         CALL    XCHNG                  ; Evaluate exchange, if any
         XOR     al,al                  ; Check for a loss
         CMP     al,dl                  ; Points lost ?
         JZ      PT23                   ; No - Jump
         DEC     dh                     ; Deduct half a Pawn value
         MOV     al,byte ptr [P1]       ; Get piece under attack
         MOV     ebx,offset COLOR       ; Color of side just moved
         XOR     al,byte ptr [ebx]      ; Compare with piece
         TEST    al,80h                 ; Do colors match ?
         MOV     al,dl                  ; Points lost
         JNZ     PT20                   ; Jump if no match
         MOV     ebx,offset PTSL        ; Previous max points lost
         CMP     al,byte ptr [ebx]      ; Compare to current value
         JC      PT23                   ; Jump if greater than
         MOV     byte ptr [ebx],dl      ; Store new value as max lost
         MOV     esi,[MLPTRJ]           ; Load pointer to this move
         MOV     al,byte ptr [M3]       ; Get position of lost piece
         CMP     al,byte ptr [esi+MLTOP] ; Is it the one moving ?
         JNZ     PT23                   ; No - jump
         MOV     byte ptr [PTSCK],al    ; Save position as a flag
         JMP     PT23                   ; Jump
;X p51
PT20:    MOV     ebx,offset PTSW1       ; Previous maximum points won
         CMP     al,byte ptr [ebx]      ; Compare to current value
         JC      rel011                 ; Jump if greater than
         MOV     al,byte ptr [ebx]      ; Load previous max value
         MOV     byte ptr [ebx],dl      ; Store new value as max won
rel011:  MOV     ebx,offset PTSW2       ; Previous 2nd max points won
         CMP     al,byte ptr [ebx]      ; Compare to current value
         JC      PT23                   ; Jump if greater than
         MOV     byte ptr [ebx],al      ; Store as new 2nd max lost
PT23:    MOV     ebx,offset P1          ; Get piece
         TEST    byte ptr [ebx],80h     ; Test color
         MOV     al,dh                  ; Value of piece
         JZ      rel012                 ; Jump if white
         NEG     al                     ; Negate for black
rel012:  MOV     ebx,offset MTRL        ; Get addrs of material total
         ADD     al,byte ptr [ebx]      ; Add new value
         MOV     byte ptr [ebx],al      ; Store
PT25:    MOV     al,byte ptr [M3]       ; Get current board position
         INC     al                     ; Increment
         CMP     al,99                  ; At end of board ?
         JNZ     PT5                    ; No - jump
         MOV     al,byte ptr [PTSCK]    ; Moving piece lost flag
         AND     al,al                  ; Was it lost ?
         JZ      PT25A                  ; No - jump
         MOV     al,byte ptr [PTSW2]    ; 2nd max points won
         MOV     byte ptr [PTSW1],al    ; Store as max points won
         XOR     al,al                  ; Zero out 2nd max points won
         MOV     byte ptr [PTSW2],al
PT25A:   MOV     al,byte ptr [PTSL]     ; Get max points lost
         AND     al,al                  ; Is it zero ?
         JZ      rel013                 ; Yes - jump
         DEC     al                     ; Decrement it
rel013:  MOV     ch,al                  ; Save it
         MOV     al,byte ptr [PTSW1]    ; Max,points won
         AND     al,al                  ; Is it zero ?
         JZ      rel014                 ; Yes - jump
         MOV     al,byte ptr [PTSW2]    ; 2nd max points won
         AND     al,al                  ; Is it zero ?
         JZ      rel014                 ; Yes - jump
         DEC     al                     ; Decrement it
         SHR     al,1                   ; Divide it by 2
         SUB     al,ch                  ; Subtract points lost
rel014:  MOV     ebx,offset COLOR       ; Color of side just moved ???
         TEST    byte ptr [ebx],80h     ; Is it white ?
         JZ      rel015                 ; Yes - jump
         NEG     al                     ; Negate for black
rel015:  MOV     ebx,offset MTRL        ; Net material on board
         ADD     al,byte ptr [ebx]      ; Add exchange adjustments
         MOV     ebx,offset MV0         ; Material at ply 0
;X p52
         SUB     al,byte ptr [ebx]      ; Subtract from current
         MOV     ch,al                  ; Save
         MOV     al,30                  ; Load material limit
         CALL    LIMIT                  ; Limit to plus or minus value
         MOV     dl,al                  ; Save limited value
         MOV     al,byte ptr [BRDC]     ; Get board control points
         MOV     ebx,offset BC0         ; Board control at ply zero
         SUB     al,byte ptr [ebx]      ; Get difference
         MOV     ch,al                  ; Save
         MOV     al,byte ptr [PTSCK]    ; Moving piece lost flag
         AND     al,al                  ; Is it zero ?
         JZ      rel026                 ; Yes - jump
         MOV     ch,0                   ; Zero board control points
rel026:  MOV     al,6                   ; Load board control limit
         CALL    LIMIT                  ; Limit to plus or minus value
         MOV     dh,al                  ; Save limited value
         MOV     al,dl                  ; Get material points
         ADD     al,al                  ; Multiply by 4
         ADD     al,al
         ADD     al,dh                  ; Add board control
         MOV     ebx,offset COLOR       ; Color of side just moved
         TEST    byte ptr [ebx],80h     ; Is it white ?
         JNZ     rel016                 ; No - jump
         NEG     al                     ; Negate for white
rel016:  ADD     al,80H                 ; Rescale score (neutral = 80H
         MOV     byte ptr [VALM],al     ; Save score
         MOV     esi,[MLPTRJ]           ; Load move list pointer
         MOV     byte ptr [esi+MLVAL],al ; Save score in move list
         RET                            ; Return

;X p53
;**********************************************************
; LIMIT ROUTINE
;**********************************************************
; FUNCTION: --  To limit the magnitude of a given value
;               to another given value.
;
; CALLED BY: -- POINTS
;
; CALLS: --     None
;
; ARGUMENTS: -- Input   - Value, to be limited in the B
;                         register.
;                       - Value to limit to in the A register
;               Output  - Limited value in the A register.
;**********************************************************
LIMIT:   TEST    ch,80h                 ; Is value negative ?
         JZ      LIM10                  ; No - jump
         NEG     al                     ; Make positive
         CMP     al,ch                  ; Compare to limit
         JC      skip19                 ; Return if outside limit
         RET
skip19:
         MOV     al,ch                  ; Output value as is
         RET                            ; Return
LIM10:   CMP     al,ch                  ; Compare to limit
         JNC     skip20                 ; Return if outside limit
         RET
skip20:
         MOV     al,ch                  ; Output value as is
         RET                            ; Return
;X      .END            ;X Bug in the original listing.

;X p54
;**********************************************************
; MOVE ROUTINE
;**********************************************************
; FUNCTION: --  To execute a move from the move list on the
;               board array.
;
; CALLED BY: -- CPTRMV
;               PLYRMV
;               EVAL
;               FNDMOV
;               VALMOV
;
; CALLS: --     None
;
; ARGUMENTS: -- None
;**********************************************************
MOVE:    MOV     ebx,[MLPTRJ]           ; Load move list pointer
         LEA     ebx,[ebx+4]    ; Increment past link bytes
MV1:     MOV     al,byte ptr [ebx]      ; "From" position
         MOV     byte ptr [M1],al       ; Save
         LEA     ebx,[ebx+1]            ; Increment pointer
         MOV     al,byte ptr [ebx]      ; "To" position
         MOV     byte ptr [M2],al       ; Save
         LEA     ebx,[ebx+1]            ; Increment pointer
         MOV     dh,byte ptr [ebx]      ; Get captured piece/flags
         MOV     esi,[M1]               ; Load "from" pos board index
         MOV     dl,byte ptr [esi+BOARD] ; Get piece moved
         TEST    dh,20h                 ; Test Pawn promotion flag
         JNZ     MV15                   ; Jump if set
         MOV     al,dl                  ; Piece moved
         AND     al,7                   ; Clear flag bits
         CMP     al,QUEEN               ; Is it a queen ?
         JZ      MV20                   ; Yes - jump
         CMP     al,KING                ; Is it a king ?
         JZ      MV30                   ; Yes - jump
MV5:     MOV     edi,[M2]               ; Load "to" pos board index
         LAHF                           ; Set piece moved flag
         OR      dl,8
         SAHF
         MOV     byte ptr [edi+BOARD],dl ; Insert piece at new position
         MOV     byte ptr [esi+BOARD],0 ; Empty previous position
         TEST    dh,40h                 ; Double move ?
         JNZ     MV40                   ; Yes - jump
         MOV     al,dh                  ; Get captured piece, if any
         AND     al,7
         CMP     al,QUEEN               ; Was it a queen ?
         JZ      skip21                 ; No - return
         RET
skip21:
         MOV     ebx,offset POSQ        ; Addr of saved Queen position
         TEST    dh,80h                 ; Is Queen white ?
         JZ      MV10                   ; Yes - jump
         LEA     ebx,[ebx+1]            ; Increment to black Queen pos
;X p55
MV10:    XOR     al,al                  ; Set saved position to zero
         MOV     byte ptr [ebx],al
         RET                            ; Return
MV15:    LAHF                           ; Change Pawn to a Queen
         OR      dl,4
         SAHF
         JMP     MV5                    ; Jump
MV20:    MOV     ebx,offset POSQ        ; Addr of saved Queen position
MV21:    TEST    dl,80h                 ; Is Queen white ?
         JZ      MV22                   ; Yes - jump
         LEA     ebx,[ebx+1]
MV22:    MOV     al,byte ptr [M2]       ; Get new Queen position
         MOV     byte ptr [ebx],al      ; Save
         JMP     MV5                    ; Jump
MV30:    MOV     ebx,offset POSK        ; Get saved King position
         TEST    dh,40h                 ; Castling ?
         JZ      MV21                   ; No - jump
         LAHF                           ; Set King castled flag
         OR      dl,10h
         SAHF
         JMP     MV21                   ; Jump
MV40:    MOV     ebx,[MLPTRJ]           ; Get move list pointer
         MOV     edx,8                  ; Increment to next move
         LEA     ebx,[ebx+edx]
         JMP     MV1                    ; Jump (2nd part of dbl move)

;X p56
;**********************************************************
; UN-MOVE ROUTINE
;**********************************************************
; FUNCTION: --  To reverse the process of the move routine,
;               thereby restoring the board array to its
;               previous position.
;
; CALLED BY: -- VALMOV
;               EVAL
;               FNDMOV
;               ASCEND
;
; CALLS: --     None
;
; ARGUMENTS: -- None
;**********************************************************
UNMOVE:  MOV     ebx,[MLPTRJ]           ; Load move list pointer
         LEA     ebx,[ebx+1]            ; Increment past link bytes
         LEA     ebx,[ebx+1]
UM1:     MOV     al,byte ptr [ebx]      ; Get "from" position
         MOV     byte ptr [M1],al       ; Save
         LEA     ebx,[ebx+1]            ; Increment pointer
         MOV     al,byte ptr [ebx]      ; Get "to" position
         MOV     byte ptr [M2],al       ; Save
         LEA     ebx,[ebx+1]            ; Increment pointer
         MOV     dh,byte ptr [ebx]      ; Get captured piece/flags
         MOV     esi,[M2]               ; Load "to" pos board index
         MOV     dl,byte ptr [esi+BOARD] ; Get piece moved
         TEST    dh,20h                 ; Was it a Pawn promotion ?
         JNZ     UM15                   ; Yes - jump
         MOV     al,dl                  ; Get piece moved
         AND     al,7                   ; Clear flag bits
         CMP     al,QUEEN               ; Was it a Queen ?
         JZ      UM20                   ; Yes - jump
         CMP     al,KING                ; Was it a King ?
         JZ      UM30                   ; Yes - jump
UM5:     TEST    dh,10h                 ; Is this 1st move for piece ?
         JNZ     UM16                   ; Yes - jump
UM6:     MOV     edi,[M1]               ; Load "from" pos board index
         MOV     byte ptr [edi+BOARD],dl ; Return to previous board pos
         MOV     al,dh                  ; Get captured piece, if any
         AND     al,8FH                 ; Clear flags
         MOV     byte ptr [esi+BOARD],al ; Return to board
         TEST    dh,40h                 ; Was it a double move ?
         JNZ     UM40                   ; Yes - jump
         MOV     al,dh                  ; Get captured piece, if any
         AND     al,7                   ; Clear flag bits
         CMP     al,QUEEN               ; Was it a Queen ?
         JZ      skip22                 ; No - return
         RET
skip22:
;X p57
         MOV     ebx,offset POSQ        ; Address of saved Queen pos
         TEST    dh,80h                 ; Is Queen white ?
         JZ      UM10                   ; Yes - jump
         LEA     ebx,[ebx+1]            ; Increment to black Queen pos
UM10:    MOV     al,byte ptr [M2]       ; Queen's previous position
         MOV     byte ptr [ebx],al      ; Save
         RET                            ; Return
UM15:    LAHF                           ; Restore Queen to Pawn
         AND     dl,0fbh
         SAHF
         JMP     UM5                    ; Jump
UM16:    LAHF                           ; Clear piece moved flag
         AND     dl,0f7h
         SAHF
         JMP     UM6                    ; Jump
UM20:    MOV     ebx,offset POSQ        ; Addr of saved Queen position
UM21:    TEST    dl,80h                 ; Is Queen white ?
         JZ      UM22                   ; Yes - jump
         LEA     ebx,[ebx+1]            ; Increment to black Queen pos
UM22:    MOV     al,byte ptr [M1]       ; Get previous position
         MOV     byte ptr [ebx],al      ; Save
         JMP     UM5                    ; Jump
UM30:    MOV     ebx,offset POSK        ; Address of saved King pos
         TEST    dh,40h                 ; Was it a castle ?
         JZ      UM21                   ; No - jump
         LAHF                           ; Clear castled flag
         AND     dl,0efh
         SAHF
         JMP     UM21                   ; Jump
UM40:    MOV     ebx,[MLPTRJ]           ; Load move list pointer
         MOV     edx,8                  ; Increment to next move
         LEA     ebx,[ebx+edx]
         JMP     UM1                    ; Jump (2nd part of dbl move)

;X p58
;***********************************************************
; SORT ROUTINE
;***********************************************************
; FUNCTION: --  To sort the move list in order of
;               increasing move value scores.
;
; CALLED BY: -- FNDMOV
;
; CALLS: --     EVAL
;
; ARGUMENTS: -- None
;***********************************************************
SORTM:   MOV     ecx,[MLPTRI]           ; Move list begin pointer
         MOV     edx,0                  ; Initialize working pointers
SR5:    MOV     ebx,ecx
        MOV     ecx,dword ptr [ebx]     ; Link to next move
        MOV     dword ptr [ebx],edx     ; Store to link in list
        CMP     ecx,0                   ; End of list ?
         JNZ     skip23                 ; Yes - return
         RET
skip23:
SR10:    MOV     [MLPTRJ],ecx           ; Save list pointer
         CALL    EVAL                   ; Evaluate move
         MOV     ebx,[MLPTRI]           ; Begining of move list
         MOV     ecx,[MLPTRJ]           ; Restore list pointer
SR15:   MOV     edx,dword ptr [ebx]     ; Next move for compare
        CMP     edx,0                   ; At end of list ?
         JZ      SR25                   ; Yes - jump
         PUSH    edx                    ; Transfer move pointer
         POP     esi
         MOV     al,byte ptr [VALM]     ; Get new move value
         CMP     al,byte ptr [esi+MLVAL] ; Less than list value ?
         JNC     SR30                   ; No - jump
SR25:   MOV     dword ptr [ebx],ecx ; Link new move into list
         JMP     SR5                    ; Jump
SR30:    XCHG    ebx,edx                ; Swap pointers
         JMP     SR15                   ; Jump

;X p59
;**********************************************************
; EVALUATION ROUTINE
;**********************************************************
; FUNCTION: --  To evaluate a given move in the move list.
;               It first makes the move on the board, then ii
;               the move is legal, it evaluates it, and then
;               restores the boaard position.
;
; CALLED BY: -- SORT
;
; CALLS: --     MOVE
;               INCHK
;               PINFND
;               POINTS
;               UNMOV
;
; ARGUMENTS: -- None
;**********************************************************
EVAL:    CALL    MOVE                   ; Make move on the board array
         CALL    INCHK                  ; Determine if move is legal
         AND     al,al                  ; Legal move ?
         JZ      EV5                    ; Yes - jump
         XOR     al,al                  ; Score of zero
         MOV     byte ptr [VALM],al     ; For illegal move
         JMP     EV10                   ; Jump
EV5:     CALL    PINFND                 ; Compile pinned list
         CALL    POINTS                 ; Assign points to move
EV10:    CALL    UNMOVE                 ; Restore board array
         RET                            ; Return

;X p60
;**********************************************************
; FIND MOVE ROUTINE
;**********************************************************
; FUNCTION: --  To determine the computer's best move by
;               performing a depth first tree search using
;               the techniques of alpha-beta pruning.
;
; CALLED BY: -- CPTRMV
;
; CALLS: --     PINFND
;               POINTS
;               GENMOV
;               SORTM
;               ASCEND
;               UNMOV
;
; ARGUMENTS: -- None
;**********************************************************
FNDMOV:  MOV     al,byte ptr [MOVENO]   ; Currnet move number
         CMP     al,1                   ; First move ?
         JNZ     skip24                 ; Yes - execute book opening
         CALL    BOOK
skip24:
         XOR     al,al                  ; Initialize ply number to zer
         MOV     byte ptr [NPLY],al
         MOV     ebx,0                  ; Initialize best move to zero
         MOV     [BESTM],ebx
         MOV     ebx,offset MLIST       ; Initialize ply list pointers
         MOV     [MLNXT],ebx
         MOV     ebx,offset PLYIX-2
         MOV     [MLPTRI],ebx
         MOV     al,byte ptr [KOLOR]    ; Initialize color
         MOV     byte ptr [COLOR],al
         MOV     ebx,offset SCORE       ; Initialize score index
         MOV     [SCRIX],ebx
         MOV     al,byte ptr [PLYMAX]   ; Get max ply number
         ADD     al,2                   ; Add 2
         MOV     ch,al                  ; Save as counter
         XOR     al,al                  ; Zero out score table
back05:  MOV     byte ptr [ebx],al
         LEA     ebx,[ebx+1]
         LAHF
         DEC ch
         JNZ     back05
         SAHF
         MOV     byte ptr [BC0],al      ; Zero ply 0 board control
         MOV     byte ptr [MV0],al      ; Zero ply 0 material
         CALL    PINFND                 ; Complie pin list
         CALL    POINTS                 ; Evaluate board at ply 0
         MOV     al,byte ptr [BRDC]     ; Get board control points
         MOV     byte ptr [BC0],al      ; Save
         MOV     al,byte ptr [MTRL]     ; Get material count
         MOV     byte ptr [MV0],al      ; Save
FM5:     MOV     ebx,offset NPLY        ; Address of ply counter
         INC     byte ptr [ebx]         ; Increment ply count
;X p61
         XOR     al,al                  ; Initialize mate flag
         MOV     byte ptr [MATEF],al
         CALL    GENMOV                 ; Generate list of moves
         MOV     al,byte ptr [NPLY]     ; Current ply counter
         MOV     ebx,offset PLYMAX      ; Address of maximum ply number
         CMP     al,byte ptr [ebx]      ; At max ply ?
         JNC     skip25                 ; No - call sort
         CALL    SORTM
skip25:
         MOV     ebx,[MLPTRI]           ; Load ply index pointer
         MOV     [MLPTRJ],ebx           ; Save as last move pointer
FM15:    MOV     ebx,[MLPTRJ]           ; Load last move pointer
         MOV     dl,byte ptr [ebx]      ; Get next move pointer
         LEA     ebx,[ebx+1]
         MOV     dh,byte ptr [ebx]
         MOV     al,dh
         AND     al,al                  ; End of move list ?
         JZ      FM25                   ; Yes - jump
         MOV     [MLPTRJ],edx           ; Save current move pointer
         MOV     ebx,[MLPTRI]           ; Save in ply pointer list
         MOV     byte ptr [ebx],dl
         LEA     ebx,[ebx+1]
         MOV     byte ptr [ebx],dh
         MOV     al,byte ptr [NPLY]     ; Current ply counter
         MOV     ebx,offset PLYMAX      ; Maximum ply number ?
         CMP     al,byte ptr [ebx]      ; Compare
         JC      FM18                   ; Jump if not max
         CALL    MOVE                   ; Execute move on board array
         CALL    INCHK                  ; Check for legal move
         AND     al,al                  ; Is move legal
         JZ      rel017                 ; Yes - jump
         CALL    UNMOVE                 ; Restore board position
         JMP     FM15                   ; Jump
rel017:  MOV     al,byte ptr [NPLY]     ; Get ply counter
         MOV     ebx,offset PLYMAX      ; Max ply number
         CMP     al,byte ptr [ebx]      ; Beyond max ply ?
         JNZ     FM35                   ; Yes - jump
         MOV     al,byte ptr [COLOR]    ; Get current color
         XOR     al,80H                 ; Get opposite color
         CALL    INCHK1                 ; Determine if King is in check
         AND     al,al                  ; In check ?
         JZ      FM35                   ; No - jump
         JMP     FM19                   ; Jump (One more ply for check)
FM18:    MOV     esi,[MLPTRJ]           ; Load move pointer
         MOV     al,byte ptr [esi+MLVAL] ; Get move score
         AND     al,al                  ; Is it zero (illegal move) ?
         JZ      FM15                   ; Yes - jump
         CALL    MOVE                   ; Execute move on board array
FM19:    MOV     ebx,offset COLOR       ; Toggle color
         MOV     al,80H
         XOR     al,byte ptr [ebx]
         MOV     byte ptr [ebx],al      ; Save new color
;X p62
         TEST    al,80h                 ; Is it white ?
         JNZ     rel018                 ; No - jump
         MOV     ebx,offset MOVENO      ; Increment move number
         INC     byte ptr [ebx]
rel018:  MOV     ebx,[SCRIX]            ; Load score table pointer
         MOV     al,byte ptr [ebx]      ; Get score two plys above
         LEA     ebx,[ebx+1]            ; Increment to current ply
         LEA     ebx,[ebx+1]
         MOV     byte ptr [ebx],al      ; Save score as initial value
         LEA     ebx,[ebx-1]            ; Decrement pointer
         MOV     [SCRIX],ebx            ; Save it
         JMP     FM5                    ; Jump
FM25:    MOV     al,byte ptr [MATEF]    ; Get mate flag
         AND     al,al                  ; Checkmate or stalemate ?
         JNZ     FM30                   ; No - jump
         MOV     al,byte ptr [CKFLG]    ; Get check flag
         AND     al,al                  ; Was King in check ?
         MOV     al,80H                 ; Pre-set stalemate score
         JZ      FM36                   ; No - jump (stalemate)
         MOV     al,byte ptr [MOVENO]   ; Get move number
         MOV     byte ptr [PMATE],al    ; Save
         MOV     al,0FFH                ; Pre-set checkmate score
         JMP     FM36                   ; Jump
FM30:    MOV     al,byte ptr [NPLY]     ; Get ply counter
         CMP     al,1                   ; At top of tree ?
         JNZ     skip26                 ; Yes - return
         RET
skip26:
         CALL    ASCEND                 ; Ascend one ply in tree
         MOV     ebx,[SCRIX]            ; Load score table pointer
         LEA     ebx,[ebx+1]            ; Increment to current ply
         LEA     ebx,[ebx+1]
         MOV     al,byte ptr [ebx]      ; Get score
         LEA     ebx,[ebx-1]            ; Restore pointer
         LEA     ebx,[ebx-1]
         JMP     FM37                   ; Jump
FM35:    CALL    PINFND                 ; Compile pin list
         CALL    POINTS                 ; Evaluate move
         CALL    UNMOVE                 ; Restore board position
         MOV     al,byte ptr [VALM]     ; Get value of move
FM36:    MOV     ebx,offset MATEF       ; Set mate flag
         LAHF
         OR      byte ptr [ebx],1
         SAHF
         MOV     ebx,[SCRIX]            ; Load score table pointer
FM37:    CMP     al,byte ptr [ebx]      ; Compare to score 2 ply above
         JC      FM40                   ; Jump if less
         JZ      FM40                   ; Jump if equal
         NEG     al                     ; Negate score
         LEA     ebx,[ebx+1]            ; Incr score table pointer
         CMP     al,byte ptr [ebx]      ; Compare to score 1 ply above
         JC      FM15                   ; Jump if less than
         JZ      FM15                   ; Jump if equal
;X p63
         MOV     byte ptr [ebx],al      ; Save as new score 1 ply above
         MOV     al,byte ptr [NPLY]     ; Get current ply counter
         CMP     al,1                   ; At top of tree ?
         JNZ     FM15                   ; No - jump
         MOV     ebx,[MLPTRJ]           ; Load current move pointer
         MOV     [BESTM],ebx            ; Save as best move.pointer
         MOV     al,byte ptr [SCORE+1]  ; Get best move score
         CMP     al,0FFH                ; Was it a checkmate ?
         JNZ     FM15                   ; No - jump
         MOV     ebx,offset PLYMAX      ; Get maximum ply number
         DEC     byte ptr [ebx]         ; Subtract 2
         DEC     byte ptr [ebx]
         MOV     al,byte ptr [KOLOR]    ; Get computer's color
         TEST    al,80h                 ; Is it white ?
         JNZ     skip27                 ; Yes - return
         RET
skip27:
         MOV     ebx,offset PMATE       ; Checkmate move number
         DEC     byte ptr [ebx]         ; Decrement
         RET                            ; Return
FM40:    CALL    ASCEND                 ; Ascend one ply in tree
         JMP     FM15                   ; Jump

;X p64
;**********************************************************
; ASCEND TREE ROUTINE
;**********************************************************
; FUNCTION: --  To adjust all necessary parameters to
;               ascend one ply in the tree.
;
; CALLED BY: -- FNDMOV
;
; CALLS: --     UNMOV
;
; ARGUMENTS: -- None
;**********************************************************
ASCEND:  MOV     ebx,offset COLOR       ; Toggle color
         MOV     al,80H
         XOR     al,byte ptr [ebx]
         MOV     byte ptr [ebx],al      ; Save new color
         TEST    al,80h                 ; Is it white ?
         JZ      rel019                 ; Yes - jump
         MOV     ebx,offset MOVENO      ; Decrement move number
         DEC     byte ptr [ebx]
rel019:  MOV     ebx,[SCRIX]            ; Load score table index
         LEA     ebx,[ebx-1]            ; Decrement
         MOV     [SCRIX],ebx            ; Save
         MOV     ebx,offset NPLY        ; Decrement ply counter
         DEC     byte ptr [ebx]
         MOV     ebx,[MLPTRI]           ; Load ply list pointer
         LEA     ebx,[ebx-1]            ; Load pointer to move list to
         MOV     dh,byte ptr [ebx]
         LEA     ebx,[ebx-1]
         MOV     dl,byte ptr [ebx]
         MOV     [MLNXT],edx            ; Update move list avail ptr
         LEA     ebx,[ebx-1]            ; Get ptr to next move to undo
         MOV     dh,byte ptr [ebx]
         LEA     ebx,[ebx-1]
         MOV     dl,byte ptr [ebx]
         MOV     [MLPTRI],ebx           ; Save new ply list pointer
         MOV     [MLPTRJ],edx           ; Save next move pointer
         CALL    UNMOVE                 ; Restore board to previous pl
         RET                            ; Return

;X p65
;**********************************************************
; ONE MOVE BOOK OPENING
; *****************************************x***************
; FUNCTION: --  To provide an opening book of a single
;               move.
;
; CALLED BY: -- FNDMOV
;
; CALLS: --     None
;
; ARGUMENTS: -- None
;**********************************************************
BOOK:    POP     eax                    ; Abort return to FNDMOV
         sahf
         MOV     ebx,offset SCORE+1     ; Zero out score
         MOV     byte ptr [ebx],0       ; Zero out score table
         MOV     ebx,offset BMOVES-PTRSIZ ; Init best move ptr to book
         MOV     [BESTM],ebx
         MOV     ebx,offset BESTM       ; Initialize address of pointer
         MOV     al,byte ptr [KOLOR]    ; Get computer's color
         AND     al,al                  ; Is it white ?
         JNZ     BM5                    ; No - jump
         Z80_LDAR                       ; Load refresh reg (random no)
         TEST    al,1                   ; Test random bit
         JNZ     skip28                 ; Return if zero (P-K4)
         RET
skip28:
         INC     byte ptr [ebx]         ; P-Q4
         INC     byte ptr [ebx]
         INC     byte ptr [ebx]
         RET                            ; Return
BM5:     INC     byte ptr [ebx]         ; Increment to black moves
         INC     byte ptr [ebx]
         INC     byte ptr [ebx]
         INC     byte ptr [ebx]
         INC     byte ptr [ebx]
         INC     byte ptr [ebx]
         MOV     esi,[MLPTRJ]           ; Pointer to opponents 1st move
         MOV     al,byte ptr [esi+MLFRP] ; Get "from" position
         CMP     al,22                  ; Is it a Queen Knight move ?
         JZ      BM9                    ; Yes - Jump
         CMP     al,27                  ; Is it a King Knight move ?
         JZ      BM9                    ; Yes - jump
         CMP     al,34                  ; Is it a Queen Pawn ?
         JZ      BM9                    ; Yes - jump
         JNC     skip29                 ; If Queen side Pawn opening -
         RET
skip29:
                                ; return (P-K4)
         CMP     al,35                  ; Is it a King Pawn ?
         JNZ     skip30                 ; Yes - return (P-K4)
         RET
skip30:
BM9:     INC     byte ptr [ebx]         ; (P-Q4)
         INC     byte ptr [ebx]
         INC     byte ptr [ebx]
         RET                            ; Return to CPTRMV

        
;X p66
;**********************************************************
; GRAPHICS DATA BASE
;**********************************************************
; DESCRIPTION:  The Graphics Data Base contains the
;               necessary stored data to produce the piece
;               on the board. Only the center 4 x 4 blocks are
;               stored and only for a Black Piece on a White
;               square. A White piece on a black square is
;               produced by complementing each block, and a
;               piece on its own color square is produced
;               by moving in a kernel of 6 blocks.
;**********************************************************

;X p67
;**********************************************************
; STANDARD MESSAGES
;**********************************************************
;X appended "$" for CP/M C.PRINTSTR call
;X      .ASCII  [^H83]  ; Part of TITLE 3 - Underlines
;X      .ASCII  [^H83]
;X      .ASCII  [^H83]
;X      .ASCII  [^H83]
;X      .ASCII  [^H83]
;X      .ASCII  [^H83]
;X      .ASCII  " "
;X      .ASCII  [^H83]
;X      .ASCII  [^H83]
;X      .ASCII  [^H83]
;X      .ASCII  [^H83]
;X      .ASCII  [^H83]
;X      .ASCII  [^H83]
;X      .ASCII  " " "$"

;X p68
;**********************************************************
; VARIABLES
;**********************************************************
                        ; corner of the square on the board

;**********************************************************
; MACRO DEFINITIONS
;**********************************************************
; All input/output to SARGON is handled in the form of
; macro calls to simplify conversion to alternate systems.
; All of the input/output macros conform to the Jove monitor
; of the Jupiter III computer.
;**********************************************************
;X *** OUTPUT <CR><LF> ***
;X *** CLEAR SCREEN ***
;X *** PRINT ANY LINE (NAME, LENGTH) ***
;X *** PRINT ANY BLOCK (NAME, LENGTH) ***
;X *** EXIT TO MONITOR ***
;X *** Single char input ***
;X *** Single char echo ***

;X p69
;**********************************************************
; MAIN PROGRAM DRIVER
;**********************************************************
; FUNCTION: --  To coordinate the game moves.
;
; CALLED BY: -- None
;
; CALLS: --     INTERR
;               INITBD
;               DSPBRD
;               CPTRMV
;               PLYRMV
;               TBCPCL
;               PGIFND
;
; MACRO CALLS:  CLRSCR
;               CARRET
;               PRTLIN
;               PRTBLK
;
; ARGUMENTS:    None
;**********************************************************
;X p70

;X p71
;*****************************************************************
; INTERROGATION FOR PLY & COLOR
;*****************************************************************
; FUNCTION: --  To query the player for his choice of ply
;               depth and color.
;
; CALLED BY: -- DRIVER
;
; CALLS: --     CHARTR
;
; MACRO CALLS:  PRTLIN
;               CARRET
;
; ARGUMENTS: -- None
;X p72
;*****************************************************************

;X p73
;**********************************************************
; COMPUTER MOVE ROUTINE
;**********************************************************
; FUNCTION: --  To control the search for the computers move
;               and the display of that move on the board
;               and in the move list.
;
; CALLED BY: -- DRIVER
;
; CALLS: --     FNDMOV
;               FCDMAT
;               MOVE
;               EXECMV
;               BITASN
;               INCHK
;
; MACRO CALLS:  PRTBLK
;               CARRET
;
; ARGUMENTS: -- None
;**********************************************************
CPTRMV:  CALL    FNDMOV                 ; Select best move
         MOV     ebx,[BESTM]            ; Move list pointer variable
         MOV     [MLPTRJ],ebx           ; Pointer to move data
         MOV     al,byte ptr [SCORE+1]  ; To check for mates
         CMP     al,1                   ; Mate against computer ?
         JNZ     CP0C                   ; No - jump
         MOV     cl,1                   ; Computer mate flag
         CALL    FCDMAT                 ; Full checkmate ?
CP0C:    CALL    MOVE                   ; Produce move on board array
         CALL    EXECMV                 ; Make move on graphics board
                                ; and return info about it
         MOV     al,ch                  ; Special move flags
         AND     al,al                  ; Special ?
         JNZ     CP10                   ; Yes - jump
         MOV     dh,dl                  ; "To" position of the move
         CALL    BITASN                 ; Convert to Ascii
         MOV     [MVEMSG_2],ebx         ;todo MVEMSG+3        ; Put in move message
         MOV     dh,cl                  ; "From" position of the move
         CALL    BITASN                 ; Convert to Ascii
         MOV     [MVEMSG],ebx           ; Put in move message
         PRTBLK  MVEMSG,5               ; Output text of move
         JMP     CP1C                   ; Jump
CP10:    TEST    ch,2                   ; King side castle ?
         JZ      rel020                 ; No - jump
         PRTBLK  O.O,5                  ; Output "O-O"
         JMP     CP1C                   ; Jump
rel020:  TEST    ch,4                   ; Queen side castle ?
         JZ      rel021                 ; No - jump
;X p74
         PRTBLK  O.O.O,5                ;  Output "O-O-O"
         JMP     CP1C                   ; Jump
rel021:  PRTBLK  P.PEP,5                ; Output "PxPep" - En passant
CP1C:    MOV     al,byte ptr [COLOR]    ; Should computer call check ?
         MOV     ch,al
         XOR     al,80H                 ; Toggle color
         MOV     byte ptr [COLOR],al
         CALL    INCHK                  ; Check for check
         AND     al,al                  ; Is enemy in check ?
         MOV     al,ch                  ; Restore color
         MOV     byte ptr [COLOR],al
         JZ      CP24                   ; No - return
         CARRET                         ; New line
         MOV     al,byte ptr [SCORE+1]  ; Check for player mated
         CMP     al,0FFH                ; Forced mate ?
         JZ      skip31                 ; No - Tab to computer column
         CALL    TBCPMV
skip31:
         PRTBLK  CKMSG,5                ; Output "check"
         MOV     ebx,offset LINECT      ; Address of screen line count
         INC     byte ptr [ebx]         ; Increment for message
CP24:    MOV     al,byte ptr [SCORE+1]  ; Check again for mates
         CMP     al,0FFH                ; Player mated ?
         JZ      skip32                 ; No - return
         RET
skip32:
         MOV     cl,0                   ; Set player mate flag
         CALL    FCDMAT                 ; Full checkmate ?
         RET                            ; Return


;X p75
;**********************************************************
; FORCED MATE HANDLING
;**********************************************************
; FUNCTION: --  To examine situations where there exits
;               a forced mate and determine whether or
;               not the current move is checkmate. If it is,
;               a losing player is offered another game,
;               while a loss for the computer signals the
;               King to tip over in resignation.
;
; CALLED BY: -- CPTRMV
;
; CALLS: --     MATED
;               CHARTR
;               TBPLMV
;
; ARGUMENTS: -- The only value passed in a register is the
;               flag which tells FCDMAT whether the computer
;               or the player is mated.
;**********************************************************

;X p76
;*****************************************************************
; TAB TO PLAYERS COLUMN
;*****************************************************************
; FUNCTION: --  To space over in the move listing to the
;               column in which the players moves are being
;               recorded. This routine also reprints the
;               move number.
;
; CALLED BY: -- PLYRMV
;
; CALLS: --     None
;
; MACRO CALLS:  PRTBLK
;
; ARGUMENTS: -- None
;*****************************************************************

;*****************************************************************
; TAB TO COMPUTERS COLUMN
;*****************************************************************
; FUNCTION: --  To space over in the move listing to the
;               column in which the computers moves are
;               being recorded. This routine also reprints
;               the move number.
;
; CALLED BY: -- DRIVER
;               CPTRMV
;
; CALLS: --     None
;
; MACRO CALLS:  PRTBLK
;
; ARGUMENTS: -- None
;*****************************************************************

;X p77
;*****************************************************************
; TAB TO PLAYERS COLUMN W/0 MOVE NO.
;*****************************************************************
; FUNCTION: --  Like TBPLCL, except that the move number
;               is not reprinted.
;
; CALLED BY: -- FCDMAT
;***************************************************************

;*****************************************************************
; TAB TO COMPUTERS COLUMN W/O MOVE NO.
;*****************************************************************
; FUNCTION: --  Like TBCPCL, except that the move number
;               is not reprinted.
;
; CALLED BY: -- CPTRMV
;*****************************************************************


;X p78
;*****************************************************************
; BOARD INDEX TO ASCII SQUARE NAME
;*****************************************************************
; FUNCTION: --  To translate a hexadecimal index in the
;               board array into an ascii description
;               of the square in algebraic chess notation.
;
; CALLED BY: -- CPTRMV
;
; CALLS: --     DIVIDE
;
; ARGUMENTS: -- Board index input in register D and the Ascii
;               square name is output in register pair HL.
;*****************************************************************
BITASN:  SUB     al,al                  ; Get ready for division
         MOV     dl,10
         CALL    DIVIDE                 ; Divide
         DEC     dh                     ; Get rank on 1-8 basis
         ADD     al,60H                 ; Convert file to Ascii (a-h)
         MOV     bl,al                  ; Save
         MOV     al,dh                  ; Rank
         ADD     al,30H                 ; Convert rank to Ascii (1-8)
         MOV     bh,al                  ; Save
         RET                            ; Return

;X p79
;*****************************************************************
; PLAYERS MOVE ANALYSIS
;*****************************************************************
; FUNCTION: --  To accept and validate the players move
;               and produce it on the graphics board. Also
;               allows player to resign the game by
;               entering a control-R.
;
; CALLED BY: -- DRIVER
;
; CALLS: --     CHARTR
;               ASNTBI
;               VALMOV
;               EXECMV
;               PGIFND
;               TBPLCL
;
; ARGUMENTS: -- None
;*****************************************************************
        

;X p80
;**********************************************************
; ASCII SQUARE NAME TO BOARD INDEX
;**********************************************************
; FUNCTION: --  To convert an algebraic square name in
;               Ascii to a hexadecimal board index.
;               This routine also checks the input for
;               validity.
;
; CALLED BY: -- PLYRMV
;
; CALLS: --     MLTPLY
;
; ARGUMENTS: -- Accepts the square name in register pair HL and
;               outputs the board index in register A. Register
;               B = 0 if ok. Register B = Register A if invalid.
;**********************************************************
ASNTBI:  MOV     al,bl                  ; Ascii rank (1 - 8)
         SUB     al,30H                 ; Rank 1 - 8
         CMP     al,1                   ; Check lower bound
         JS      AT04                   ; Jump if invalid
         CMP     al,9                   ; Check upper bound
         JNC     AT04                   ; Jump if invalid
         INC     al                     ; Rank 2 - 9
         MOV     dh,al                  ; Ready for multiplication
         MOV     dl,10
         CALL    MLTPLY                 ; Multiply
         MOV     al,bh                  ; Ascii file letter (a - h)
         SUB     al,40H                 ; File 1 - 8
         CMP     al,1                   ; Check lower bound
         JS      AT04                   ; Jump if invalid
         CMP     al,9                   ; Check upper bound
         JNC     AT04                   ; Jump if invalid
         ADD     al,dh                  ; File+Rank(20-90)=Board index
         MOV     ch,0                   ; Ok flag
         RET                            ; Return
AT04:    MOV     ch,al                  ; Invalid flag
         RET                            ; Return

;X p81
;*************************************************************
; VALIDATE MOVE SUBROUTINE
;*************************************************************
; FUNCTION: --  To check a players move for validity.
;
; CALLED BY: -- PLYRMV
;
; CALLS: --     GENMOV
;               MOVE
;               INCHK
;               UNMOVE
;
; ARGUMENTS: -- Returns flag in register A, 0 for valid and 1 for
;               invalid move.
;*************************************************************
VALMOV:  MOV     ebx,[MLPTRJ]           ; Save last move pointer
         PUSH    ebx                    ; Save register
         MOV     al,byte ptr [KOLOR]    ; Computers color
         XOR     al,80H                 ; Toggle color
         MOV     byte ptr [COLOR],al    ; Store
         MOV     ebx,offset PLYIX-2     ; Load move list index
         MOV     [MLPTRI],ebx
         MOV     ebx,offset MLIST+1024  ; Next available list pointer
         MOV     [MLNXT],ebx
         CALL    GENMOV                 ; Generate opponents moves
         MOV     esi,offset MLIST+1024  ; Index to start of moves
VA5:     MOV     al,byte ptr [MVEMSG]   ; "From" position
         CMP     al,byte ptr [esi+MLFRP] ; Is it in list ?
         JNZ     VA6                    ; No - jump
         MOV     al,byte ptr [MVEMSG+1] ; "To" position
         CMP     al,byte ptr [esi+MLTOP] ; Is it in list ?
         JZ      VA7                    ; Yes - jump
VA6:     MOV     dl,byte ptr [esi+MLPTR] ; Pointer to next list move
         MOV     dh,byte ptr [esi+MLPTR+1]
         XOR     al,al                  ; At end of list ?
         CMP     al,dh
         JZ      VA10                   ; Yes - jump
         PUSH    edx                    ; Move to X register
         POP     esi
         JMP     VA5                    ; Jump
VA7:     MOV     [MLPTRJ],esi           ; Save opponents move pointer
         CALL    MOVE                   ; Make move on board array
         CALL    INCHK                  ; Was it a legal move ?
         AND     al,al
         JNZ     VA9                    ; No - jump
VA8:     POP     ebx                    ; Restore saved register
         RET                            ; Return
VA9:     CALL    UNMOVE                 ; Un-do move on board array
VA10:    MOV     al,1                   ; Set flag for invalid move
         POP     ebx                    ; Restore saved register
         MOV     [MLPTRJ],ebx           ; Save move pointer
         RET                            ; Return

;X p82
;*************************************************************
; ACCEPT INPUT CHARACTER
;*************************************************************
; FUNCTION: --  Accepts a single character input from the
;               console keyboard and places it in the A
;               register. The character is also echoed on
;               the video screen, unless it is a carriage
;               return, line feed, or backspace. Lower case
;               alphabetic characters are folded to upper case.
;
; CALLED BY: -- DRIVER
;               INTERR
;               PLYRMV
;               ANALYS
;
; CALLS: --     None
;
; ARGUMENTS: -- Character input is output in register A.
;
; NOTES: --     This routine contains a reference to a
;               monitor function of the Jove monitor, there-
;               for the first few lines of this routine are
;               system dependent.
;*************************************************************

;X p83
;**********************************************************
; NEW PAGE IF NEEDED
;**********************************************************
; FUNCTION: --  To clear move list output when the column
;               has been filled.
;
; CALLED BY: -- DRIVER
;               PLYRMV
;               CPTRMV
;
; CALLS: --     DSPBRD
;
; ARGUMENTS: -- Returns a 1 in the A register if a new
;               page was turned.
;**********************************************************

;X p84
;*************************************************************
; DISPLAY MATED KING
;*************************************************************
; FUNCTION: --  To tip over the computers King when
;               mated.
;
; CALLED BY: -- FCDMAT
;
; CALLS: --     CONVRT
;               BLNKER
;               INSPCE (Abnormal Call to IP04)
;
; ARGUMENTS: -- None
;*************************************************************

;X p85
;**********************************************************
; SET UP POSITION FOR ANALYSIS
;**********************************************************
; FUNCTION: --  To enable user to set up any position
;               for analysis, or to continue to play
;               the game. The routine blinks the board
;               squares in turn and the user has the option
;               of leaving the contents unchanged by a
;               carriage return, emptying the square by a 0,
;               or inputting a piece of his chosing. To
;               enter a piece, type in piece-code,color-code,
;               moved-code.
;
;               Piece-code is a letter indicating the
;               desired piece:
;                       K -     King
;                       Q -     Queen
;                       R -     Rook
;                       B -     Bishop
;                       N -     Knight
;                       P -     Pawn
;
;               Color code is a letter, W for white, or B for
;               black.
;
;               Moved-code is a number. 0 indicates the piece has never
;               moved. 1 indicates the piece has moved.
;
;               A backspace will back up in the sequence of blinked
;               squares. An Escape will terminate the blink cycle and
;               verify that the position is correct, then procede
;               with game initialization.
;
; CALLED BY: -- DRIVER
;
; CALLS: --     CHARTR
;               DPSBRD
;               BLNKER
;               ROYALT
;               PLYRMV
;               CPTRMV
;
; MACRO CALLS:  PRTLIN
;               EXIT
;               CLRSCR
;               PRTBLK
;               CARRET
;
; ARGUMENTS: -- None
;**********************************************************
;X p86
;X p87

        
;X p88
;*************************************************************
; UPDATE POSITIONS OF ROYALTY
;*************************************************************
; FUNCTION: --  To update the positions of the Kings
;               and Queen after a change of board position
;               in ANALYS.
;
; CALLED BY: -- ANALYS
;
; CALLS: --     None
;
; ARGUMENTS: -- None
;*************************************************************
ROYALT:  MOV     ebx,offset POSK        ; Start of Royalty array
         MOV     ch,4                   ; Clear all four positions
back06:  MOV     byte ptr [ebx],0
         LEA     ebx,[ebx+1]
         LAHF
         DEC ch
         JNZ     back06
         SAHF
         MOV     al,21                  ; First board position
RY04:    MOV     byte ptr [M1],al       ; Set up board index
         MOV     ebx,offset POSK        ; Address of King position
         MOV     esi,[M1]
         MOV     al,byte ptr [esi+BOARD] ; Fetch board contents
         TEST    al,80h                 ; Test color bit
         JZ      rel023                 ; Jump if white
         LEA     ebx,[ebx+1]            ; Offset for black
rel023:  AND     al,7                   ; Delete flags, leave piece
         CMP     al,KING                ; King ?
         JZ      RY08                   ; Yes - jump
         CMP     al,QUEEN               ; Queen ?
         JNZ     RY0C                   ; No - jump
         LEA     ebx,[ebx+1]            ; Queen position
         LEA     ebx,[ebx+1]            ; Plus offset
RY08:    MOV     al,byte ptr [M1]       ; Index
         MOV     byte ptr [ebx],al      ; Save
RY0C:    MOV     al,byte ptr [M1]       ; Current position
         INC     al                     ; Next position
         CMP     al,99                  ; Done.?
         JNZ     RY04                   ; No - jump
         RET                            ; Return

;X p89
;*************************************************************
; SET UP EMPTY BOARD
;*************************************************************
; FUNCTION: --  Diplay graphics board and pieces.
;
; CALLED BY: -- DRIVER
;               ANALYS
;               PGIFND
;
; CALLS: --     CONVRT
;               INSPCE
;
; ARGUMENTS: -- None
;
; NOTES: --     This routine makes use of several fixed
;               addresses in the video storage area of
;               the Jupiter III computer, and is therefor
;               system dependent. Each such reference will
;               be marked.
;*************************************************************
                                ; address
;X p90

;X p91
;**********************************************************
; INSERT PIECE SUBROUTINE
;**********************************************************
; FUNCTION: --  This subroutine places a piece onto a
;               given square on the video board. The piece
;               inserted is that stored in the board array
;               for that square.
;
; CALLED BY: -- DPSPRD
;               MATED
;
; CALLS: --     MLTPLY
;
; ARGUMENTS: -- Norm address for the square in register
;               pair HL.
;**********************************************************
;X p92


;X p93
;**********************************************************
; BOARD INDEX TO NORM ADDRESS SUBR.
;**********************************************************
; FUNCTION: --  Converts a hexadecimal board index into
;               a Norm address for the square.
;
; CALLED BY: -- DSPBRD
;               INSPCE
;               ANALYS
;               MATED
;
; CALLS: --     DIVIDE
;               MLTPLY
;
;ARGUMENTS: --  Returns the Norm address in register pair
;               HL.
;**********************************************************
CONVRT:  PUSH    ecx                    ; Save registers
         PUSH    edx
         lahf
         PUSH    eax
         MOV     al,byte ptr [BRDPOS]   ; Get board index
         MOV     dh,al                  ; Set up dividend
         SUB     al,al
         MOV     dl,10                  ; Divisor
         CALL    DIVIDE                 ; Index into rank and file
                        ; file (1-8) & rank (2-9)
         DEC     dh                     ; For rank (1-8)
         DEC     al                     ; For file (0-7)
         MOV     cl,dh                  ; Save
         MOV     dh,6                   ; Multiplier
         MOV     dl,al                  ; File number is multiplicand
         CALL    MLTPLY                 ; Giving file displacement
         MOV     al,dh                  ; Save
         ADD     al,10H                 ; File norm address
         MOV     bl,al                  ; Low order address byte
         MOV     al,8                   ; Rank adjust
         SUB     al,cl                  ; Rank displacement
         ADD     al,0C0H                ; Rank Norm address
         MOV     bh,al                  ; High order addres byte
         POP     eax                    ; Restore registers
         sahf
         POP     edx
         POP     ecx
         RET                            ; Return

;X p94
;**********************************************************
; POSITIVE INTEGER DIVISION
;   inputs hi=A lo=D, divide by E   (al, dh) divide by dl
;   output D (dh) remainder in A (al)
;**********************************************************
DIVIDE:  PUSH    ecx
         MOV     ch,8
DD04:    SHL     dh,1
         RCL     al,1
         SUB     al,dl
         JS      rel027
         INC     dh
         JMP     rel024
rel027:  ADD     al,dl
rel024:  LAHF
         DEC ch
         JNZ     DD04
         SAHF
         POP     ecx
         RET

;**********************************************************
; POSITIVE INTEGER MULTIPLICATION
;   inputs D, E         (dh, dl)
;   output hi=A lo=D    (al, dh)
;**********************************************************
MLTPLY:  PUSH    ecx
         SUB     al,al
         MOV     ch,8
ML04:    TEST    dh,1
         JZ      rel025
         ADD     al,dl
rel025:  SAR     al,1
         RCR     dh,1
         LAHF
         DEC ch
         JNZ     ML04
         SAHF
         POP     ecx
         RET

;X p95
;**********************************************************
; SQUARE BLINKER
;**********************************************************
;
; FUNCTION: --  To blink the graphics board square to signal
;               a piece's intention to move, or to high-
;               light the square as being alterable
;               in ANALYS.
;
; CALLED BY: -- MAKEMV
;               ANALYS
;               MATED
;
; CALLS: --     None
;
; ARGUMENTS: -- Norm address of desired square passed in register
;               pair HL. Number of times to blink passed in
;               register B.
;**********************************************************
;X p96


;**********************************************************
; EXECUTE MOVE SUBROUTINE
;**********************************************************
; FUNCTION: --  This routine is the control routine for
;               MAKEMV. It checks for double moves and
;               sees that they are properly handled. It
;               sets flags in the B register for double
;               moves:
;                       En Passant -- Bit 0
;                       O-O     -- Bit 1
;                       O-O-O   -- Bit 2
;
; CALLED BY: -- PLYRMV
;               CPTRMV
;
; CALLS: --     MAKEMV
;
; ARGUMENTS: -- Flags set in the B register as described
;               above.
;**********************************************************
EXECMV:  PUSH    esi                    ; Save registers
         lahf
         PUSH    eax
         MOV     esi,[MLPTRJ]           ; Index into move list
         MOV     cl,byte ptr [esi+MLFRP] ; Move list "from" position
         MOV     dl,byte ptr [esi+MLTOP] ; Move list "to" position
         CALL    MAKEMV                 ; Produce move
         MOV     dh,byte ptr [esi+MLFLG] ; Move list flags
         MOV     ch,0
         TEST    dh,40h                 ; Double move ?
         JZ      EX14                   ; No - jump
         MOV     edx,MOVSIZ             ; Move list entry width
         LEA     esi,[esi+edx]          ; Increment MLPTRJ
         MOV     cl,byte ptr [esi+MLFRP] ; Second "from" position
         MOV     dl,byte ptr [esi+MLTOP] ; Second "to" position
         MOV     al,dl                  ; Get "to" position
         CMP     al,cl                  ; Same as "from" position ?
         JNZ     EX04                   ; No - jump
         INC     ch                     ; Set en passant flag
         JMP     EX10                   ; Jump
EX04:    CMP     al,1AH                 ; White O-O ?
         JNZ     EX08                   ; No - jump
         LAHF                           ; Set O-O flag
         OR      ch,2
         SAHF
         JMP     EX10                   ; Jump
EX08:    CMP     al,60H                 ; Black 0-0 ?
         JNZ     EX0C                   ; No - jump
         LAHF                           ; Set 0-0 flag
         OR      ch,2
         SAHF
         JMP     EX10                   ; Jump
EX0C:    LAHF                           ; Set 0-0-0 flag
         OR      ch,4
         SAHF
EX10:    CALL    MAKEMV                 ; Make 2nd move on board
EX14:    POP     eax                    ; Restore registers
         sahf
         POP     esi
         RET                            ; Return

;X p98
;**********************************************************
; MAKE MOVE SUBROUTINE
;**********************************************************
; FUNDTION: --  Moves the piece on the board when a move
;               is made. It blinks both the "from" and
;               "to" positions to give notice of the move.
;
; CALLED BY: -- EXECMV
;
; CALLS: --     CONVRT
;               BLNKER
;               INSPCE
;
; ARGUMENTS: -- The "from" position is passed in register
;               C, and the "to" position in register E.
;**********************************************************
MAKEMV: RET             ; Stubbed out for now

SARGON  ENDP
;
; SHIM from C code
;
PUBLIC	_shim_function
_shim_function PROC
    push    ebp
    mov     ebp,esp
    push    esi
    push    edi
    mov     ebx,[ebp+8]
    mov     dword ptr [ebx],offset BOARDA



;   SUB     A               ; Code of White is zero
    sub al,al
;   STA     COLOR           ; White always moves first
    mov byte ptr [COLOR],al
;   STA     KOLOR           ; Bring in computer's color
    mov byte ptr [KOLOR],al
;   CALL    INTERR          ; Players color/search depth
;   call    INTERR
    mov byte ptr [PLYMAX],1
    mov al,0
;   CALL    INITBD          ; Initialize board array
    call    SARGON
;   MVI     A,1             ; Move number is 1 at at start
    mov al,1
;   STA     MOVENO          ; Save
    mov byte ptr [MOVENO],al
;   CALL    CPTRMV          ; Make and write computers move
    mov al,1
    call    SARGON
    pop     edi
    pop     esi
    pop     ebp
	ret
_shim_function ENDP

_TEXT    ENDS
END

        
