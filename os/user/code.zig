pub export fn userEntry() linksection(".user") callconv(.naked) noreturn {
    asm volatile (
        \\ li a7, 0
        \\ ecall
        \\ 1:
        \\ j 1b
    );
}
