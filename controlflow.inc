; ~ name reg times
%macro BeginCounterLoopDesc 3
    mov %2, %3
.Loop_%1:
%endmacro

; ~ name reg
%macro EndCounterLoopDesc 2
    dec %2
    jnz .Loop_%1
%endmacro
