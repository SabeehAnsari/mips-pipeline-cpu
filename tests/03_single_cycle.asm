# =====================================================================
#  03_single_cycle.asm   -  integration test for the single-cycle CPU
#
#  MARS settings required:
#     pseudo-instructions OFF, delayed branching OFF
#     memory configuration: Compact, Text at Address 0
#
#  Exercises 18 of the 27 instructions end to end: every ALU class,
#  both shift directions, lui/ori to build a 32-bit constant, a store
#  followed by a load, a branch not taken, a branch taken, and the
#  full jal / jr / j sequence.
#
#  There are no hazards to worry about here - a single-cycle machine
#  completes each instruction before starting the next. This program
#  is reused later to check the pipelined version produces identical
#  results, which is the point: same program, same answers, fewer
#  cycles.
#
#  The program ends in a self-loop. The testbench runs a fixed number
#  of cycles and then checks the register file.
#
#  EXPECTED FINAL REGISTER STATE
#     $t0  = 0x0000000A    10
#     $t1  = 0x00000003    3
#     $t2  = 0x0000000D    13     t0 + t1
#     $t3  = 0x00000007    7      t0 - t1
#     $t4  = 0x00000002    2      t0 & t1
#     $t5  = 0x0000000B    11     t0 | t1
#     $t6  = 0x00000009    9      t0 ^ t1
#     $t7  = 0x00000028    40     t0 << 2
#     $s0  = 0x00000005    5      t0 >> 1
#     $s1  = 0x00000001    1      t1 < t0
#     $s2  = 0x12345678           lui then ori
#     $s3  = 0x00002000           data segment base
#     $s4  = 0x0000000D    13     loaded back from memory
#     $s5  = 0x00000001    1      branch not taken, so this ran
#     $s6  = 0x00000000    0      branch taken, so this was skipped
#     $s7  = 0x00000007    7      reached after returning from func
#     $t8  = 0x00000037    55     set inside func
#     $ra  = 0x00000050           return address left by jal
#
#  All other registers remain zero.
#
#     memory[0x00002000] = 13
# =====================================================================

        .text
        addi $t0, $zero, 10
        addi $t1, $zero, 3

        add  $t2, $t0, $t1          # 13
        sub  $t3, $t0, $t1          # 7
        and  $t4, $t0, $t1          # 2
        or   $t5, $t0, $t1          # 11
        xor  $t6, $t0, $t1          # 9
        sll  $t7, $t0, 2            # 40
        srl  $s0, $t0, 1            # 5
        slt  $s1, $t1, $t0          # 1

        lui  $s2, 0x1234            # build a 32-bit constant
        ori  $s2, $s2, 0x5678       # 0x12345678

        addi $s3, $zero, 0x2000     # data segment base
        sw   $t2, 0($s3)            # store 13
        lw   $s4, 0($s3)            # read it back

        beq  $t0, $t1, skip         # 10 != 3, not taken
        addi $s5, $zero, 1          # so this runs
skip:
        bne  $t0, $t1, target       # 10 != 3, taken
        addi $s6, $zero, 99         # so this is skipped
target:
        jal  func                   # $ra <- address of the next instruction
        addi $s7, $zero, 7          # runs after jr returns here
        j    done

func:
        addi $t8, $zero, 55
        jr   $ra

done:
        j    done                   # halt
