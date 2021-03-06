.include "bitmap.inc"
.include "inventory.inc"
.include "joystick.inc"
.include "macros.inc"
.include "memory.inc"
.include "math.inc"
.include "sprite.inc"
.include "text.inc"
.include "types.inc"
.include "zeropage.inc"

.CODE

; the bounds of the text area
TXT_ROW_START = 18
TXT_ROW_STOP  = 24
TXT_COL_START = 2
TXT_COL_STOP  = 17*2

NAME_ROW =  16
NAME_COL =  4
NAME_COL_STOP =  20

ACTION_COL = 9
ACTION_ROW = 1

ALERT_COL = 7
ALERT_ROW = 23

; the bounds of the inventory area
INV_COL_START = 2
INV_COL_STOP  = 17*2
INV_ROW_START = 18
INV_ROW_STOP = 23
INV_NUM_COLS = (INV_COL_STOP / 16)
INV_NUM_ROWS = (INV_ROW_STOP - INV_ROW_START)

; bounds of scrolldown button
SCROLLDOWN_X = 152
SCROLLDOWN_Y = 120
SCROLLDOWN_W = 8
SCROLLDOWN_H = 8

; bounds of scrollup button
SCROLLUP_X = 152
SCROLLUP_Y = 20
SCROLLUP_W = 8
SCROLLUP_H = 8


txtscroll: .byte 0 ;# of characters the text area is scrolled
invscroll: .byte 0 ;# of pixels the inventory is scrolled

; struct TextRegion console
console: .byte 0,16,16,4

;--------------------------------------
;onfire
;Call upon fire being pressed to handle fire-sensitive GUI elements.
;
.export __onfire
.proc __onfire

.endproc

;--------------------------------------
; name
; displays the room name given in (YX).
.export __gui_name
.proc __gui_name
@x=zp::tmp0
@y=zp::tmp1
	stx @x
	sty @y

	lda #NAME_COL
	sta text::colstart

	; clear existing name
	lda #129
	ldx #NAME_COL_STOP-NAME_COL
	stx text::len
@l0:	sta mem::spare,x
	dex
	bpl @l0
	lda #NAME_ROW
	ldx #<mem::spare
	ldy #>mem::spare
	jsr text::puts

	; print new name
	ldx @x
	ldy @y
	lda #NAME_ROW
	jmp text::print
.endproc

;--------------------------------------
;txt
;Displays the string in (YX).
;returns:
;  carry: set if there's more to display
;
.export __gui_txt
.proc __gui_txt
@done = zp::tmp0
@row = zp::tmp1
@msg = zp::tmp2
	stx @msg
	sty @msg+1

	lda #TXT_COL_START
	sta text::colstart
	lda #TXT_ROW_START
	sta @row

@l0:	ldy #$00
	sty @done
@l1:	lda (@msg),y
	beq @end
	iny
	cpy #TXT_COL_STOP-TXT_COL_START
	bcc @l1

	; go back to the last word that fits on the row
@chk:	lda (@msg),y
	cmp #' '
	beq @draw
	dey
	bpl @chk

	.byte $2c ;skw
@end:   inc @done
@draw:
	sty text::len
	ldx @msg
	ldy @msg+1
	lda @row
	jsr text::puts

	lda @msg
	clc
	adc text::len
	sta @msg
	bcc :+
	inc @msg+1

:	ldy #$00
@skipspaces:
	lda (@msg),y
	cmp #' '
	bne @nextrow
	incw @msg
	jmp @skipspaces

@nextrow:
	lda @done
	bne @0
	inc @row
	lda @row
	cmp #TXT_ROW_STOP
	bcc @l0
@0:	rts
.endproc

;--------------------------------------
; alert display the message in (YX) and prompts the user to press fire to
; continue.
.export __gui_alert
.proc __gui_alert
	jsr __gui_txt
	lda #ALERT_COL
	sta text::colstart
	lda #ALERT_ROW
	ldx #<@firemsg
	ldy #>@firemsg
	jsr text::print

@waitfire:
	jsr joy::poll
	cmp #$00
	beq @waitfire
	rts
@firemsg: .byte "press fire",0
.endproc

;--------------------------------------
; action sets the displayed user action to the string in (YX)
.export __gui_action
.proc __gui_action
	lda #ACTION_COL
	sta text::colstart
	lda #ACTION_ROW
	jsr text::print
	rts
.endproc

;--------------------------------------
;drawinv
;Displays the inventory.
.export __gui_drawinv
.proc __gui_drawinv
@row = zp::tmp2
@item = zp::tmp3
@msg = zp::tmp4
@numbuff = zp::tmp6
	stx @msg
	sty @msg+1

	jsr __gui_clrtxt

	lda #INV_COL_STOP-INV_COL_START
	sta text::len

	lda #INV_COL_START
	sta text::colstart
	lda #INV_ROW_START
	sta @row

	lda #'.'
	sta @numbuff+1
	lda #0
	sta @numbuff+2

	lda #$00
	sta @item

@l0:	lda #3
	sta text::len
	lda #'0'
	clc
	adc @item
	sta @numbuff
	ldx #<@numbuff
	ldy #>@numbuff
	lda @row
	jsr text::print

	lda #16-12
	sta text::len
	lda text::colstart
	clc
	adc #1
	sta text::colstart

	lda @item
	jsr inv::itemname
	cpy #$00
	beq @next
	lda @row
	jsr text::print

@next:	lda text::colstart
	clc
	adc #7
	sta text::colstart
	cmp #INV_COL_STOP-16
	bcc :+

	inc @row
	lda #INV_COL_START
	sta text::colstart
	lda @row
	cmp #INV_ROW_STOP
	bcs @done  ; we're out of rows

:	inc @item
	lda @item
	cmp inv::len
	bcs @done
	cmp #64
	bcc @l0

@done:	lda #7
	sta text::colstart
	lda #INV_ROW_STOP
	ldx #<@invmsg
	ldy #>@invmsg
	jsr text::print
	jsr highlightinv
	rts
@invmsg: .byte "inventory",0
.endproc


;--------------------------------------
; highlightinv highlights the currently selected item in the inventory.
.export highlightinv
.proc highlightinv
@dst = zp::tmp0
	lda inv::selection
	and #$01
	asl
	asl
	asl
	adc #INV_COL_START
	adc #INV_COL_START
	tax
	lda bm::columns,x
	sta @dst
	lda bm::columns+1,x
	sta @dst+1

	lda inv::selection
	lsr
	asl
	asl
	asl
	adc #INV_ROW_START*8
	adc @dst
	sta @dst
	lda @dst+1
	adc #$00
	sta @dst+1

	ldx #16/2
@l0:	ldy #$07
@l1:	lda (@dst),y
	eor #$ff
	sta (@dst),y
	dey
	bpl @l1
@nextcol:
	lda @dst
	clc
	adc #$c0
	sta @dst
	bcc :+
	inc @dst+1
:	dex
	bne @l0
	rts
.endproc

;--------------------------------------
; clrtxt clears the text display area
.export __gui_clrtxt
.proc __gui_clrtxt
@row=zp::tmp0
	lda #' '
	ldx #TXT_COL_STOP-TXT_COL_START
@l0:	sta mem::spare,x
	dex
	bpl @l0

	lda #TXT_COL_STOP-TXT_COL_START
	sta text::len
	lda #TXT_COL_START
	sta text::colstart

	lda #TXT_ROW_START
	sta @row
@l1:	lda @row
	ldx #<mem::spare
	ldy #>mem::spare
	jsr text::puts
	inc @row
	lda @row
	cmp #TXT_ROW_STOP
	bcc @l1
	rts
.endproc

;--------------------------------------
;scrollinv
;Scrolls the inventory by .A positions
;
.export __gui_scrollinv
.proc __gui_scrollinv
.endproc

;--------------------------------------
;textinput
.export __gui_textinput
__gui_textinput:
	jsr __gui_txt

;--------------------------------------
;input
.export __gui_input
.proc __gui_input
	rts
.endproc

;--------------------------------------
; wrect (slowly) draws a rectangle with the background color
;wrect
.export __gui_wrect
.proc __gui_wrect
@xstop=zp::tmp0
@ystop=zp::tmp1
@dst=zp::tmp2
@lmask=zp::tmp4
@rmask=zp::tmp5
@xstart=zp::tmp6
@ystart=zp::tmp7
@getdst:
	stx @xstart
	sty @ystart
	txa
	and #$f8
	lsr
	lsr
	tax
	lda bm::columns,x
	sta @dst
	lda bm::columns+1,x
	sta @dst+1

	lda @xstart
	and #$07

	tax
	lda #$00
@getlmask:
	sec
	ror
	dex
	bpl @getlmask
	sta @lmask

	lda @xstop
	sec
	sbc @xstart
	sta @xstart
	lda @xstop
	and #$07
	tax
	lda #$ff
@getrmask:
	lsr
	dex
	bpl @getrmask
	sta @rmask

	lda @lmask
	jmp @blitcol ; blit first column

@l0:	lda @xstart
	beq @done
	bpl @getmask
@done:	rts

@getmask:
	sec
	sbc #$08
	sta @xstart
	bmi @lastcol
	lda #$00
	.byt $2c
@lastcol:
	lda @rmask
@blitcol:
	sta @mask
	ldy @ystart
@mask=*+1
@l1:	lda #$00
	and (@dst),y
	sta (@dst),y
	iny
	cpy @ystop
	bcc @l1
        add16_8 @dst, #$c0
	jmp @l0
.endproc
