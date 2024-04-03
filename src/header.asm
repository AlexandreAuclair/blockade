.SEGMENT "HEADER"
.BYTE "NES"
.BYTE $1A ; header
.BYTE $02 ; 2* 16kb prog rom
.BYTE $01 ; 1* 8kb char rom
.BYTE %00000000 ; mapping & mirroring
.BYTE $00, $00, $00, $00, $00, $00, $00, $00 ; filler bytes

.SEGMENT "VECTORS"
  .WORD NMI
  .WORD RESET
  .WORD 0