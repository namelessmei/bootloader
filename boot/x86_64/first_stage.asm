[BITS 16]
[ORG 0x7C00]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl

    mov ax, 0x0203
    mov cx, 0x0002
    xor dh, dh
    mov bx, 0x7E00
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    mov si, success_msg
    call print_string

    db 0xEA
    dw 0x0000, 0x07E0

disk_error:
    mov si, error_msg
    call print_string
    mov al, ah
    call print_hex
    cli
.halt:
    hlt
    jmp short .halt

print_string:
    pushf
    cld
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp short .loop
.done:
    popf
    ret

print_hex:
    push ax
    mov dl, al
    shr al, 4
    call print_nibble
    mov al, dl
    and al, 0x0F
    call print_nibble
    pop ax
    ret

print_nibble:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .print
    add al, 7
.print:
    mov ah, 0x0E
    int 0x10
    ret

boot_drive:    db 0
success_msg:   db "OK", 0
error_msg:     db "ERR:", 0

times 510-($-$$) db 0
dw 0xAA55
