; ~ name reg
%macro BeginCounterLoopAsc 3
    mov %2, %3
.Loop_%1:
%endmacro

; ~ name reg times
%macro EndCounterLoopAsc 3
    inc %2
    cmp %2, %3
    jb .Loop_%1
%endmacro
