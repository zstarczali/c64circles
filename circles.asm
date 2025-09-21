.pc = $0801
// BASIC autostart: 10 SYS2061
.byte $0B,$08,$0A,$00,$9E,$32,$30,$36,$31,$00,$00,$00

// -------- Zero page symbols --------
.const BYTEADDR = $FC      // $FC/$FD -> bitmap byte pointer (indirect)
.const CR_PTR   = $FE      // $FE/$FF -> Screen matrix pointer (indirect)

// -------- Constants --------
.const BMPSCREEN = $6000

// -------- Macros --------
.macro DrawCircle(px, py, pr, pc) {
    lda #pc
    sta drawColor
    lda #<px
    sta cx_lo
    lda #>px
    sta cx_hi
    lda #py
    sta cy
    lda #pr
    sta radius
    jsr circle_midpoint
}



// =========================
//   INIT + DEMO
// =========================

// prepare self-mod clear
        lda #>BMPSCREEN
        sta mod1+2
        lda #<BMPSCREEN
        sta mod1+1

// white background, white border
        lda #$01
        sta $D021
        sta $D020

// enable bitmap
        ldy #$3B
        sty $D011

        lda $DD02
        ora #$03
        sta $DD02

// VIC bank = $4000-$7FFF
        lda $DD00
        and #$FC
        ora #$02
        sta $DD00

// screen matrix = $5C00, bitmap = $6000
        lda $D018
        and #$0F
        ora #$70
        sta $D018

        lda $D018
        and #$F0
        ora #$08
        sta $D018

// screen matrix fill (fg/bg nibbles): $D0 = fg=$D (light green), bg=$0 (black)
ldx #$00
        lda $D021       // jelenlegi háttérszín
        and #$0F        // alsó nibble = háttér
        sta tmp         // ideiglenesen eltároljuk
        lda #$D0        // felső nibble = $D (világoszöld), alsó nibble = 0
        and #$F0        // csak felső nibble marad
        ora tmp         // összerakjuk: fg=$D, bg=$D021
colfill:
        sta $5C00,x
        sta $5D00,x
        sta $5E00,x
        sta $5F00,x
        inx
        bne colfill

        jsr clear_screen

// demo: három kör különböző színnel
        //DrawCircle(160, 100, 60,  $00)   // fekete (fekete háttéren nem látszik)
        DrawCircle(110,  70, 35,  $02)   // piros
        DrawCircle(210, 130, 45,  $04)   // világoszöld

hang:
        jmp hang


// =========================================================
//  MIDPOINT / BRESENHAM CIRCLE  (d = 3 - 2r, always x++)
// =========================================================
circle_midpoint:
        lda #0
        sta x8
        lda radius
        sta y8

// d = 3 - 2*r  (16-bit into d_hi:d_lo)
        lda radius
        asl                 // 2r -> t_lo/t_hi
        sta t_lo
        lda #0
        rol
        sta t_hi

        lda #3
        sec
        sbc t_lo
        sta d_lo
        lda #0
        sbc t_hi
        sta d_hi

cm_loop:
        jsr plot_octants_8

        lda x8
        cmp y8
        bcc cm_cont
        beq cm_cont
        rts
cm_cont:
// if d <= 0 ?
        lda d_hi
        bmi cm_le_zero
        ora d_lo
        beq cm_le_zero
        jmp cm_gt_zero

cm_le_zero:
// d += 4x + 6
        lda x8
        asl
        sta t_lo
        lda #0
        sta t_hi
        asl t_lo
        rol t_hi            // t = 4x
        clc
        lda t_lo
        adc #6
        sta t_lo
        lda t_hi
        adc #0
        sta t_hi
        lda d_lo
        clc
        adc t_lo
        sta d_lo
        lda d_hi
        adc t_hi
        sta d_hi
        jmp cm_inc_x

cm_gt_zero:
// d += 4*(x - y) + 10, y--
        lda x8
        sec
        sbc y8
        sta t_lo
        lda #0
        sbc #0
        sta t_hi
        asl t_lo
        rol t_hi
        asl t_lo
        rol t_hi            // t = 4*(x - y)
        clc
        lda t_lo
        adc #10
        sta t_lo
        lda t_hi
        adc #0
        sta t_hi
        lda d_lo
        clc
        adc t_lo
        sta d_lo
        lda d_hi
        adc t_hi
        sta d_hi
        dec y8

cm_inc_x:
        inc x8
        jmp cm_loop


// =========================
//   8 OCTANTS (uses your plot)
// =========================
plot_octants_8:
        // (cx + x, cy + y)
        lda cx_lo
        clc
        adc x8
        sta xp+1
        lda cx_hi
        adc #0
        sta xp
        lda cy
        clc
        adc y8
        sta yp
        jsr plot

        // (cx - x, cy + y)
        lda cx_lo
        sec
        sbc x8
        sta xp+1
        lda cx_hi
        sbc #0
        sta xp
        lda cy
        clc
        adc y8
        sta yp
        jsr plot

        // (cx + x, cy - y)
        lda cx_lo
        clc
        adc x8
        sta xp+1
        lda cx_hi
        adc #0
        sta xp
        lda cy
        sec
        sbc y8
        sta yp
        jsr plot

        // (cx - x, cy - y)
        lda cx_lo
        sec
        sbc x8
        sta xp+1
        lda cx_hi
        sbc #0
        sta xp
        lda cy
        sec
        sbc y8
        sta yp
        jsr plot

        // (cx + y, cy + x)
        lda cx_lo
        clc
        adc y8
        sta xp+1
        lda cx_hi
        adc #0
        sta xp
        lda cy
        clc
        adc x8
        sta yp
        jsr plot

        // (cx - y, cy + x)
        lda cx_lo
        sec
        sbc y8
        sta xp+1
        lda cx_hi
        sbc #0
        sta xp
        lda cy
        clc
        adc x8
        sta yp
        jsr plot

        // (cx + y, cy - x)
        lda cx_lo
        clc
        adc y8
        sta xp+1
        lda cx_hi
        adc #0
        sta xp
        lda cy
        sec
        sbc x8
        sta yp
        jsr plot

        // (cx - y, cy - x)
        lda cx_lo
        sec
        sbc y8
        sta xp+1
        lda cx_hi
        sbc #0
        sta xp
        lda cy
        sec
        sbc x8
        sta yp
        jsr plot
        rts


// =========================
//   PLOT (bitmap $6000) + HI-RES szín ($5C00 felső nibble)
//   FIX: X>=256 esetén bitmap +32 bájt, col +32
// =========================
plot:
        ldy yp
        ldx xp+1

        // build bitmap byte address into BYTEADDR ($FC/$FD)
        lda ytablelow,y
        clc
        adc xtablelow,x
        sta BYTEADDR

        lda ytablehigh,y
        adc xtablehigh,x
        sta BYTEADDR+1

        lda BYTEADDR
        clc
        adc #<BMPSCREEN
        sta BYTEADDR
        lda BYTEADDR+1
        adc #>BMPSCREEN
        sta BYTEADDR+1

        // --- ha X >= 256 (xp != 0), lépj +32 bájtot a sorban ---
        lda xp
        beq @no_xhi_bmp
        clc
        lda BYTEADDR
        adc #32
        sta BYTEADDR
        lda BYTEADDR+1
        adc #0
        sta BYTEADDR+1
@no_xhi_bmp:

        // Color-mátrix oszlop: col = X>>3 (low byte alapján)
        lda xp+1
        lsr
        lsr
        lsr
        sta col

        // --- ha X >= 256, col += 32 (a 40 oszlopból a jobb oldali 8 blokk) ---
        lda xp
        beq @no_xhi_col
        lda col
        clc
        adc #32
        sta col
@no_xhi_col:

        // sor = Y>>3
        lda yp
        lsr
        lsr
        lsr
        sta row

        // cr = row*40 = row*32 + row*8
        lda row
        sta cr_lo
        lda #0
        sta cr_hi
        asl cr_lo
        rol cr_hi
        asl cr_lo
        rol cr_hi
        asl cr_lo
        rol cr_hi
        asl cr_lo
        rol cr_hi
        asl cr_lo
        rol cr_hi            // *32

        lda row
        sta tmp_lo
        lda #0
        sta tmp_hi
        asl tmp_lo
        rol tmp_hi
        asl tmp_lo
        rol tmp_hi
        asl tmp_lo
        rol tmp_hi           // *8

        clc
        lda cr_lo
        adc tmp_lo
        sta cr_lo
        lda cr_hi
        adc tmp_hi
        sta cr_hi            // row*40

        clc
        lda cr_lo
        adc col
        sta cr_lo
        lda cr_hi
        adc #0
        sta cr_hi

        // --- HI-RES szín a képernyő-mátrixba ($5C00): felső nibble = előszín ---
        clc
        lda cr_lo
        adc #<$5C00
        sta CR_PTR
        lda cr_hi
        adc #>$5C00
        sta CR_PTR+1

        lda drawColor
        and #$0F
        asl
        asl
        asl
        asl                 // A = (fg<<4)
        sta tmp_lo

        ldy #0
        lda (CR_PTR),y
        and #$0F            // háttér (alsó nibble) marad
        ora tmp_lo          // előszín a felső nibble-be
        sta (CR_PTR),y

        // --- bit beállítása a bitmap bájtban ---
        ldy #0
        lda (BYTEADDR),y
        ora bitable,x
        sta (BYTEADDR),y
        rts


// =========================
//   CLEAR BITMAP ($6000..$7FFF)
// =========================
clear_screen:
        ldy #32
cl1:
        ldx #0
        lda #0
mod1:
        sta BMPSCREEN,x
        inx
        cpx #250
        bne mod1

        clc
        lda mod1+1
        adc #250
        sta mod1+1
        lda mod1+2
        adc #0
        sta mod1+2

        dey
        bne cl1

        lda #<BMPSCREEN
        sta mod1+1
        lda #>BMPSCREEN
        sta mod1+2
        rts


// =========================
//   VARIABLES
// =========================
cx_lo:     .byte 0
cx_hi:     .byte 0
cy:        .byte 0
radius:    .byte 0
x8:        .byte 0
y8:        .byte 0
d_lo:      .byte 0
d_hi:      .byte 0
t_lo:      .byte 0
t_hi:      .byte 0
xp:        .byte 0,0
yp:        .byte 0
drawColor: .byte $00
tmp:       .byte 0

// color ram address builder (not ZP; reused for $5C00 index)
cr_lo:   .byte 0
cr_hi:   .byte 0
tmp_lo:  .byte 0
tmp_hi:  .byte 0
row:     .byte 0
col:     .byte 0


// =========================
/*  TABLES (unchanged) */
// =========================
ytablelow:
.byte 0,1,2,3,4,5,6,7
.byte 64,65,66,67,68,69,70,71
.byte 128,129,130,131,132,133,134,135
.byte 192,193,194,195,196,197,198,199
.byte 0,1,2,3,4,5,6,7
.byte 64,65,66,67,68,69,70,71
.byte 128,129,130,131,132,133,134,135
.byte 192,193,194,195,196,197,198,199
.byte 0,1,2,3,4,5,6,7
.byte 64,65,66,67,68,69,70,71
.byte 128,129,130,131,132,133,134,135
.byte 192,193,194,195,196,197,198,199
.byte 0,1,2,3,4,5,6,7
.byte 64,65,66,67,68,69,70,71
.byte 128,129,130,131,132,133,134,135
.byte 192,193,194,195,196,197,198,199
.byte 0,1,2,3,4,5,6,7
.byte 64,65,66,67,68,69,70,71
.byte 128,129,130,131,132,133,134,135
.byte 192,193,194,195,196,197,198,199
.byte 0,1,2,3,4,5,6,7
.byte 64,65,66,67,68,69,70,71
.byte 128,129,130,131,132,133,134,135
.byte 192,193,194,195,196,197,198,199
.byte 0,1,2,3,4,5,6,7

ytablehigh:
.byte 0,0,0,0,0,0,0,0
.byte 1,1,1,1,1,1,1,1
.byte 2,2,2,2,2,2,2,2
.byte 3,3,3,3,3,3,3,3
.byte 5,5,5,5,5,5,5,5
.byte 6,6,6,6,6,6,6,6
.byte 7,7,7,7,7,7,7,7
.byte 8,8,8,8,8,8,8,8
.byte 10,10,10,10,10,10,10,10
.byte 11,11,11,11,11,11,11,11
.byte 12,12,12,12,12,12,12,12
.byte 13,13,13,13,13,13,13,13
.byte 15,15,15,15,15,15,15,15
.byte 16,16,16,16,16,16,16,16
.byte 17,17,17,17,17,17,17,17
.byte 18,18,18,18,18,18,18,18
.byte 20,20,20,20,20,20,20,20
.byte 21,21,21,21,21,21,21,21
.byte 22,22,22,22,22,22,22,22
.byte 23,23,23,23,23,23,23,23
.byte 25,25,25,25,25,25,25,25
.byte 26,26,26,26,26,26,26,26
.byte 27,27,27,27,27,27,27,27
.byte 28,28,28,28,28,28,28,28
.byte 30,30,30,30,30,30,30,30

xtablelow:
.byte 0,0,0,0,0,0,0,0
.byte 8,8,8,8,8,8,8,8
.byte 16,16,16,16,16,16,16,16
.byte 24,24,24,24,24,24,24,24
.byte 32,32,32,32,32,32,32,32
.byte 40,40,40,40,40,40,40,40
.byte 48,48,48,48,48,48,48,48
.byte 56,56,56,56,56,56,56,56
.byte 64,64,64,64,64,64,64,64
.byte 72,72,72,72,72,72,72,72
.byte 80,80,80,80,80,80,80,80
.byte 88,88,88,88,88,88,88,88
.byte 96,96,96,96,96,96,96,96
.byte 104,104,104,104,104,104,104,104
.byte 112,112,112,112,112,112,112,112
.byte 120,120,120,120,120,120,120,120
.byte 128,128,128,128,128,128,128,128
.byte 136,136,136,136,136,136,136,136
.byte 144,144,144,144,144,144,144,144
.byte 152,152,152,152,152,152,152,152
.byte 160,160,160,160,160,160,160,160
.byte 168,168,168,168,168,168,168,168
.byte 176,176,176,176,176,176,176,176
.byte 184,184,184,184,184,184,184,184
.byte 192,192,192,192,192,192,192,192
.byte 200,200,200,200,200,200,200,200
.byte 208,208,208,208,208,208,208,208
.byte 216,216,216,216,216,216,216,216
.byte 224,224,224,224,224,224,224,224
.byte 232,232,232,232,232,232,232,232
.byte 240,240,240,240,240,240,240,240
.byte 248,248,248,248,248,248,248,248
.byte 0,0,0,0,0,0,0,0
.byte 8,8,8,8,8,8,8,8
.byte 16,16,16,16,16,16,16,16
.byte 24,24,24,24,24,24,24,24
.byte 32,32,32,32,32,32,32,32
.byte 40,40,40,40,40,40,40,40
.byte 48,48,48,48,48,48,48,48
.byte 56,56,56,56,56,56,56,56

xtablehigh:
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0
.byte 1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1

bitable:
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
.byte 128,64,32,16,8,4,2,1
