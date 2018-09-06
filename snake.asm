  .inesprg 1
  .ineschr 1
  .inesmap 0
  .inesmir 1

;Constants for snake direction
RIGHTDIR  = $00
DOWNDIR   = $01
LEFTDIR   = $02
UPDIR     = $03

;Initial Constances
SLENINIT  = $0A

;GAMESTATES
GTITLE    = $00
GGAME     = $01
GDEAD     = $02

;COORDINATES
CCENTERH  = $21
CCENTERL  = $CF

  .bank 0
  .rsset $0000
buttons    .rs 1 ; Button State
vblank_c   .rs 1 ; vblank counter
g_state    .rs 1 ; gamestate
g_seed     .rs 2 ; PRNG Seed
s_pos      .rs 2 ; head position on map
s_pos_x    .rs 1 ; x Position of head
s_pos_y    .rs 1 ; y Position of head
s_dir      .rs 1 ; Current Direction of Snake
s_len      .rs 1 ; Current Snake length
s_list     .rs 256 ;Snake Tiles
s_list_pos .rs 1 ; List Position
i_pos_x    .rs 1 ; Item Position X
i_pos_y    .rs 1 ; Item Position Y
i_idx      .rs 2 ; Item Index
  .org $C000
RESET:
  SEI
  CLD
  ;Init Palette
  LDA $2002
  LDA #$3F
  STA $2006
  LDA #$10
  STA $2006
  LDX #$00
PaletteLoop:
  LDA PaletteData, x
  STA $2007
  INX
  CPX #$20
  BNE PaletteLoop
  ;Load Background

  ;Load Attribute
  LDA $2002
  LDA #$23
  STA $2006
  LDA #$C0
  STA $2006
  LDX #$00
  ;Enable VBLANK IRQ
  LDA #%10010000
  STA $2000
  ;Enable Background/Sprites
  LDA #%00011110
  STA $2001
  ;Disable Scrolling
  LDA #$00
  STA $2005
  STA $2005
  ;Init PRNG
  LDA #$3F
  STA g_seed
  LDA #$F1
  STA g_seed+1
  ;Init Game State
  JSR ResetGameState
  LDA #GGAME
  STA g_state
Forever:
  JSR PRNG
  JMP Forever

NMI:
  JSR ReadController
  LDA buttons
  ;Check right down
  AND #%00000001
  BEQ CheckRightDone
  LDA #RIGHTDIR
  STA s_dir
  JMP CheckUpDone
CheckRightDone:
  ;Check left down
  LDA buttons
  AND #%00000010
  BEQ CheckLeftDone
  LDA #LEFTDIR
  STA s_dir
  JMP CheckUpDone
CheckLeftDone:
  ;Check down down
  LDA buttons
  AND #%00000100
  BEQ CheckDownDone
  LDA #DOWNDIR
  STA s_dir
  JMP CheckUpDone
CheckDownDone:
  ;Check up down
  LDA buttons
  AND #%00001000
  BEQ CheckUpDone
  LDA #UPDIR
  STA s_dir
CheckUpDone:
  LDA vblank_c
  CLC
  ADC #$01
  CMP #$05
  BNE VBlankCheckDone
  LDA g_state
  CMP #GGAME
  BNE CheckGameDone
  JSR UpdateHead
  JSR CheckCollision
  JSR UpdateList
  LDA $2002
  LDA s_pos+1
  STA $2006
  LDA s_pos
  STA $2006
  LDA #$5E
  STA $2007
  LDA $2002
  LDA i_idx+1
  STA $2006
  LDA i_idx
  STA $2006
  LDA #$CF
  STA $2007
CheckGameDone:
  LDA g_state
  CMP #GDEAD
  BNE CheckGameOver
  LDA buttons
  AND #$FF
  BEQ CheckButtonPressedDead
  JSR ResetGameState
  LDA #GGAME
  STA g_state
  JMP CheckGameOver
CheckButtonPressedDead
  LDX #$08
  JSR PrintString
CheckGameOver
  LDA #$00
VBlankCheckDone:
  STA vblank_c

  ;Enable VBLANK IRQ
  LDA #%10010000
  STA $2000
  ;Enable Background/Sprites
  LDA #%00011110
  STA $2001
  ;Disable Scrolling
  LDA #$00
  STA $2005
  STA $2005
  RTI

ResetMap:
  ;Disable VBLANK IRQ
  LDA #%00000000
  STA $2000
  ;Enable Background/Sprites
  LDA #%00000000
  STA $2001
  ;Disable Scrolling
  LDA #$00
  STA $2005
  STA $2005
  LDY #$00
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006
OuterLoadBackgroundLoop:
  LDX #$00
InnerLoadBackgroundLoop:
  LDA #$81
  STA $2007
  INX
  CPX #$20
  BNE InnerLoadBackgroundLoop
  INY
  CPY #$1D
  BNE OuterLoadBackgroundLoop
  ;Enable VBLANK IRQ
  LDA #%10010000
  STA $2000
  ;Enable Background/Sprites
  LDA #%00011110
  STA $2001
  ;Disable Scrolling
  LDA #$00
  STA $2005
  STA $2005
  RTS

;Reset Gamestate
ResetGameState:
  JSR ResetMap
  ;Init VBlank Counter
  LDA #$00
  STA vblank_c
  ;Init Snake Position
  LDA #CCENTERH
  STA s_pos+1
  LDA #CCENTERL
  STA s_pos
  LDA #$10
  STA s_pos_x
  LDA #$0E
  STA s_pos_y
  ;Init Snake Direction
  LDA #DOWNDIR
  STA s_dir
  ;Init Snake Length
  LDA #SLENINIT
  STA s_len
  ASL A
  LDX #$FF
ClearList:
  LDA #$00
  STA s_list,X
  DEX
  CPX #$00
  BNE ClearList
  ;Init Snake List Position
  LDA #$00
  STA s_list_pos
  JSR AddItem
  RTS

;Print a String in the Center
PrintString:
  LDA $2002
  LDA #CCENTERH
  STA $2006
  LDA #CCENTERL
  STA $2006
PrintStringLoop:
  DEX
  LDA gameover,x
  ADC #$15
  STA $2007
  CPX #$00
  BNE PrintStringLoop
  RTS

;Update Button State
ReadController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadControllerLoop:
  LDA $4016
  LSR A
  ROL buttons
  DEX
  BNE ReadControllerLoop
  RTS

;Add Item
AddItem:
  LDA g_seed+1
  AND #$1F
  CMP #$1F
  BNE check31
  JSR PRNG
  JMP AddItem
check31:
  CMP #$1E
  BNE check30
  JSR PRNG
  JMP AddItem
check30:
  CMP #$1D
  BNE check29
  JSR PRNG
  JMP AddItem
check29:
  STA i_pos_y
  STA i_idx
  LDA #$00
  STA i_idx+1
  LDX #$05
YPos:
  CLC
  ASL i_idx
  ROL i_idx+1
  DEX
  BNE YPos

  CLC
  LDA g_seed
  AND #$1F
  STA i_pos_x
  INC i_pos_x
  ADC i_idx
  STA i_idx
  LDA #$20
  ADC i_idx+1
  STA i_idx+1

  RTS

;Update Head Position
UpdateHead:
  LDA s_dir
  CMP #RIGHTDIR
  BNE RightCheckDone
  LDA s_pos
  CLC
  ADC #$01
  STA s_pos
  LDA s_pos+1
  ADC #$00
  STA s_pos+1
  INC s_pos_x
  JMP LeftDirCheckDone
RightCheckDone:
  LDA s_dir
  CMP #UPDIR
  BNE UpDirCheckDone
  LDA s_pos
  SEC
  SBC #$20
  STA s_pos
  LDA s_pos+1
  SBC #$00
  STA s_pos+1
  DEC s_pos_y
  JMP LeftDirCheckDone
UpDirCheckDone:
  LDA s_dir
  CMP #DOWNDIR
  BNE DownDirCheckDone
  LDA s_pos
  CLC
  ADC #$20
  STA s_pos
  LDA s_pos+1
  ADC #$00
  STA s_pos+1
  INC s_pos_y
  JMP LeftDirCheckDone
DownDirCheckDone:
  LDA s_dir
  CMP #LEFTDIR
  BNE LeftDirCheckDone
  LDA s_pos
  SEC
  SBC #$01
  STA s_pos
  LDA s_pos+1
  SBC #$00
  STA s_pos+1
  DEC s_pos_x
LeftDirCheckDone:
  RTS

UpdateList:
  LDA s_list_pos
  CLC
  ADC #$01
  CMP s_len
  BNE ListLengthCheckDone
  LDA #$00
ListLengthCheckDone:
  STA s_list_pos
  ASL A
  TAX
  TAY
  INY
  LDA $2002
  LDA s_list, y
  STA $2006
  DEY
  LDA s_list, y
  STA $2006
  LDA #$81
  STA $2007
  LDA s_pos
  STA s_list, x
  INX
  LDA s_pos+1
  STA s_list, x
  RTS

CheckCollision:
  LDX #$00
CheckCollisionLoop:
  TXA
  ASL A
  TAY
  LDA s_list, y
  CMP s_pos
  BNE NoSelfCollision
  INY
  LDA s_list, y
  CMP s_pos+1
  BNE NoSelfCollision
  LDA #GDEAD
  STA g_state
NoSelfCollision
  INX
  CPX s_len
  BNE CheckCollisionLoop
  LDA s_pos_y
  CMP #$00
  BNE NoUpperBorderCollision
  LDA #GDEAD
  STA g_state
  JMP NoRightBorderCollision
NoUpperBorderCollision:
  LDA s_pos_y
  CMP #$1D
  BNE NoLowerBorderCollision
  LDA #GDEAD
  STA g_state
  JMP NoRightBorderCollision
NoLowerBorderCollision:
  LDA s_pos_x
  CMP #$00
  BNE NoLeftBorderCollision
  LDA #GDEAD
  STA g_state
  JMP NoRightBorderCollision
NoLeftBorderCollision:
  LDA s_pos_x
  CMP #$21
  BNE NoRightBorderCollision
  LDA #GDEAD
  STA g_state
NoRightBorderCollision:
  LDA i_pos_y
  CMP s_pos_y
  bne NoItemHit
  LDA i_pos_x
  CMP s_pos_x
  bne NoItemHit
  LDA #$05
  CLC
  ADC s_len
  STA s_len 
  JSR AddItem
NoItemHit
  RTS

PRNG:
  LDX #$08
  LDA g_seed+0
PrngBegin:
  ASL A
  ROL g_seed+1
  BCC NoShift
  EOR #$2D
NoShift:
  DEX
  BNE PrngBegin
  ORA #$01
  STA g_seed+0

  CMP #$00
  RTS

gameover   .db $1B, $0E, $1F, $18, $0E, $16, $0A, $10

  .bank 1
  .org $E000
  PaletteData:
  .db $22,$29,$1A,$0F,$22,$36,$17,$0F,$22,$30,$21,$0F,$22,$27,$17,$0F  ;background palette data
  .db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data

attribute:
  .db %00000000, %00010000, %0010000, %00010000, %00000000, %00000000, %00000000, %00110000

  .org $FFFA
  .dw NMI
  .dw RESET
  .dw 0

  .bank 2
  .org $0000
  .incbin "gen.chr"

