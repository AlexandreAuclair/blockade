; NES Constant

SPRITE_ADDR  = $0200 ; Begining Address of sprite      | write - read |

  ; PPU registers

PPU_CTRL     = $2000 ; PPU control register            |     write    |
PPU_MASK     = $2001 ; PPU mask register               |     write    |
PPU_STATUS   = $2002 ; PPU status register             |     read     |
PPU_OAM_ADDR = $2003 ; OAM address port                |     write    |
PPU_OAM_DATA = $2004 ; OAM data port                   | write - read |
PPU_SCROLL   = $2005 ; PPU scrolling position register |     write    | x2
PPU_ADDRESS  = $2006 ; PPU address register            | write - read |
PPU_DATA     = $2007 ; PPU data port                   | write - read |

  ; 2A03 registers

SQ1_VOL      = $4000 ; Duty cycle and volume           
SQ1_SWEEP    = $4001 ; Sweep control register          
SQ1_LO       = $4002 ; Low byte of period              
SQ1_HI       = $4003 ; High byte of period and length counter value
SQ2_VOL      = $4004 ; Duty cycle and volume
SQ2_SWEEP    = $4005 ; Sweep control register
SQ2_LO       = $4006 ; Low byte of period
SQ2_HI       = $4007 ; High byte of period and length counter value
TRI_CTRL     = $4008 ; Linear counter
;            = $4009 ; Unused
TRI_LO       = $400A ; Low byte of period
TRI_HI       = $400B ; High byte of period and length counter value
NOISE_VOL    = $400C ; Volume
;            = $400D ; Unused
NOISE_LO     = $400E ; Period and waveform shape
NOISE_HI     = $400F ; Length counter value
DMC_FREQ     = $4010 ; IRQ flag, loop flag and frequency
DMC_RAW      = $4011 ; 7-bit DAC
DMC_START    = $4012 ; Start address = $C000 + $40*$xx
DMC_LEN      = $4013 ; Sample length = $10*$xx + 1 bytes (128*$xx + 8 samples)
OAM_DMA      = $4014 ; OAM DMA register (high byte)    |     write    |
APU_STATUS   = $4015 ; Sound channels enable           |     write    | Sound channel and IRQ status |     read     |
JOY1         = $4016 ; Joystick strobe                 |     write    | Joystick 1 data              |     read     |
JOY2_FRAME   = $4017 ; Frame counter control           |     write    | Joystick 2 data              |     read     |