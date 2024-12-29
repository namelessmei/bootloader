[BITS 16]
[ORG 0x7E00]

KERNEL_HIGH      equ 0xFFFFFFFF80000000
KERNEL_SEG       equ 0x1000
KERNEL_OFF       equ 0x0000
KERNEL_LOW       equ (KERNEL_SEG << 4) + KERNEL_OFF
VGA_MEM         equ 0xB8000

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000
    mov si, msg_stage2
    call print_rm
    call enable_a20
    call load_kernel
    call enter_pm

print_rm:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_rm
.done:
    ret

load_kernel:
    mov ax, 0x0240
    xor ch, ch
    mov cl, 5
    xor dh, dh
    push KERNEL_SEG
    pop es
    mov bx, KERNEL_OFF
    int 0x13
    jc disk_error
    ret

enable_a20:
    push ax
    in al, 0x92
    or al, 2
    out 0x92, al
    pop ax
    ret

enter_pm:
    xchg bx, bx
    cli
    lgdt [gdt32_desc]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:pm_entry

disk_error:
    mov si, msg_disk_err
    call print_rm
    cli
    hlt

; Group 32-bit code
[BITS 32]
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x200000
    mov esi, msg_pm
    call print_pm
    call setup_paging
    lgdt [gdt64_desc]
    call enter_lm
    jmp 0x08:lm_entry

print_pm:
    push eax
    push ebx
    mov ebx, VGA_MEM
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0F
    mov [ebx], ax
    add ebx, 2
    jmp .loop
.done:
    pop ebx
    pop eax
    ret

setup_paging:
    mov edi, 0x1000
    xor eax, eax
    mov ecx, 5 * 4096 / 4
    rep stosd
    mov dword [0x1000], 0x00002003
    mov dword [0x2000], 0x00003003
    mov dword [0x3000], 0x00000083
    mov dword [0x1000 + 8 * ((KERNEL_HIGH >> 39) & 0x1FF)], 0x00004003
    mov dword [0x4000 + 8 * ((KERNEL_HIGH >> 30) & 0x1FF)], 0x00005003
    mov dword [0x5000 + 8 * ((KERNEL_HIGH >> 21) & 0x1FF)], 0x00000083
    mov edi, 0x1000
    mov cr3, edi
    ret

enter_lm:
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr
    mov eax, 10100000b
    mov cr4, eax
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax
    ret

; Group 64-bit code
[BITS 64]
lm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000 + KERNEL_HIGH
    mov rsi, msg_lm
    call print_lm
    mov rax, KERNEL_HIGH + KERNEL_LOW
    jmp rax

print_lm:
    push rax
    push rbx
    mov rbx, VGA_MEM
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0F
    mov [rbx], ax
    add rbx, 2
    jmp .loop
.done:
    pop rbx
    pop rax
    ret

; Data section at the end
msg_stage2:    db 'Stage 2 loaded', 13, 10, 0
msg_disk_err:  db 'Disk error', 13, 10, 0
msg_lm:        db 'In long mode', 0
msg_pm:        db 'In protected mode', 0

; GDT structures at the very end since they're accessed less frequently
align 16
gdt32:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt32_end:

gdt32_desc:
    dw gdt32_end - gdt32 - 1
    dd gdt32

align 16
gdt64:
    dq 0
    dq 0x00AF9A000000FFFF
    dq 0x00AF92000000FFFF
gdt64_end:

gdt64_desc:
    dw gdt64_end - gdt64 - 1
    dq gdt64
