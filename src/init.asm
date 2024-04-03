  SEI ; disable IRQs
  CLD ; disable decimal mode
  LDX #$40
  STX JOY2_FRAME    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX PPU_CTRL ; disable NMI
  STX PPU_MASK ; disable rendering
  STX DMC_FREQ ; disable DMC IRQs

  JSR VBlankWait

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  LDA #$24
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  INX
  BNE clrmem

  JSR VBlankWait
