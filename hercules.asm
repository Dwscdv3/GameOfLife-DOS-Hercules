hercules_index   equ 0x03B4
hercules_control equ 0x03B8
hercules_switch  equ 0x03BF

hercules_scrn_on equ 00001000b
hercules_grph    equ 00000010b
hercules_text    equ 00100000b


section .data

hercules_gtable:
    db 0x35, 0x2D, 0x2E, 0x07
    db 0x5B, 0x02, 0x57, 0x57
    db 0x02, 0x03, 0x00, 0x00

hercules_ttable:
    db 0x61, 0x50, 0x52, 0x0F
    db 0x19, 0x06, 0x19, 0x19
    db 0x02, 0x0D, 0x0B, 0x0C

hercules_page   db 0


section .text

hercules_protection_off:
    mov dx, hercules_switch
    mov al, 3
    out dx, al
    ret

hercules_page_flip:
    push dx
    mov al, [cs: hercules_page]
    xor al, 1
    mov [cs: hercules_page], al
    mov cl, 7
    shl al, cl
    or al, hercules_grph | hercules_scrn_on
    mov dx, hercules_control
    out dx, al
    pop dx
    ret

hercules_gmode:
    mov al, hercules_grph
    lea si, hercules_gtable
    mov bx, 0
    mov cx, 0x4000
    call hercules_setmd
    ret

hercules_tmode:
    mov al, hercules_text
    lea si, hercules_ttable
    mov bx, 0x720
    mov cx, 0x2000
    call hercules_setmd
    ret

hercules_setmd:
    push es
    push ax
    push bx
    push cx

    mov dx, hercules_control
    out dx, al

    mov ax, ds
    mov es, ax
    mov dx, hercules_index
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

    mov dx, hercules_control
    pop ax
    add al, hercules_scrn_on
    out dx, al

    pop es
    ret
