READ_ONLY   equ 0
WRITE_ONLY  equ 1
READ_WRITE  equ 2

; ~ path, mode (r, w, rw)
; @modify AX: handle | errno
%macro OpenFile 2
    push dx
    mov dx, %1
    mov al, %2
    mov ah, 0x3D
    int 0x21
    pop dx
    jc fatal
%endmacro

; ~ handle
; @modify AX: errno
%macro CloseFile 1
    push bx
    mov bx, %1
    mov ah, 0x3E
    int 0x21
    pop bx
    jc fatal
%endmacro

; ~ handle, buffer, size
; @modify AX: bytes read | errno
; @modify DX: buffer end
%macro ReadFile 3
    push bx
    push cx
    mov bx, %1
    mov cx, %3
    mov dx, %2
    mov ah, 0x3F
    int 0x21
    pop cx
    pop bx
    jc fatal
%endmacro


section .data

onexit  dw 0


section .text

fatal:
    mov bx, [onexit]
    cmp bx, 0
    jz .skip_handler
    push ax
    call bx
    pop ax
.skip_handler:
    mov ah, 0x4C
    int 0x21
