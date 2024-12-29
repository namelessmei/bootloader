#define VGA_WIDTH 80
#define VGA_HEIGHT 25
#define VGAMEMORY ((volatile unsigned short*) 0xB8000)

void clear_vga_buffer(unsigned char color)
{
    unsigned short blank = (color << 8) | ' ';
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; ++i)
    {
        VGAMEMORY[i] = blank;
    }
}

void kernel_main()
{
    unsigned char default_color = 0x0F;

    clear_vga_buffer(default_color);

    const char* msg = "Hello World!";

    for (int i = 0; msg[i] != '\0'; ++i)
    {
        VGAMEMORY[i] = (default_color << 8) | msg[i];
    }

    while (1)
    {
        __asm__("hlt");
    }
}
