.include "build/tetris.inc"
.include "ips.inc"

; adapted from Tetris Gym hz.asm by Kirjava
; new changes for CTWC Jonas Cup by Kitaru

tapDebounceThreshold := $10         ; constant

; $5A technically overlaps with garbageHole, but relevant code should not be reached
tapCount := $5A
tapTimer := $5B
tapDebounce := $5C
tapDirection := $5D
tapBufferButtons := $5E
tapShiftDisabled := $5F

.segment "CTWC_INIT_GAME_MOD_2"
        ips_segment     "CTWC_INIT_GAME_MOD_2",$8757
; The CTWC cart version replaces now-unused B-Type init code with our own
;        lda     gameType                        ; 8757
;        beq     @skipTypeBInit                  ; 8759
;        lda     #$25                            ; 875B
;        sta     player1_lines                   ; 875D
;        sta     player2_lines                   ; 875F
; In this public release, we can relocate this block into the init func we call
		jsr initGameDAS
        nop
        nop
        nop
        nop
        nop
        nop
        nop

spawnPiece := $98BA
.segment "CTWC_SPAWN_NEXT_MOD"
        ips_segment     "CTWC_SPAWN_NEXT_MOD",$9894
; Replace unused 2P branch from vanilla cart with a call to our variable init func
;        lda     numberOfPlayers                 ; 9894
;        cmp     #$01                            ; 9896
;        beq     @spawnPiece                     ; 9898
;        ...
        jsr ctwc_tapStart
        jmp spawnPiece

.segment "CTWC_CONTROLS_ACTIVE"
        ips_segment     "CTWC_CONTROLS_ACTIVE",$81CF
; Changes to playState_playerControlsActiveTetrimino
; We can put more code here and overrun the unused branchOnPlayStatePlayer2
        jsr     ctwc_tapLimit           ; 81CF
        jsr     rotate_tetrimino        ; 81D2
        jsr     drop_tetrimino          ; 81D5
        LDX     levelNumber
        CPX     #$27
        BCC     @noDKS
        JSR     drop_tetrimino
  @noDKS:
        RTS

.segment "DKS_IMPL_2"
        ips_segment     "DKS_IMPL_2",$8973
;        lda     #$01                            ; 8973
        LDA     #$00

.segment "CTWC_CODE_CAVE_3"
        ips_segment     "CTWC_CODE_CAVE_3",unreferenced_data4+768
initGameDAS:
; Reproduce B-Type init game logic here for use on vanilla carts,
;  then proceed with our DAS Mode variable init
        lda     gameType                        ; 8757
        beq     @skipTypeBInit                  ; 8759
        lda     #$25                            ; 875B
        sta     player1_lines                   ; 875D
        sta     player2_lines                   ; 875F
@skipTypeBInit:
ctwc_tapStart:
        lda #$00
        sta tapCount
        sta tapTimer+0
        lda #tapDebounceThreshold
        sta tapDebounce
        sta tapBufferButtons
        rts
ctwc_tapLimit:
; In the CTWC cart, there is a title screen selection for different game modes (normal, DAS, 2P mindmeld, ...)
;        lda ctwc_mode
;        cmp #$01                        ; DAS mode
;        bne @originalShift
        jsr ctwc_hzLimit
        lda tapShiftDisabled            ; if DAS mode, if disable flag set, skip piece movement
        bne @ret
@originalShift:
        jsr shift_tetrimino
@ret:
        lda #$00
        sta tapShiftDisabled
        rts
ctwc_hzLimit:
        lda tapCount
        beq @notTapping
    ; if tapping, tick frame count
        lda tapTimer
        clc
        adc #$01
        sta tapTimer
@notTapping:
    ; tick debounce counter
        lda tapDebounce
        cmp #tapDebounceThreshold
        beq @debounceCap
        inc tapDebounce
@debounceCap:
        lda tapBufferButtons    ; keep previous tap buffer state in X
        tax
        lda newlyPressedButtons
        and #$03
        sta tapBufferButtons    ; set prospective early tap buffer state
        bne @tapped             ; if there's a fresh tap on this frame, process it now
        txa                     ; if there's a 1-frame buffer tap, then mux it in
        bne @bufferTapped
        rts
@bufferTapped:
        sta tapBufferButtons    ; use tap buffer as a tmp var for muxing
        lda newlyPressedButtons
        and #$FC                ; get non-horizontal tapped buttons
        ora tapBufferButtons    ; combine
        sta newlyPressedButtons
        lda #$00
        sta tapBufferButtons    ; clear buffer
        lda newlyPressedButtons ; set up A as appropriate for @tapped logic
        and #$03
@tapped:
        clc
        ror             ; normalize direction to 1/0
        tax             ; keep button direction in X to free up A
        lda heldButtons ; SOCD 40Hz override: if both are held, dir = Right
        and #$03
        cmp #$03
        bne :+
        lda #$00
        tax
:
        cpx tapDirection
        bne @newTap
    ; if debounce meets threshold, this is a fresh tap
        lda tapDebounce
        cmp #tapDebounceThreshold
        bne @within
@newTap:
        stx tapDirection
@wrap:
        lda #$00
        sta tapCount
    ; 0 is the first frame (11 means 12 frames)
        sta tapTimer
@within:
    ; in Gym impl: increment tap count here
    ; in CTWC rework: instrument tap count increment directly in shift_tetrimino
    ; Both: reset debounce
        ;inc tapCount
        lda tapCount
        cmp #$10
        bcs @wrap
        lda #$00
        sta tapDebounce
        sta tapShiftDisabled
        ldx tapCount
        cpx #$0B
        bcs @disableShift
        lda tbl_dasLimit,x
        cmp tapTimer
        bmi @clearBuffer      ; if tap is allowed, clear 1-frame buffer and return
@disableShift:
        ; if tap is early, set the move disabled flag
        lda #$01
        sta tapShiftDisabled
        ; if tap is precisely 1-frame early, keep the tap buffer
        ; else, clear the tap buffer
        lda tbl_dasLimit,x
        cmp tapTimer
        beq @ret
@clearBuffer:
        lda #$00
        sta tapBufferButtons
@ret:
        rts
ctwc_registerShift:
        lda #$03
        sta soundEffectSlot1Init
        lda newlyPressedButtons
        and #$03
        beq @notTapped
        inc tapCount
        jmp @ret
@notTapped:
        lda heldButtons
        and #$03
        beq @ret
        ; treat any DAS shift as the potential first tap of a new string
        ; this keeps scheduling correct for tap strings after DAS,
        ; such as when "perfect first frame tap" was from buffered DAS,
        ; or when the player attempts a "multi-quicktap"
        lda #$00
        sta tapCount
        inc tapCount
        sta tapTimer+0
        sta tapDebounce
@ret:
        rts
tbl_dasLimit:
        .byte $FF, $FF, 11, 17, 23, 29, 35, 41, 47, 53; , 59

.segment "CTWC_REGISTER_SHIFT_MOD_1"
        ips_segment     "CTWC_REGISTER_SHIFT_MOD_1",$89E4
;        lda     #$03                            ; 89E4
;        sta     soundEffectSlot1Init            ; 89E6
        jsr ctwc_registerShift
        nop
        nop

.segment "CTWC_REGISTER_SHIFT_MOD_2"
        ips_segment     "CTWC_REGISTER_SHIFT_MOD_2",$89F9
;        lda     #$03                            ; 89F9
;        sta     soundEffectSlot1Init            ; 89FB
        jsr ctwc_registerShift
        nop
        nop
