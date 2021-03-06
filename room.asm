.include "app.inc"
.include "base.inc"
.include "file.inc"
.include "fx.inc"
.include "gui.inc"
.include "macros.inc"
.include "math.inc"
.include "memory.inc"
.include "sprite.inc"
.include "text.inc"
.include "types.inc"
.include "zeropage.inc"
.CODE

ROOM_WIDTH = 96/8
ROOM_HEIGHT = 112

MAX_THINGS = 8
NUM_EXITS=6

;--------------------------------------
numrooms: .byt 0

idstable: .res MAX_THINGS
nametable: .res MAX_THINGS*2
desctable: .res MAX_THINGS*2
setuptable: .res MAX_THINGS*2
handlertable: .res MAX_THINGS*2

numthings: .byte 0
sprites: .res MAX_THINGS*2

name: .word 0
description: .word 0


; the addresses for room names for N,S,E,W,U,D
exits: .res 2*6

;--------------------------------------
; removes the thing with the given ID from the room
.export __room_remove
.proc __room_remove
	ldx numthings
@l0:	dex
	bmi @done
	cmp idstable,x
	bne @l0
	lda #$00
	sta idstable,x
	txa
	tay

:	lda idstable+1,y
	sta idstable,y
	iny
	cpy numthings
	bne :-

	txa
	asl
	tax
	ldy #$00
@l1:	lda sprites+2,x
	sta sprites,x
	lda sprites+3,x
	sta sprites+1,x

	lda desctable+2,x
	sta desctable,x
	lda desctable+3,x
	sta desctable+1,x

	lda nametable+2,x
	sta nametable,x
	lda nametable+3,x
	sta nametable+1,x

	lda handlertable+2,x
	sta handlertable,x
	lda handlertable+3,x
	sta handlertable+1,x
	inx
	inx
	iny
	cpy numthings
	bne @l1

	dec numthings

@done:	rts
.endproc

;--------------------------------------
; addthing adds the thing in (YX) to the room
; 0-1 sprite address
; 2-3 name address
; 4-5 description address
; 6-7 handler (use) address
.proc __room_addthing
@t=zp::tmp0
	stx @t
	sty @t+1

	lda numthings
	asl
	tax

	ldy #$00
	lda (@t),y
	sta sprites,x
	iny
	lda (@t),y
	sta sprites+1,x

	iny
	lda (@t),y
	sta nametable,x
	iny
	lda (@t),y
	sta nametable+1,x

	iny
	lda (@t),y
	sta desctable,x
	iny
	lda (@t),y
	sta desctable+1,x

	iny
	lda (@t),y
	sta handlertable,x
	iny
	lda (@t),y
	sta handlertable+1,x
	rts
.endproc

;--------------------------------------
; gethandle returns the room handle for the thing of the ID given in (YX)
; if the thing is not present in the room, returns $ff. The result is given in .A
; Use the handle returned to get the sprite, description, etc. via the other
; getters.
.export __room_gethandle
.proc __room_gethandle
	stx @lo
	sty @hi

	tya
	ldy #$00
	ldx numthings
@l0:
@lo=*+1
	lda #$00
	cmp idstable,y
	bne @next
@hi=*+1
	lda #$00
	cmp idstable+1,y
	bne @next
@found:
	tya
	lsr
	rts

@next: 	iny
	iny
	dex
	bne @l0
@notfound:
	lda #$ff
	rts
.endproc

;--------------------------------------
; getsprite returns the sprite for the thing from the given room handle in (YX).
.export __room_getsprite
.proc __room_getsprite
	tax
	lda sprites+1,x
	tay
	lda sprites,x
	tax
	rts
.endproc

;--------------------------------------
; getdesc returns the description for the thing from the given room handle in (YX)
.export __room_getdesc
.proc __room_getdesc
	tax
	lda desctable+1,x
	tay
	lda desctable,x
	tax
	rts
.endproc

;--------------------------------------
; loads a filename from the given length prefixed string
.proc load_lpstr
	stx $f0
	sty $f1
	ldy #$00
	lda ($f0),y
	ldx $f0
	inx
	bne :+
	inc $f1
:	ldy $f1
	jmp file::load
.endproc

;--------------------------------------
;load loads the room data for the room name in (YX)
; format of room file:
; - picdata
; - exits (1 byte ID of rooms):
;   North
;   South
;   West
;   East
;   Up
;   Down
; - things table
; - room-description
; things data
.export __room_load
.proc __room_load
	jmp load_lpstr
.endproc

;--------------------------------------
;update updates tables with the buffered room data
.export __room_update
.proc __room_update
@src = zp::tmp0
@dst = zp::tmp2
@cnt = zp::tmp4
@desc = mem::roombuff + (ROOM_WIDTH*ROOM_HEIGHT)
	; load the room image data
	ldx #<mem::roombuff
	ldy #>mem::roombuff
	stx @src
	sty @src+1
	ldx #<($1100 + ($c0*4) + 16)
	ldy #>($1100 + ($c0*4) + 16)
	stx @dst
	sty @dst+1

	ldx #ROOM_WIDTH
@l1:	ldy #$00
@l0:	lda (@src),y
	sta (@dst),y
	iny
	cpy #ROOM_HEIGHT
	bne @l0

	lda @src
	clc
	adc #ROOM_HEIGHT
	bcc :+
	inc @src+1
:	sta @src

	lda @dst
	clc
	adc #$c0
	bcc :+
	inc @dst+1
:	sta @dst
	dex
	bne @l1

	; get the exits (len-prefixed)
	ldx #$00
	ldy #$00
@exits: lda @src
	sta exits,x
	lda @src+1
	sta exits+1,x
	lda (@src),y
	bne :+
	lda #$00
	sta exits,x
	sta exits+1,x
:	sec
	adc @src
	sta @src
	bcc :+
	inc @src+1
:	inx
	inx
	cpx #NUM_EXITS*2
	bne @exits

@name:	lda @src
	sta name
	lda @src+1
	sta name+1
	; get the room name
:	lda (@src),y
	incw @src
	cmp #$00
	bne :-

@description:
	lda @src
	sta description
	lda @src+1
	sta description+1
	; get the room description
:	lda (@src),y
	incw @src
	cmp #$00
	bne :-

	; get the things in the room
	lda (@src),y
	sta numthings
	bne :+
	jmp @done
:	incw @src
	lda #$00
	sta @cnt

@things:
	ldy #$00
	lda (@src),y
	bne @getthing
	jmp @done

@getthing:
	lda @cnt
	cmp numthings
	bne :+
	jmp @done

:	asl
	tax

@getname:
	lda @src
	sta nametable,x
	lda @src+1
	sta nametable+1,x
:	lda (@src),y
	php
	incw @src
	plp
	bne :-

@getdesc:
	lda @src
	sta desctable,x
	lda @src+1
	sta desctable+1,x
:	lda (@src),y
	php
	incw @src
	plp
	bne :-

@getsprite:
	lda @src
	sta sprites,x
	lda @src+1
	sta sprites+1,x

	; move past x, y, flags
	lda @src
	adc #$03
	sta @src
	bcc :+
	inc @src+1

:	; compute address of sprite graphics
	adc #$02
	sta (@src),y
	lda @src+1
	adc #$00
	incw @src
	sta (@src),y
	incw @src

	; move pointer past the sprite data
	ldx @src
	ldy @src+1
	jsr sprite::size
	pha
	txa
	adc @src
	sta @src
	pla
	adc @src+1
	sta @src+1


	lda @cnt
	asl
	tax
	ldy #$01
	lda (@src),y	; if MSB is 0, store $0000 for the handler
	bne :+
	sta setuptable,x
	sta setuptable+1,x
	beq @setupdone
:	lda @src	; otherwise store the address of the handler
	adc #2
	sta setuptable,x
	lda @src+1
	adc #0
	sta setuptable+1,x
	ldy #$00
	lda (@src),y
	adc @src
	tax
	iny
	lda (@src),y
	adc @src+1
	stx @src
	sta @src+1
@setupdone:
	incw @src
	incw @src

	; move pointer past handler code (add handler length)
	lda @cnt
	asl
	tax
	ldy #$01
	lda (@src),y	; if len is 0, store $0000 for the handler
	bne :+
	dey
	lda (@src),y
	bne :+
	sta setuptable,x
	sta setuptable+1,x
	beq @handlerdone

:	lda @src
	clc
	adc #$02
	sta handlertable,x
	lda @src+1
	adc #$00
	sta handlertable+1,x

	; add handler length
	ldy #$00
	lda (@src),y
	adc @src
	tax
	iny
	lda (@src),y
	adc @src+1
	stx @src
	sta @src+1
@handlerdone:
	incw @src
	incw @src

@nextthing:
	inc @cnt
	jmp @things

@done:
	jsr gui::clrtxt
	ldx app::cursor
	ldy app::cursor+1
	jsr sprite::on

	; write the room name
	ldx name
	ldy name+1
	jsr gui::name

	; enable the sprites
	ldx numthings
	beq @writedesc
	dex
:	txa
	pha
	asl
	tax
	lda sprites,x
	ldy sprites+1,x
	tax
	jsr sprite::on
	pla
	tax
	dex
	bpl :-

	; run setup code
	ldx numthings
	dex
:	txa
	pha
	jsr setup
	pla
	tax
	dex
	bpl :-

@writedesc:
	; write the room's description
	ldx description
	ldy description+1
	lda #20
	sta text::speed
	jsr gui::txt
	lda #0
	sta text::speed

	rts
.endproc

;--------------------------------------
; setup runs the handler for the thing given in .A
.export setup
.proc setup
	asl
	tay
	lda setuptable,y
	sta @handle
	lda setuptable+1,y
	bne :+
	rts
:	sta @handle+1
@handle=*+1
	jmp $ffff
.endproc


;--------------------------------------
; use runs the handler for the thing given in .A
.export use
.proc use
	asl
	tay
	lda handlertable,y
	sta @handle
	lda handlertable+1,y
	bne :+
	rts
:	sta @handle+1
@handle=*+1
	jmp $ffff
.endproc

;--------------------------------------
; lookat prints the description for the thing given in .A
.proc lookat
	asl
	tay
	lda desctable,y
	tax
	lda desctable+1,y
	tay
	jsr gui::txt
	rts
.endproc

;--------------------------------------
; look prints the description of the selected thing.
.export __room_look
__room_look:
	lda #$01
	.byte $2c
;--------------------------------------
; handle runs the handler for the thing at the coordinates given in (.X,.Y) or,
; if there is nothing at that position, does nothing.
.export __room_use
.proc __room_use
@xpos=zp::tmpa
@ypos=zp::tmpb
@xstop=zp::tmpc
@ystop=zp::tmpd
@i=zp::tmpe
@use_or_look=zp::tmpf
@thing=zp::tmp10
	lda #$00
	sta @use_or_look
	lda #$00
	sta @i
@l0:	lda @i
	cmp numthings
	bcc :+
	rts

	; get the thing's positon
:	asl
	tax
	lda sprites+1,x
	tay
	lda sprites,x
	tax
	jsr sprite::pos
	stx @xpos
	sty @ypos

	; get the thing's dimensions and compute bounds of its rect
	lda @i
	asl
	tax
	lda sprites+1,x
	tay
	lda sprites,x
	tax
	jsr sprite::dim
	clc
	adc @ypos
	sta @ystop

	txa
	asl
	asl
	asl
	adc @xpos
	sta @xstop

	lda xpos
	cmp @xpos
	bcc @next
	cmp @xstop
	bcs @next

	sec
	sbc @xpos
	sta relx

	lda ypos
	cmp @ypos
	bcc @next
	cmp @ystop
	bcs @next

	sec
	sbc @ypos
	sta rely

	lda @i
	ldx @use_or_look	; do we want to LOOK or USE the selected thing?
	bne @look

@use:   jmp use
@look:  jmp lookat

@next:  inc @i
	lda @i
	cmp numthings
	bcc @l0
	rts
.endproc

;--------------------------------------
.export __room_north
.proc __room_north
	ldx #$00
	.byte $2c
.endproc
;--------------------------------------
.export __room_south
.proc __room_south
	ldx #$02
	.byte $2c
.endproc
;--------------------------------------
.export __room_east
.proc __room_east
	ldx #$04
	.byte $2c
.endproc
;--------------------------------------
.export __room_west
.proc __room_west
	ldx #$06
	.byte $2c
.endproc
;--------------------------------------
.proc __room_up
	ldx #$08
	.byte $2c
.endproc
;--------------------------------------
.proc __room_down
	ldx #$0a
	lda exits+1,x
	beq @done
	pha
	lda exits,x
	pha
	jsr fx::fadeout
	pla
	tax
	pla
	tay
	jsr __room_load
	jsr fx::fadein
	jsr __room_update
@done:	rts
.endproc
