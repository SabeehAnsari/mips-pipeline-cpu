# =====================================================================
#  05_hazards.asm   -  the unpadded program
#
#  This is what the whole project is for. Not a single nop between
#  dependent instructions, not a single nop after a branch. Every
#  hazard is real and the hardware has to handle it:
#
#    forwarding at distance 1 and distance 2, on both operands
#    a store whose address register was written the cycle before
#    a load followed immediately by a use          -> one stall
#    a branch not taken                            -> no flush
#    a branch taken with three live instructions behind it -> flush
#    jal / jr, with the instruction after jal executing on return
#
#  The same program runs on cpu_single and cpu_pipelined and must
#  produce identical results. That equality, and the cycle counts
#  either side of it, is the headline result of the report.
#
#  The last real instruction stores 0xDEADBEEF to 0x00002004. The
#  testbench watches for that write to know exactly when each CPU
#  finished, which is how the cycle counts are measured.
#
#  EXPECTED FINAL REGISTER STATE
#     $t0 = 10          $s0 = 6            $t8 = 42
#     $t1 = 3           $s1 = 1            $t9 = 99
#     $t2 = 13          $s2 = 0x12345678   $a0 = 0xDEADBEEF
#     $t3 = 10          $s3 = 0x2000       $ra = return address
#     $t4 = 8           $s4 = 13
#     $t5 = 15          $s5 = 14
#     $t6 = 7           $s6 = 1
#     $t7 = 52          $s7 = 0    <- stays zero only if flush works
#
#     memory[0x2000] = 13
#     memory[0x2004] = 0xDEADBEEF
# =====================================================================

        .text
        addi $t0, $zero, 10
        addi $t1, $zero, 3

        add  $t2, $t0, $t1          # forward $t1 at distance 1, $t0 at 2
        sub  $t3, $t2, $t1          # forward $t2 at distance 1
        and  $t4, $t2, $t3          # forward $t3 at 1 and $t2 at 2
        or   $t5, $t2, $t3
        xor  $t6, $t2, $t3
        sll  $t7, $t2, 2
        srl  $s0, $t2, 1
        slt  $s1, $t1, $t0

        lui  $s2, 0x1234
        ori  $s2, $s2, 0x5678       # forward at distance 1

        addi $s3, $zero, 0x2000
        sw   $t2, 0($s3)            # address register written last cycle
        lw   $s4, 0($s3)
        addi $s5, $s4, 1            # LOAD-USE - one stall is unavoidable

        beq  $t0, $t1, no_skip      # not taken, no flush
        addi $s6, $zero, 1          # so this runs

no_skip:
        bne  $t0, $t1, taken        # taken - the next three are killed
        addi $s7, $zero, 55
        addi $s7, $zero, 56
        addi $s7, $zero, 57

taken:
        jal  func
        addi $t8, $zero, 42         # runs after jr returns here
        j    done
        nop
        nop

func:
        addi $t9, $zero, 99
        jr   $ra

done:
        lui  $a0, 0xDEAD
        ori  $a0, $a0, 0xBEEF
        sw   $a0, 4($s3)            # sentinel - the testbench watches for this

halt:
        j    halt
