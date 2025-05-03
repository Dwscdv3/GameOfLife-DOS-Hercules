HERCULES_INDEX   equ 0x03B4
HERCULES_CONTROL equ 0x03B8
HERCULES_SWITCH  equ 0x03BF

HERCULES_SCRN_ON equ 00001000b
HERCULES_GRPH    equ 00000010b


section .data

hercules_gtable:
    db 0x35, 0x2D, 0x2E, 0x07
    db 0x5B, 0x02, 0x57, 0x57
    db 0x02, 0x03, 0x00, 0x00


section .text

hercules_protection_off:
    mov dx, HERCULES_SWITCH
    mov al, 3
    out dx, al
    ret

hercules_graphics_mode:
    mov al, HERCULES_GRPH
    lea si, hercules_gtable
    mov bx, 0
    mov cx, 0x4000
    jmp hercules_set_mode

hercules_set_mode:
    push es
    push ax
    push bx
    push cx

    mov dx, HERCULES_CONTROL
    out dx, al

    mov dx, HERCULES_INDEX
    mov cx, 12
    xor ah, ah

.parms:
    mov al, ah
    out dx, al

    inc dx
    lodsb
    out dx, al

    inc ah
    dec dx
    loop .parms

    pop cx
    mov ax, 0xB000
    cld

    mov es, ax
    xor di, di
    pop ax
    rep stosw

    mov dx, HERCULES_CONTROL
    pop ax
    add al, HERCULES_SCRN_ON
    out dx, al

    pop es
    ret
