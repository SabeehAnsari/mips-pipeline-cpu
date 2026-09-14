# =====================================================================
#  01_load_use.asm   -  load-use hazard
#
#  MARS settings required:
#     pseudo-instructions OFF, delayed branching OFF
#     memory configuration: Compact, Text at Address 0
#
#  What this tests:
#     The lw result is not available until the MEM stage, but the next
#     instruction needs it in EX. Forwarding cannot move data backwards
#     in time, so the hazard unit must insert exactly one bubble.
#     The instruction after that needs the same value but is far enough
#     behind that plain forwarding is enough - no second stall.
#
#  EXPECTED FINAL STATE   (fill in from MARS, then commit this file)
#     $t0 = 0x00002000
#     $t1 = 0x0000002A      42
#     $t2 = 0x0000002A      42
#     $t3 = 0x0000002B      43
# =====================================================================

        .data
val:    .word   42

        .text
        addi $t0, $zero, 0x2000     # base address of .data
        lw   $t1, 0($t0)            # $t1 <- 42, ready only after MEM
        addi $t2, $t1, 0            # immediate use  -> must stall 1 cycle
        addi $t3, $t1, 1            # second use     -> forwarding only
