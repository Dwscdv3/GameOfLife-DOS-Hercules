cpu 8086

org 0x100
jmp start

%include "controlflow.inc"
%include "dos.asm"
%include "hercules.asm"

SEG_FRAMEBUFFER_1       equ 0xB000
ADDR_CMDLINE            equ 0x81
SCREEN_WIDTH            equ 720
ROW_BYTES               equ SCREEN_WIDTH / 8
BOARD_WIDTH             equ 240
BOARD_HEIGHT            equ 174
UNPACKED_SIZE           equ BOARD_WIDTH * BOARD_HEIGHT
PACKED_SIZE             equ UNPACKED_SIZE / 8


section .text

start:
    call hercules_protection_off
    call hercules_graphics_mode

    call get_arg0
    OpenFile si, READ_ONLY
    mov bx, ax
    ReadFile bx, seed, PACKED_SIZE
    CloseFile bx

reset:
    mov ax, ds
    mov es, ax
    mov si, seed
    mov di, board
    mov ah, 10000000b
.loop_start:
    cmp si, seed + PACKED_SIZE
    jae .loop_end
    mov al, [si]
    and al, ah
    jz .false
    mov al, 1
.false:
    stosb
    ror ah, 1
    jnc .skip_inc_si
    inc si
.skip_inc_si:
    jmp .loop_start
.loop_end:
    mov ax, SEG_FRAMEBUFFER_1
    mov es, ax

main:
    call draw
    call tick
    jmp main

draw:
    mov si, board
    xor di, di

    BeginCounterLoopDesc y, dl, BOARD_HEIGHT / 2
        %macro UnrollBody 1
            lodsb
            test al, al
            jz %%else
            %if %1 < 0x100
                mov al, %1
                or byte [es: di], al
                or byte [es: di + 0x2000], al
            %else
                mov ax, %1
                or word [es: di], ax
                or word [es: di + 0x2000], ax
            %endif
            jmp %%endif
        %%else:
            %if %1 < 0x100
                mov al, ~%1
                and word [es: di], ax
                and word [es: di + 0x2000], ax
            %else
                mov ax, ~%1
                and word [es: di], ax
                and word [es: di + 0x2000], ax
            %endif
        %%endif:
        %endmacro

        %macro DrawRow 0
            BeginCounterLoopDesc %%x, dh, SCREEN_WIDTH / 24
                UnrollBody 11100000b
                UnrollBody 00011100b
                UnrollBody 1000000000000011b
                inc di
                UnrollBody 01110000b
                UnrollBody 00001110b
                UnrollBody 1100000000000001b
                inc di
                UnrollBody 00111000b
                UnrollBody 00000111b
                inc di
            EndCounterLoopDesc %%x, dh
        %endmacro

        DrawRow
        add di, 0x4000 - ROW_BYTES
        DrawRow
        sub di, 0x4000

        %undef DrawRow
        %undef UnrollBody
    EndCounterLoopDesc y, dl

    ret

tick:
    %macro Count 0
        test [si], dh
        jz %%false
        inc ah
    %%false:
    %endmacro

    %macro Set 0
        cmp ah, 3
        je %%live
        cmp ah, 2
        jne %%die
        test [di], dh
        jz %%die
    %%live:
        or byte [di], 2
    %%die:
        inc di
    %endmacro

    %macro Up 0
        sub si, BOARD_WIDTH
        Count
    %endmacro

    %macro Down 0
        add si, BOARD_WIDTH
        Count
    %endmacro

    %macro Left 0
        dec si
        Count
    %endmacro

    %macro Right 0
        inc si
        Count
    %endmacro

    %define ResetCounter xor ah, ah

    mov si, board
    mov di, board
    mov dh, 1

    ResetCounter
    Down
    Right
    Up
    Set
    mov cl, BOARD_WIDTH - 2
    .loop_first_row:
        ResetCounter
        Left
        Down
        Right
        Right
        Up
        Set
    loop .loop_first_row
    ResetCounter
    Left
    Down
    Right
    Set
    inc si

    BeginCounterLoopDesc y, dl, BOARD_HEIGHT - 2
        ResetCounter
        Count
        Right
        Up
        Up
        Left
        Set
        inc si
        mov cl, BOARD_WIDTH - 2
        .loop_row:
            ResetCounter
            Count
            Left
            Down
            Down
            Right
            Right
            Up
            Up
            Set
        loop .loop_row
        ResetCounter
        Count
        Left
        Down
        Down
        Right
        Set
        inc si
    EndCounterLoopDesc y, dl
    sub si, BOARD_WIDTH

    ResetCounter
    Up
    Right
    Down
    Set
    mov cl, BOARD_WIDTH - 2
    .loop_last_row:
        ResetCounter
        Left
        Up
        Right
        Right
        Down
        Set
    loop .loop_last_row
    ResetCounter
    Left
    Up
    Right
    Set

    %define UNROLL_TIMES 20
    mov si, board
    mov cx, UNPACKED_SIZE / UNROLL_TIMES
    .loop_start:
        %rep UNROLL_TIMES
            shr byte [si], 1
            inc si
        %endrep
    loop .loop_start
    %undef UNROLL_TIMES

    %undef Up
    %undef Down
    %undef Left
    %undef Right
    %undef ResetCounter
    %undef Count
    %undef Set
    ret

; @modify SI: address of first argument
; @modify DI: garbage
; @once
get_arg0:
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
    cmp byte [di], ' '
    je .replace_char
    cmp byte [di], 0x0D
    je .replace_char
    inc di
    jmp .tokenize
.replace_char:
    mov byte [di], 0
.after_tokenize:
    ret


section .bss

seed    resb PACKED_SIZE
board   resb UNPACKED_SIZE
