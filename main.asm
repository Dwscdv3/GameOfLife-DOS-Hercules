cpu 8086

org 0x100
start_of_image:
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

start:
    call hercules_protection_off
    call hercules_graphics_mode

    call get_arg0
    OpenFile si, READ_ONLY
    mov bx, ax
    ReadFile bx, seed, PACKED_SIZE
    CloseFile bx

reset:
    mov ax, ss
    mov ds, ax
    add ax, (0x100 + end_of_image - start_of_image + PACKED_SIZE) >> 4
    mov es, ax
    mov si, seed
    xor di, di
    mov ah, 10000000b
.loop_start:
    cmp di, UNPACKED_SIZE
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
    mov ax, es
    mov ds, ax
    call draw
    mov ax, ds
    add ax, 0x1000
    mov es, ax
    call update
    mov ax, es
    mov ds, ax
    call draw
    mov ax, ds
    sub ax, 0x1000
    mov es, ax
    call update
    jmp main

draw:
    mov ax, SEG_FRAMEBUFFER_1
    mov es, ax
    xor si, si
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
    EndCounterLoopDesc y, dl

    ret

update:
    %macro Count 1
        %1 ah, [si]
    %endmacro

    %macro Set 0
        cmp ah, 3
        jb %%die
        mov al, dh
        je %%end
        cmp ah, 4
        mov al, [di]
        je %%end
    %%die:
        xor al, al
    %%end:
        stosb
    %endmacro

    %macro Up 1
        sub si, bp
        Count %1
    %endmacro

    %macro Down 1
        add si, bp
        Count %1
    %endmacro

    %macro Left 1
        dec si
        Count %1
    %endmacro

    %macro Left2 1
        dec si
        Left %1
    %endmacro

    %macro Right 1
        inc si
        Count %1
    %endmacro

    %macro Right3 1
        add si, bx
        Count %1
    %endmacro

    %define ResetCounter xor ah, ah

    %macro ConvolveRowWithHeight 1
        ResetCounter
        Count add
        %rep %1 - 1
            Down add
        %endrep
        Right add
        %rep %1 - 1
            Up add
        %endrep
        Set
        Right add
        %rep %1 - 1
            Down add
        %endrep
        Set
        mov cl, BOARD_WIDTH - 3
        %%loop_start:
            Left2 sub
            %rep %1 - 1
                Up sub
            %endrep
            Right3 add
            %rep %1 - 1
                Down add
            %endrep
            Set
        loop %%loop_start
        Left2 sub
        %rep %1 - 1
            Up sub
        %endrep
        Set
    %endmacro

    xor cx, cx
    xor si, si
    xor di, di
    mov dh, 1
    mov bp, BOARD_WIDTH
    mov bx, 3

    ConvolveRowWithHeight 2
    xor si, si
    BeginCounterLoopDesc y, dl, BOARD_HEIGHT - 2
        ConvolveRowWithHeight 3
        add si, bx
    EndCounterLoopDesc y, dl
    ConvolveRowWithHeight 2

    ret

seed:

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
    cmp byte [di], ' '
    je .terminate_string
    cmp byte [di], 0x0D
    je .terminate_string
    inc di
    jmp .tokenize
.terminate_string:
    mov byte [di], 0
    ret

end_of_image:
