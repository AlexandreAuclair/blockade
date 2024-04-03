.INCLUDE "header.asm"

.SEGMENT "ZEROPAGE"

.INCLUDE "registers.inc"

STARTINGYP1 = $06
STARTINGXP1 = $07
STARTINGYP2 = $17
STARTINGXP2 = $18

OAMWIDTHSCREEN =  $20
OAMHEIGHTSCREEN = $1E
; my position in the background equals WIDTH * posY + posX

STATEGAMEOVER  = $00  ; displaying game over screen
STATEDEMO      = $01  ; displaying demo
STATEPLAYING   = $02  ; play game

;variable
pointerLo:    .res 1   ; pointer variables are declared in RAM
pointerHi:    .res 1   ; low byte first, high byte immediately after
tempHalf1btn: .res 1
tempHalf2btn: .res 1
btnInstant:   .res 2
buttons:      .res 2
posXP1:       .res 1
posXP2:       .res 1
posYP1:       .res 1
posYP2:       .res 1
direction:    .res 2 ; 0 = no move 1 = right 2 = left 4 = down 8 = up 
counter:      .res 1
playersprite: .res 2
posbg1:       .res 2 ; first Y second X
posbg2:       .res 2 ; first Y second X
oldposbg1:    .res 2 ; first Y second X
oldposbg2:    .res 2 ; first Y second X
oldDirection: .res 2 ; 0 = no move 1 = right 2 = left 4 = down 8 = up 
gamestate:    .res 1
IsUpdating:   .res 1
score:        .res 2 ; first score1 second score2
playingstate: .res 1
swap:         .res 1
winner:       .res 1 ; 1 = player 1 win, 2 = player 2 win
timer:        .res 1
timerDemo:    .res 1
seed:         .res 1
rN:           .res 1
rng1:         .res 1
rng2:         .res 1

.SEGMENT "STARTUP"

RESET:
  .INCLUDE "init.asm"

.SEGMENT "CODE"
  LDA #STATEGAMEOVER
  STA gamestate

  JSR LoadPalette
  JSR LoadBackground
  JSR LoadGameOverCard

  LDA #%10010000
  STA PPU_CTRL
  LDA #%00011110
  STA PPU_MASK


  LDA #$0F
  STA APU_STATUS  ;enable Square 1, Square 2, Triangle and Noise channels.  Disable DMC.

  JSR ResetPosition

  LDA #$01
  STA seed

  LDA #$08
  STA timer

  LDA #$80
  STA timerDemo
forever:
  JMP forever

NMI:
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA IsUpdating
  BNE finNMI
  LDA #$01
  STA IsUpdating

  LDA #$00
  STA PPU_OAM_ADDR
  LDA #$02
  STA OAM_DMA

  LDA #%10010000
  STA PPU_CTRL
  LDA #%00011110
  STA PPU_MASK

  LDA #$00          ; no scroll
  STA PPU_SCROLL
  STA PPU_SCROLL

  JSR ReadControllers


GameEngine:  
  LDA gamestate
  CMP #STATEDEMO
  BEQ EngineDemo      ;;game is displaying demo
    
  LDA gamestate
  CMP #STATEGAMEOVER
  BEQ EngineGameOver  ;;game is displaying ending screen
  
  LDA gamestate
  CMP #STATEPLAYING
  BEQ EnginePlaying   ;;game is playing

GameEngineDone:  
  LDA #$00
  STA IsUpdating

finNMI:
  PLA
  TAY
  PLA
  TAX
  PLA

  RTI
;----------------------------------------------------------------------------
;GAME ENGINE
;----------------------------------------------------------------------------

EngineDemo:
  @beginDemo:
  JSR randomNumber
  demoLoop:
  LDA buttons
  CMP #$10
  BEQ DemoIsStoped
  LDA timerDemo
  BEQ endDemo
  JSR decreaseTimerDemo
  JMP GameEngineDone
  endDemo:
  LDA #$00
  STA gamestate
  LDA #$80
  STA timerDemo
  JMP GameEngineDone
  DemoIsStoped:
  LDA #$02
  STA gamestate
  JMP GameEngineDone

EngineGameOver:
  JSR LoadPlayer
  STA direction
  LDX #$01
  STA direction,X
  gameOverLoop:
  LDA score
  BNE @scoredisplay
  LDA score,X
  BNE @scoredisplay
  JMP @checkButton
  @scoredisplay:
  JSR LoadScore
  LDA #$00
  STA PPU_ADDRESS
  STA PPU_ADDRESS
  @checkButton:
  LDA buttons
  CMP #$10
  BEQ endGameOver
  @checkForTime:
  LDA timerDemo
  BEQ beginDemo
  JSR decreaseTimerDemo
  JSR decreaseTimer
  JMP GameEngineDone
  endGameOver:
  LDA #$02
  STA gamestate
  LDX #$01
  LDA #$00
  STA score
  STA score,X
  JMP GameEngineDone
  beginDemo:
  LDA #$01
  STA gamestate
  LDA #$A0
  STA timerDemo
  JMP GameEngineDone

EnginePlaying:
  LDA playingstate
  CMP #$00
  BEQ beginmatch
  CMP #$01
  BEQ playingLoop
  CMP #$02
  BEQ endofMatch

beginmatch:
  JSR LoadBackground
  JSR ResetPosition
  LDA #$00
  LDX #$01
  STA winner
  STA oldposbg1
  STA oldposbg1,X
  STA oldposbg2
  STA oldposbg2,X
  JSR LoadPlayer
  LDA #$01
  STA playingstate
  JMP GameEngineDone

playingLoop:
    JSR movingPlayers
    LDX #$01
    JSR changeDirection
    LDA counter
    BNE @endLoop
    JSR LoadPlayer
  @endLoop:
    LDX #$01
    LDA direction
    BEQ @end
    LDA direction,X
    BEQ @end
    JMP GameEngineDone
  @end:
    LDA #$40
    STA counter 
    LDA #$02
    STA playingstate
    JSR displayScore
    JMP GameEngineDone

endofMatch:
    DEC counter
    LDA counter
    BEQ @end
    JSR paletteBlink
    JMP GameEngineDone
  @end:
    LDA score
    CMP #$06
    BNE @checkScore2
    JMP endPlaying
    @checkScore2:
    LDX #$01
    LDA score,X
    CMP #$06
    BEQ endPlaying
    LDA #$00
    STA playingstate
    JMP GameEngineDone
  endPlaying:
    LDA #$00
    STA gamestate
    LDX #$01
    STA oldposbg1
    STA oldposbg1,X
    STA oldposbg2
    STA oldposbg2,X
    LDA #$80
    STA timerDemo
    LDA PPU_STATUS
    LDA #$3F
    STA PPU_ADDRESS
    LDA #$02
    STA PPU_ADDRESS
    LDA #$30
    STA PPU_DATA
    STA swap
    LDA #$00
    STA PPU_ADDRESS
    STA PPU_ADDRESS
    JSR ResetPosition
    JSR LoadBackground
    JSR LoadGameOverCard
    JMP GameEngineDone

;----------------------------------------------------------------------------
;SUBROUTINE
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------------------------------------------------------------------------------
; void VBlankWait() 
; wait for the vblank of the screen
;----------------------------------------------------------------------------------------------------------------------------------------------------
VBlankWait:
  BIT PPU_STATUS
  BPL VBlankWait
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
; void LoadPalette()
; load the palette data into the ppu
;----------------------------------------------------------------------------------------------------------------------------------------------------
LoadPalette:
    LDA PPU_STATUS
    LDA #$3F
    STA PPU_ADDRESS
    LDA #$00
    STA PPU_ADDRESS
    LDX #$00
  LoadPaletteLoop:
    LDA paletteData,x
    STA PPU_DATA
    INX
    CPX #$20
    BNE LoadPaletteLoop
    RTS

;----------------------------------------------------------------------------------------------------------------------------------------------------
; void ReadControllers() 
; use $C0,C1 for temp controller byte then transfer them to $DC,$DD for input down and $DE and $DF use to keep what is currently press
;----------------------------------------------------------------------------------------------------------------------------------------------------
ReadControllers:      ;
  LDX #$01            ; X = 1;
  SecondCheck:        ;
    SEC               ; P |= 0x01 ; set carry
  latchbtn:           ;
    PHP               ; S.push(P); //push processor status
    LDA #$01          ; A = 1;
    STA JOY1          ; JOY1 = A;
    LDA #$00          ; A = 0;
    STA JOY1          ; JOY1 = A;
    LDY #$08          ; Y = 8; // tell both controllers to latch buttons
  @dowhile:           ; do{
    LDA JOY1,X        ;   A = JOY1[X] //read info from controller (2 if X = 1, 1 if X = 0)
    LSR               ;   A >> 1; // shift bit into the right for puttin input bit in carry
    ROL tempHalf1btn  ;   vC0 <-< P; // rotate the bit to the left the carry bit goes into the 0 bit // vC0 goes A,Select,Up,Left from controller 2 and 1
    LSR               ;   A >> 1; 
    ROL tempHalf2btn  ;   VC1 <-< P; // and here goes B,Start,Down,Right from controller 2 and 1
    DEY               ;   Y--;
    BNE @dowhile      ; }while(Y != 0);
    LDA tempHalf1btn  ; A = vC0
    ORA tempHalf2btn  ; A = A | vC1; 
    PLP               ; P = S.pull();
    BCC @else         ; if((P&0x01) != 0){
    STA btnInstant,X  ;   vDC[X] = A;
    CLC               ;   P &= 0xFE; 
    BCC latchbtn      ;   if((P&0x01) == 0){ goto latchbtn; }
  @else:              ; }else{
    CMP btnInstant,X  ;   if(A != vDC[X]){
    BEQ @sinon        ;     A = buttons[X];
    LDA buttons,X     ;   }
  @sinon:             ;   else{
    TAY               ;     Y = A;
    EOR buttons,X     ;     A = (A | buttons[X]) & !(A & buttons[X]); // exclusive OR on A 
    AND btnInstant,X  ;     A &= btnInstant[X]; 
    STA btnInstant,X  ;     btnInstant[X] = A;
    STY buttons,X     ;     buttons[X] = Y;
    DEX               ;     X--;
    BPL SecondCheck   ;     if((P&0x80) == 0){ goto SecondCheck; }
    RTS               ;    }
                      ; } return;
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void LoadBackground()
;load any background but must be give in the adresse low and high
;----------------------------------------------------------------------------------------------------------------------------------------------------
LoadBackground:
  LDA #$00
  STA PPU_CTRL
  STA PPU_MASK
    LDA PPU_STATUS        ; read PPU status to reset the high/low latch
    LDA #$20
    STA PPU_ADDRESS       ; write the high byte of $2000 address
    LDA #$00
    STA PPU_ADDRESS       ; write the low byte of $2000 address

    LDA #<background
    STA pointerLo         ; put the low byte of the address of background into pointer
    LDA #>background
    STA pointerHi         ; put the high byte of the address into pointer
    
    LDX #$00              ; start at pointer + 0
    LDY #$00
  OutsideLoop:
    
  InsideLoop:
    LDA (pointerLo), y  ; copy one background byte from address in pointer plus Y
    STA PPU_DATA        ; this runs 256 * 4 times
    
    INY                 ; inside loop counter
    CPY #$00
    BNE InsideLoop      ; run the inside loop 256 times before continuing down
    
    INC pointerHi       ; low byte went 0 to 256, so high byte needs to be changed now
    
    INX
    CPX #$04
    BNE OutsideLoop     ; run the outside loop 256 times before continuing down
    LDA #%10010000
    STA PPU_CTRL
    LDA #%00011110
    STA PPU_MASK
    RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void LoadGameOverCard()
;load the game over on background
;----------------------------------------------------------------------------------------------------------------------------------------------------
LoadGameOverCard:
  LDA #$00
  STA PPU_CTRL
  STA PPU_MASK
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$21
  STA PPU_ADDRESS       ; write the high byte of $2000 address
  LDA #$AE
  STA PPU_ADDRESS       ; write the low byte of $2000 address
  LDX #$00
  gameoverCardLoop:
    LDA GameOver,X
    STA PPU_DATA
    INX
    CPX #$04
    BNE gameoverCardLoop
  next:
    LDA PPU_STATUS        ; read PPU status to reset the high/low latch
    LDA #$21
    STA PPU_ADDRESS       ; write the high byte of $2000 address
    LDA #$CE
    STA PPU_ADDRESS       ; write the low byte of $2000 address
  @Loop:
    LDA GameOver,X
    STA PPU_DATA
    INX
    CPX #$08
    BNE @Loop
    LDA #%10010000
    STA PPU_CTRL
    LDA #%00011110
    STA PPU_MASK
    RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void LoadPlayer()
;print the player into the background | check for collision on the bg layer
;----------------------------------------------------------------------------------------------------------------------------------------------------
LoadPlayer:
  LDA #$00
  STA PPU_CTRL
  STA PPU_MASK
  
 
  JSR castPosition
  LDX #$00        ; bg index
  LDY #$00        ; player index
  LDA direction
  BNE @continue
  JMP secondPlayer
  @continue:
  LDA oldposbg1,X
  BNE @replaceHeadByBody
  INX
  LDA oldposbg1,X
  BEQ @head
  LDX #$00

  @replaceHeadByBody:
  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC oldposbg1,X
  STA PPU_ADDRESS
  INX 
  LDA oldposbg1,X
  STA PPU_ADDRESS
  LDA counter
  BNE @standardBlock
  LDA oldDirection
  SEC 
  SBC direction
  CMP #$F9
  BEQ @rightToUp
  CMP #$FA
  BEQ @leftToUp
  CMP #$FD
  BEQ @rightToDown
  CMP #$FE
  BEQ @leftToDown
  CMP #$07
  BEQ @upToRight
  CMP #$03
  BEQ @downToRight
  CMP #$06
  BEQ @upToLeft
  CMP #$02
  BEQ @downToLeft
  JMP @standardBlock
  @rightToDown:
  @upToLeft:
  LDA #$FA 
  STA PPU_DATA
  JMP @newdir
  @leftToDown:
  @upToRight:
  LDA #$FB
  STA PPU_DATA
  JMP @newdir
  @downToRight:
  @leftToUp:
  LDA #$FC
  STA PPU_DATA
  JMP @newdir
  @downToLeft:
  @rightToUp:
  LDA #$FD
  STA PPU_DATA
  @newdir:
  LDA direction
  STA oldDirection
  JMP @head
  @standardBlock:
  LDA direction
  CMP #$08
  BEQ @vertblock
  CMP #$04
  BEQ @vertblock
  LDA #$FF
  STA PPU_DATA
  JMP @head
  @vertblock:
  LDA #$FE
  STA PPU_DATA

  @head:
  LDX #$00
  LDA posbg1,X
  CMP oldposbg1,X
  BNE @newPos
  INX
  LDA posbg1,X
  CMP oldposbg1,X
  BEQ @noNewPos
  @newPos:
  LDX #$00
  LDA posbg1,X
  STA oldposbg1,X
  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC posbg1,X
  STA PPU_ADDRESS
  INX
  LDA posbg1,X
  STA PPU_ADDRESS
  STA oldposbg1,X
  LDA PPU_DATA
  LDA PPU_DATA
  BEQ @noNewPos
  LDA #$10
  STA playersprite
  LDA #$00
  STA direction
  INC score,X
  LDA #$02
  STA winner
  @noNewPos:
  DEX
  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC posbg1,X
  STA PPU_ADDRESS
  INX
  LDA posbg1,X
  STA PPU_ADDRESS
  LDA playersprite,Y
  STA PPU_DATA

  secondPlayer:
  INY
  LDA direction,Y
  BNE @continue
  JMP @end
  @continue:
  LDX #$00
  LDA oldposbg2,X
  BNE @replaceHeadByBody
  INX
  LDA oldposbg2,X
  BEQ @head
  LDX #$00

  @replaceHeadByBody:
  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC oldposbg2,X
  STA PPU_ADDRESS
  INX 
  LDA oldposbg2,X
  STA PPU_ADDRESS
  LDA counter
  BNE @standardBlock
  LDA oldDirection,X
  SEC 
  SBC direction,X
  CMP #$F9
  BEQ @rightToUp
  CMP #$FA
  BEQ @leftToUp
  CMP #$FD
  BEQ @rightToDown
  CMP #$FE
  BEQ @leftToDown
  CMP #$07
  BEQ @upToRight
  CMP #$03
  BEQ @downToRight
  CMP #$06
  BEQ @upToLeft
  CMP #$02
  BEQ @downToLeft
  JMP @standardBlock
  @rightToDown:
  @upToLeft:
  LDA #$FA 
  STA PPU_DATA
  JMP @newdir
  @leftToDown:
  @upToRight:
  LDA #$FB
  STA PPU_DATA
  JMP @newdir
  @downToRight:
  @leftToUp:
  LDA #$FC
  STA PPU_DATA
  JMP @newdir
  @downToLeft:
  @rightToUp:
  LDA #$FD
  STA PPU_DATA
  @newdir:
  LDA direction,X
  STA oldDirection,X
  JMP @head
  @standardBlock:
  LDA direction,X
  CMP #$08
  BEQ @vertblock
  CMP #$04
  BEQ @vertblock
  LDA #$FF
  STA PPU_DATA
  JMP @head
  @vertblock:
  LDA #$FE
  STA PPU_DATA

  @head:
  LDX #$00
  LDA posbg2,X
  CMP oldposbg2,X
  BNE @newPos
  INX
  LDA posbg2,X
  CMP oldposbg2,X
  BEQ @noNewPos
  @newPos:
  LDX #$00
  LDA posbg2,X
  STA oldposbg2,X
  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC posbg2,X
  STA PPU_ADDRESS
  INX
  LDA posbg2,X
  STA PPU_ADDRESS
  STA oldposbg2,X
  LDA PPU_DATA
  LDA PPU_DATA
  BEQ @noNewPos
  LDA #$10
  STA playersprite,Y
  LDA #$00
  STA direction,X
  INC score
  LDA #$01
  STA winner
  @noNewPos:
  DEX
  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC posbg2,X
  STA PPU_ADDRESS
  INX
  LDA posbg2,X
  STA PPU_ADDRESS
  LDA playersprite,Y
  STA PPU_DATA
  
  @end:
  LDA #%10010000
  STA PPU_CTRL
  LDA #%00011110
  STA PPU_MASK
  LDA PPU_STATUS
  LDA #$00
  STA PPU_ADDRESS
  STA PPU_ADDRESS
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void castPosition()
;take posY and posX and transfer them into the 16 bit value wanted
;----------------------------------------------------------------------------------------------------------------------------------------------------
castPosition:
  LDA #$00
  STA posbg1
  STA posbg2
  LDY #$00   ; index
  LDA posXP1
  LDX #$00   ; mul index
  CLC
  @multiplication:     ; calculate value of Y in bg space
    ADC #OAMWIDTHSCREEN
    BCC @nextCalcul
    PHA
    LDA #$00
    ADC posbg1,Y
    STA posbg1,Y
    PLA
    @nextCalcul:
    INX
    CPX posYP1
    BNE @multiplication
    INY
    STA posbg1,Y
  castPos2:
    LDY #$00
    LDA posXP2
    LDX #$00
    CLC
  @multiplication:
    ADC #OAMWIDTHSCREEN
    BCC @nextCalcul
    PHA
    LDA #$00
    ADC posbg2,Y
    STA posbg2,Y
    PLA
    @nextCalcul:
    INX
    CPX posYP2
    BNE @multiplication
    INY
    STA posbg2,Y
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void movingPlayers()
;check the direction and move the arrow if the counter is reach
;----------------------------------------------------------------------------------------------------------------------------------------------------
movingPlayers:
  LDA counter
  CMP #$10
  BEQ @continue
  INC counter
  RTS
  @continue:
    LDA #$00
    STA counter
    LDA direction
    BEQ EndOfMoveP1
    CMP #$01
    BEQ @cas1
    CMP #$02
    BEQ @cas2
    CMP #$04
    BEQ @cas3
    CMP #$08
    BEQ @cas4
  @cas1:
    LDA posXP1
    CMP #(OAMWIDTHSCREEN-1)
    BEQ EndOfMoveP1
    CLC
    ADC #$01
    STA posXP1
    JMP EndOfMoveP1
  @cas2:
    LDA posXP1
    BEQ EndOfMoveP1
    SEC
    SBC #$01
    STA posXP1
    JMP EndOfMoveP1
  @cas3:
    LDA posYP1
    CMP #(OAMHEIGHTSCREEN-2)
    BEQ EndOfMoveP1
    CLC
    ADC #$01
    STA posYP1
    JMP EndOfMoveP1
  @cas4:
    LDA posYP1
    CMP #$01
    BEQ EndOfMoveP1
    SEC
    SBC #$01
    STA posYP1
    JMP EndOfMoveP1
  EndOfMoveP1:
    LDX #$01
    LDA direction,X
    BEQ EndOfMoveP2
    CMP #$01
    BEQ @cas1
    CMP #$02
    BEQ @cas2
    CMP #$04
    BEQ @cas3
    CMP #$08
    BEQ @cas4
  @cas1:
    LDA posXP2
    CMP #(OAMWIDTHSCREEN-1)
    BEQ EndOfMoveP2
    CLC
    ADC #$01
    STA posXP2
    JMP EndOfMoveP2
  @cas2:
    LDA posXP2
    BEQ EndOfMoveP2
    SEC
    SBC #$01
    STA posXP2
    JMP EndOfMoveP2
  @cas3:
    LDA posYP2
    CMP #(OAMHEIGHTSCREEN-2)
    BEQ EndOfMoveP2
    CLC
    ADC #$01
    STA posYP2
    JMP EndOfMoveP2
  @cas4:
    LDA posYP2
    CMP #$01
    BEQ EndOfMoveP2
    SEC
    SBC #$01
    STA posYP2
    JMP EndOfMoveP2
  EndOfMoveP2:
    RTS

;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void changeDirection()
;check the button in to change direction
;----------------------------------------------------------------------------------------------------------------------------------------------------
changeDirection:
  LDA btnInstant,X
  CMP #$01
  BEQ @cas1
  CMP #$02
  BEQ @cas2
  CMP #$04
  BEQ @cas3
  CMP #$08
  BNE @over
  JMP @cas4
  @over:
  JMP @EndOfChangeDirection
  @cas1:
    CPX #$01
    BNE @cas1p1
    LDA #$01
    STA direction,X
    LDA #$0D
    STA playersprite,X
    JMP @EndOfChangeDirection
  @cas1p1:
    LDA #$01
    STA direction,X
    LDA #$0C
    STA playersprite,X
    JMP @EndOfChangeDirection
  @cas2:
    CPX #$01
    BNE @cas2p1
    LDA #$02
    STA direction,X
    LDA #$09
    STA playersprite,X
    JMP @EndOfChangeDirection
  @cas2p1:
    LDA #$02
    STA direction,X
    LDA #$08
    STA playersprite,X
    JMP @EndOfChangeDirection
  @cas3:
    CPX #$01
    BNE @cas3p1
    LDA #$04
    STA direction,X
    LDA #$0F
    STA playersprite,X
    JMP @EndOfChangeDirection
  @cas3p1:
    LDA #$04
    STA direction,X
    LDA #$0E
    STA playersprite,X
    JMP @EndOfChangeDirection
  @cas4:
    CPX #$01
    BNE @cas4p1
    LDA #$08
    STA direction,X
    LDA #$0B
    STA playersprite,X
    JMP @EndOfChangeDirection
  @cas4p1:
    LDA #$08
    STA direction,X
    LDA #$0A
    STA playersprite,X
    JMP @EndOfChangeDirection
  @EndOfChangeDirection:
  DEX
  BEQ chd
  RTS
  chd:
  JMP changeDirection
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void resetPosition()
;reset the position of the players
;----------------------------------------------------------------------------------------------------------------------------------------------------
ResetPosition:
  LDA #STARTINGXP1
  STA posXP1
  LDA #STARTINGYP1
  STA posYP1
  LDA #STARTINGXP2
  STA posXP2
  LDA #STARTINGYP2
  STA posYP2
  LDX #$00
  LDA #$04
  STA direction,X
  STA oldDirection,X
  LDA #$0E
  STA playersprite,X
  INX
  LDA #$0B
  STA playersprite,X
  LDA #$08
  STA direction,X
  STA oldDirection,X
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void displayScore()
;display the score of the player
;----------------------------------------------------------------------------------------------------------------------------------------------------
displayScore:
  LDA #$00
  STA PPU_CTRL
  STA PPU_MASK

  LDA #STARTINGXP1-1
  STA posXP1
  LDA #STARTINGYP1-1
  STA posYP1
  LDA #STARTINGXP2-1
  STA posXP2
  LDA #STARTINGYP2-1
  STA posYP2
  LDY #$00
  @WriteScoreLineLoop:
  TYA
  PHA
  JSR castPosition
  PLA
  TAY
  LDX #$01
  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC posbg1
  STA PPU_ADDRESS
  LDA posbg1,X
  STA PPU_ADDRESS
  LDA #$00
  STA PPU_DATA
  STA PPU_DATA
  STA PPU_DATA

  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC posbg2
  STA PPU_ADDRESS
  LDA posbg2,X
  STA PPU_ADDRESS
  LDA #$00
  STA PPU_DATA
  STA PPU_DATA
  STA PPU_DATA
  INY
  INC posYP1
  INC posYP2
  CPY #$03
  BNE @WriteScoreLineLoop

  LDA #STARTINGXP1
  STA posXP1
  LDA #STARTINGYP1
  STA posYP1
  LDA #STARTINGXP2
  STA posXP2
  LDA #STARTINGYP2
  STA posYP2
  JSR castPosition

  LDX #$01
  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC posbg1
  STA PPU_ADDRESS
  LDA posbg1,X
  STA PPU_ADDRESS
  LDA score
  BNE @writeScore1
  CLC
  ADC #$07
  @writeScore1:
  LDY winner
  CPY #$01
  BEQ @winner1
  CLC
  ADC #$10
  @winner1:
  STA PPU_DATA

  LDA PPU_STATUS
  LDA #$20
  CLC
  ADC posbg2
  STA PPU_ADDRESS
  LDA posbg2,X
  STA PPU_ADDRESS
  LDA score,X
  BNE @writeScore2
  CLC
  ADC #$07
  @writeScore2:
  LDY winner
  CPY #$02
  BEQ @winner2
  CLC
  ADC #$10
  @winner2:
  STA PPU_DATA


  LDA #%10010000
  STA PPU_CTRL
  LDA #%00011110
  STA PPU_MASK
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void LoadScore()
;Load the score beside the game over card
;----------------------------------------------------------------------------------------------------------------------------------------------------
LoadScore:
  LDA PPU_STATUS
  LDA #$21
  STA PPU_ADDRESS
  LDA #$CC
  STA PPU_ADDRESS
  LDA score
  BNE @print
  CLC
  ADC #$07
  @print:
  STA PPU_DATA
  Score2:
  LDA PPU_STATUS
  LDA #$21
  STA PPU_ADDRESS
  LDA #$D3
  STA PPU_ADDRESS
  LDA score,X
  BNE @print
  CLC
  ADC #$07
  @print:
  STA PPU_DATA
  LDA #$00
  STA PPU_ADDRESS
  STA PPU_ADDRESS
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void paletteBlink()
;make the chosen sprite blink
;----------------------------------------------------------------------------------------------------------------------------------------------------
paletteBlink:
  LDA timer
  CMP #$08
  BNE @exit
  LDA #$00
  STA timer
  LDA PPU_STATUS
  LDA #$3F
  STA PPU_ADDRESS
  LDA #$02
  STA PPU_ADDRESS
  LDA swap
  CMP #$0F
  BEQ @whiteSwap
  CMP #$30
  BEQ @blackSwap
  @whiteSwap:
  LDA #$30
  JMP @print
  @blackSwap:
  LDA #$0F
  @print:
  STA PPU_DATA
  STA swap
  LDA #$00
  STA PPU_ADDRESS
  STA PPU_ADDRESS
  @exit:
  INC timer
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;void randomNumber()
;take the seed and change it and return 2 random number in rng1 and rng2
;----------------------------------------------------------------------------------------------------------------------------------------------------
randomNumber:
  LDA timer
  CMP #$08
  BNE @out
  ; Generate a random number between 0 and 255 (8-bit)
  LDA seed
  LDX #$01
  JSR randomize
  ; The random number is now in A (accumulator)
  AND #$0F
  CMP #$08
  BEQ @store1
  CMP #$04
  BEQ @store1
  CMP #$02
  BEQ @store1
  CMP #$01
  BNE @out
  @store1:
  STA rng1
  ; Generate a random number between 0 and 255 (8-bit)
  LDA seed
  LDX #$00
  JSR randomize2
  ; The random number is now in A (accumulator)
  AND #$0F
  CMP #$08
  BEQ @store2
  CMP #$04
  BEQ @store2
  CMP #$02
  BEQ @store2
  CMP #$01
  BNE @out
  @store2:
  STA rng2
  @out:
  JSR decreaseTimer

  randomize:
  ; Use X and A as inputs
  ; Outputs a random number in A
  LDY #0
  @loop:
  LDA random_table, x
  ADC seed
  STA seed
  INX
  INX
  INY
  BNE @loop
  RTS

  randomize2:
  ; Use X and A as inputs
  ; Outputs a random number in A
  LDY #0
  @loop:
  LDA random_table2, x
  ADC seed
  STA seed
  INX
  INX
  INY
  BNE @loop
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
;int mod()
;return A modulo rN in A
;----------------------------------------------------------------------------------------------------------------------------------------------------
mod:
  LDX #$00
  @divison:
  SEC
  SBC rN
  CMP rN
  BCS @divison
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
; void decreaseTimer()
; decrease timer. if timer is lower than a certain number return to the setter
;----------------------------------------------------------------------------------------------------------------------------------------------------
decreaseTimer:
  DEC timer
  BEQ @decreaseTimerHi
  RTS
  @setTimer:
  LDA #$08
  STA timer
  RTS
  @decreaseTimerHi:
  JMP @setTimer
;----------------------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------------------------------
; void decreaseTimer()
; decrease timer. if timer is lower than a certain number return to the setter
;----------------------------------------------------------------------------------------------------------------------------------------------------
decreaseTimerDemo:
  LDA timer
  CMP #$08
  BNE @out
  LDA timerDemo
  BEQ @out
  DEC timerDemo
  @out:
  RTS
;----------------------------------------------------------------------------------------------------------------------------------------------------


;-----------------------------------------DATA-----------------------------------------------------------

background:
  .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 1
  .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

  .BYTE $FB,$FF,$FF,$FF,$FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;;row 2
  .BYTE $16,$FF,$FF,$FF,$FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FA

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 3
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 4
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 5
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 6
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 7
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 8
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 9
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 10
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 11
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 12
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 13
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 14
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 15
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 16
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 17
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 18
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 19
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 20
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 21
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 22
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 23
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 24
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 25
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 26
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 27
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FE,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 28
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$FE

  .BYTE $FC,$FF,$FF,$FF,$FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 29
  .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FD

  .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 30
  .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

attribute:
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000

paletteData:
  .BYTE $0F,$30,$30,$30,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $0F,$30,$30,$30   ;;background palette
  .BYTE $0F,$30,$30,$30,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $0F,$30,$30,$30   ;;sprite palette

random_table:
  .BYTE $01, $02, $04, $08, $08, $04, $02, $01, $01, $02, $04, $08, $08, $04, $02, $01, $01, $02, $04, $08, $08, $04, $02, $01, $01, $02, $04, $08, $08, $04, $02, $01

random_table2:
  .BYTE $08, $04, $02, $01, $01, $02, $04, $08, $08, $04, $02, $01, $01, $02, $04, $08, $08, $04, $02, $01, $01, $02, $04, $08, $08, $04, $02, $01, $01, $02, $04, $08

GameOver:
  .BYTE "gameover"

.SEGMENT "CHARS"
  ;spr
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  ;bg
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$10,$30,$50,$10,$10,$10,$10,$7C
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$3C,$42,$02,$04,$18,$20,$42,$7E
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$3C,$42,$02,$3C,$02,$02,$42,$3C
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$08,$18,$28,$48,$FC,$08,$08,$1C
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$7E,$40,$40,$7C,$02,$02,$42,$7C
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$3C,$40,$40,$5C,$62,$42,$42,$3C
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$3C,$42,$42,$42,$42,$42,$42,$3C
  .BYTE $00,$10,$30,$7E,$FE,$7E,$30,$10,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$10,$30,$5E,$82,$5E,$30,$10,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $10,$38,$7C,$FE,$38,$38,$38,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $10,$28,$44,$EE,$28,$28,$38,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$08,$0C,$7E,$7F,$7E,$0C,$08,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$08,$0C,$7A,$41,$7A,$0C,$08,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$38,$38,$38,$FE,$7C,$38,$10,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$38,$28,$28,$EE,$44,$28,$10,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$55,$AA,$55,$AA,$55,$AA,$55,$AA;$10
  .BYTE $10,$30,$50,$10,$10,$10,$10,$7C,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $3C,$42,$02,$04,$18,$20,$42,$7E,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $3C,$42,$02,$3C,$02,$02,$42,$3C,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $08,$18,$28,$48,$FC,$08,$08,$1C,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $7E,$40,$40,$7C,$02,$02,$42,$7C,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $3C,$40,$40,$5C,$62,$42,$42,$3C,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $3C,$42,$42,$42,$42,$42,$42,$3C,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;$20
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;$30
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;$40
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;50
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;60
  .BYTE $00,$38,$44,$44,$7C,$44,$44,$44,$00,$00,$00,$00,$00,$00,$00,$00;a
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;b
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;c
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;d
  .BYTE $00,$7C,$44,$50,$70,$50,$44,$7C,$00,$00,$00,$00,$00,$00,$00,$00;e
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;f
  .BYTE $00,$38,$44,$40,$5C,$54,$44,$3C,$00,$00,$00,$00,$00,$00,$00,$00;g
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;h
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;i
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;j
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;k
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;l
  .BYTE $00,$6C,$54,$54,$54,$54,$54,$44,$00,$00,$00,$00,$00,$00,$00,$00;m
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;n
  .BYTE $00,$38,$44,$44,$44,$44,$44,$38,$00,$00,$00,$00,$00,$00,$00,$00;o
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;p
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;q
  .BYTE $00,$78,$44,$44,$78,$50,$48,$44,$00,$00,$00,$00,$00,$00,$00,$00;r
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;s
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;t
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;u
  .BYTE $00,$44,$44,$44,$44,$44,$28,$10,$00,$00,$00,$00,$00,$00,$00,$00;v
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;w
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;x
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;y
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00;z
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $FF,$41,$41,$FF,$F9,$19,$19,$F9,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $FF,$84,$84,$FF,$9F,$99,$99,$F9,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $9F,$98,$98,$FF,$9F,$90,$90,$FF,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $99,$1F,$19,$F9,$FF,$09,$09,$FF,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $99,$9F,$99,$F9,$99,$9F,$99,$F9,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $FF,$44,$44,$FF,$FF,$11,$11,$FF,$00,$00,$00,$00,$00,$00,$00,$00