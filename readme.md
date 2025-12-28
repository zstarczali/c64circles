# C64 Hi-Res Circle Drawing Demo
This project is a Commodore 64 demo that uses the hi-res bitmap mode and implements the Midpoint/Bresenham circle algorithm (integer-only, no floating point) to draw circles on the bitmap screen. The code takes care of VIC-II initialization, screen/bitmap memory setup, proper color handling (hi-res mode: 1 bit/pixel, one foreground + one background color per cell), and includes a fast screen clear routine.

![Commodore 64 Emulator Screenshot](https://github.com/zstarczali/c64circles/blob/main/images/circles.png) 

## Features
- Hi-res bitmap mode: bitmap at $6000, screen matrix (color nibbles) at $5C00
- Autostart: BASIC stub (10 SYS 2061) at .pc = $0801
- Midpoint circle algorithm: 8-way symmetry, integer arithmetic only
- Color handling: foreground color written to the upper nibble of the - screen matrix; background comes from $D021
- Fast clear: full bitmap clear via self-modifying loop
- Macro API: simple DrawCircle(px, py, pr, pc) macro to draw circles

## Memory and VIC Setup

- VIC bank: $4000–$7FFF
- Set by $DD00 low 2 bits → 10 (bank 1)
- Bitmap: $6000 (configured via $D018 bits)
- Screen matrix: $5C00 (40×25 bytes, nibble pairs: upper = foreground, - lower = background)
- Background/border: $D021 / $D020
- Mode: bitmap enabled via $D011 (bit 5 = 1), bank select via $DD00/$DD02

## Main Routines

- Initialization
    - VIC bank/mode setup
    - Screen matrix fill: fg = light green ($D), bg = current $D021 lower nibble
    - Clear bitmap

## Demo

 - Example circles:

    ```asm
    DrawCircle(110,  70, 35, $02)   ; red
    DrawCircle(210, 130, 45, $04)   ; light green
    ```


- Circle drawing (circle_midpoint)

    - d = 3 - 2r decision variable
    - Always increment x, conditionally decrement y

    - Plot with 8-way symmetry: plot_octants_8

- Pixel plotting (plot)
    - Converts (X,Y) → bitmap byte + bitmask (bitable)
    - X ≥ 256 fix: add +32 bytes to bitmap row, +32 to color RAM offset
    - Foreground color written to upper nibble of screen matrix

- Clear screen (clear_screen)
    - Self-modifying loop, 32×250 byte chunks

## Building with Kick Assembler
Compile with Kick Assembler:

```bash
java -jar KickAss.jar circles.asm -o circles.prg
```
Run in VICE emulator:
```bash
x64sc circles.prg
```

The program will autostart thanks to the BASIC stub.

## Known Limitations
- Only 1 foreground color per 8×8 block (hi-res restriction)
- No clipping → drawing outside screen may cause artifacts
- Very large radius may result in extra drawing time
