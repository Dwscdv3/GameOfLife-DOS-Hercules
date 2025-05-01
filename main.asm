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
BOARD_WIDTH             equ 240
BOARD_HEIGHT            equ 174


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
    mov ax, ds
    mov es, ax
    mov si, seed
    mov di, board
    mov ah, 10000000b
.loop_start:
    cmp si, seed.end
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

main:
    call draw
    call tick
    jmp main

draw:
    mov ax, SEG_FRAMEBUFFER_1
    mov es, ax
    mov si, board
    xor di, di
    BeginCounterLoopAsc y, dl, 0
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

        %macro DrawRow 1
            BeginCounterLoopAsc x_%1, dh, 0
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
            EndCounterLoopAsc x_%1, dh, SCREEN_WIDTH / 24
        %endmacro

        DrawRow bank01
        add di, 0x4000 - ROW_BYTES
        DrawRow bank23
        sub di, 0x4000

        %undef DrawRow
        %undef UnrollBody
    EndCounterLoopAsc y, dl, BOARD_HEIGHT / 2
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

    mov ax, ds
    mov es, ax
    mov si, board
    mov di, board
    mov dh, 1

    ResetCounter
    Down
    Right
    Up
    Set
    mov cx, BOARD_WIDTH - 2
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
    sub si, BOARD_WIDTH - 1

    BeginCounterLoopAsc y, dl, 1
        ResetCounter
        Down
        Right
        Up
        Up
        Left
        Set
        add si, BOARD_WIDTH + 1
        BeginCounterLoopAsc x, cl, 1
            ResetCounter
            Up
            Left
            Down
            Down
            Right
            Right
            Up
            Up
            Set
            add si, BOARD_WIDTH
        EndCounterLoopAsc x, cl, BOARD_WIDTH - 1
        ResetCounter
        Up
        Left
        Down
        Down
        Right
        Set
        sub si, BOARD_WIDTH - 1
    EndCounterLoopAsc y, dl, BOARD_HEIGHT - 1

    ResetCounter
    Up
    Right
    Down
    Set
    mov cx, BOARD_WIDTH - 2
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
    mov cx, BOARD_WIDTH * BOARD_HEIGHT / UNROLL_TIMES
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

seed    resb BOARD_WIDTH * BOARD_HEIGHT / 8
        .end:
board   resb BOARD_WIDTH * BOARD_HEIGHT
        .end:
