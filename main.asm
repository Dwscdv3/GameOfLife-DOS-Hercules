cpu 8086

org 0x100
jmp start

%include "controlflow.inc"
%include "dos.asm"
%include "hercules.asm"

SEG_FRAMEBUFFER_1       equ 0xB000
SEG_FRAMEBUFFER_2       equ 0xB800
ADDR_CMDLINE            equ 0x81
SCREEN_WIDTH            equ 720
SCREEN_HEIGHT           equ 348
ROW_BYTES               equ SCREEN_WIDTH / 8
WIDTH_PER_CELL          equ 3
HEIGHT_PER_CELL         equ 2
GRID_WIDTH              equ SCREEN_WIDTH / WIDTH_PER_CELL
GRID_HEIGHT             equ SCREEN_HEIGHT / HEIGHT_PER_CELL


section .text

start:
    mov bx, onexit
    call hercules_protection_off
    mov word [bx], hercules_tmode
    call hercules_gmode
    call tokenize_cmdline
    OpenFile si, READ_ONLY
    mov [handle], ax
    ReadFile [handle], seed, seed.end - seed
    CloseFile [handle]
reset:
    mov ax, SEG_FRAMEBUFFER_1
    mov es, ax
    mov ax, SEG_FRAMEBUFFER_2
    mov ds, ax
    mov bp, seed
    xor bx, bx
    xor cx, cx
    xor dx, dx
    BeginCounterLoopAsc y, dl, 0
        BeginCounterLoopAsc x, cl, 0
            %macro UnrollBody 2
                mov bl, [bp]
                and bl, dh
                times %2 %1 bl, 1
                call set_cell
                inc cl
                shr dh, 1
            %endmacro
            mov dh, 10000000b
            UnrollBody shr, 4
            UnrollBody shr, 3
            UnrollBody shr, 2
            UnrollBody shr, 1
            UnrollBody shr, 0
            UnrollBody shl, 1
            UnrollBody shl, 2
            mov bl, [bp]
            and bl, dh
            times 3 shl bl, 1
            call set_cell
            inc bp
            %undef UnrollBody
        EndCounterLoopAsc x, cl, GRID_WIDTH
    EndCounterLoopAsc y, dl, GRID_HEIGHT
    call swap_ds_es
tick:
    xor cx, cx
    xor dx, dx
    BeginCounterLoopAsc y, dl, 0
        BeginCounterLoopAsc x, cl, 0
            %macro GetCellAndCount 0
                call get_cell
                test al, al
                jz %%skip
                shl bl, 1
            %%skip:
            %endmacro
            mov bx, 1
            dec dl
            GetCellAndCount
            inc cl
            GetCellAndCount
            inc dl
            GetCellAndCount
            inc dl
            GetCellAndCount
            dec cl
            GetCellAndCount
            dec cl
            GetCellAndCount
            dec dl
            test bl, 00001111b
            jz .early_return
            GetCellAndCount
            test bl, 00001110b
            jz .early_return
            dec dl
            GetCellAndCount
            inc dl
        .early_return:
            inc cl
            call get_cell
            test al, al
            jz .self_is_dead
            add bl, 00000100b
        .self_is_dead:
            and bl, 00001000b
            call set_cell
        EndCounterLoopAsc x, cl, GRID_WIDTH
    EndCounterLoopAsc y, dl, GRID_HEIGHT
    call swap_ds_es
    call hercules_page_flip
    jmp tick

swap_ds_es:
    mov ax, ds
    mov bx, es
    mov ds, bx
    mov es, ax
    ret

%macro Mul3_Div8_To 2
    mov %2, %1
    times 2 add %2, %1
    times 3 shr %2, 1
%endmacro

; @input CX: x
; @input DL: y
; @modify AL: return value 0 or non-0
; @modify AH: garbage
; @modify DI: index of target cell's first byte
; @modify BP: x % 8
get_cell:
    cmp dl, GRID_HEIGHT
    jae .out_of_bound
    cmp cx, GRID_WIDTH
    jae .out_of_bound
    mov ah, dl
    and ax, 0000000100000000b
    times 6 shl ax, 1
    mov di, ax
    mov al, ROW_BYTES
    mov ah, dl
    shr ah, 1
    mul ah
    Mul3_Div8_To cx, bp
    add ax, bp
    add di, ax
    mov bp, cx
    and bp, byte 00000111b
    mov ah, [.mask_table + bp]
    mov al, [di]
    and al, ah
    ret
.out_of_bound:
    xor al, al
    ret
.mask_table:
    db 10000000b, 00010000b, 00000010b, 01000000b
    db 00001000b, 00000001b, 00100000b, 00000100b

; @input CX: x
; @input DL: y
; @input BX: value, must be 0 (false) or 8 (true)
; @modify AX: garbage
; @modify BX: garbage
; @modify SI: garbage
; @modify DI: index of target cell's first byte
set_cell:
    mov ah, dl
    and ax, 0000000100000000b
    times 6 shl ax, 1
    mov di, ax
    mov al, ROW_BYTES
    mov ah, dl
    shr ah, 1
    mul ah
    Mul3_Div8_To cx, si
    add ax, si
    add di, ax
    mov si, cx
    and si, byte 00000111b
    add bx, si
    shl bx, 1
    mov ax, [cs: .jump_table + bx]
    jmp ax
.0  and byte [es: di],          00011111b
    and byte [es: di + 0x2000], 00011111b
    ret
.1  and byte [es: di],          11100011b
    and byte [es: di + 0x2000], 11100011b
    ret
.2  and word [es: di],          0111111111111100b
    and word [es: di + 0x2000], 0111111111111100b
    ret
.3  and byte [es: di],          10001111b
    and byte [es: di + 0x2000], 10001111b
    ret
.4  and byte [es: di],          11110001b
    and byte [es: di + 0x2000], 11110001b
    ret
.5  and word [es: di],          0011111111111110b
    and word [es: di + 0x2000], 0011111111111110b
    ret
.6  and byte [es: di],          11000111b
    and byte [es: di + 0x2000], 11000111b
    ret
.7  and byte [es: di],          11111000b
    and byte [es: di + 0x2000], 11111000b
    ret
.8  or byte [es: di],          11100000b
    or byte [es: di + 0x2000], 11100000b
    ret
.9  or byte [es: di],          00011100b
    or byte [es: di + 0x2000], 00011100b
    ret
.10 or word [es: di],          1000000000000011b
    or word [es: di + 0x2000], 1000000000000011b
    ret
.11 or byte [es: di],          01110000b
    or byte [es: di + 0x2000], 01110000b
    ret
.12 or byte [es: di],          00001110b
    or byte [es: di + 0x2000], 00001110b
    ret
.13 or word [es: di],          1100000000000001b
    or word [es: di + 0x2000], 1100000000000001b
    ret
.14 or byte [es: di],          00111000b
    or byte [es: di + 0x2000], 00111000b
    ret
.15 or byte [es: di],          00000111b
    or byte [es: di + 0x2000], 00000111b
    ret
.jump_table:
    dw  .0,  .1,  .2,  .3,  .4,  .5,  .6,  .7
    dw  .8,  .9, .10, .11, .12, .13, .14, .15

; @modify SI: address of first argument
tokenize_cmdline:
    push di
    mov si, ADDR_CMDLINE
.trim:
    cmp byte [si], ' '
    jne .after_trim
    inc si
    jmp .trim
.after_trim:
    mov di, si
.tokenize:
    cmp di, 0x100
    jge .after_tokenize
    cmp byte [di], 0
    je .replace_char
    cmp byte [di], ' '
    je .replace_char
    cmp byte [di], 0x0D
    je .replace_char
    inc di
    jmp .tokenize
.replace_char:
    mov byte [di], 0
    inc di
    jmp .tokenize
.after_tokenize:
    pop di
    ret


section .data

handle  dw 0


section .bss

seed    resb GRID_WIDTH * GRID_HEIGHT / 8
        .end:
