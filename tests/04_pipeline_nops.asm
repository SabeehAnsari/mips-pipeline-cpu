# =====================================================================
#  04_pipeline_nops.asm   -  pipeline structure test, hazards avoided
#
#  STEP 6 of the build order. At this point the pipeline registers exist
#  but nothing handles hazards, so this program avoids creating any.
#
#  The padding rules, and why:
#
#    3 nops between an instruction and anything that reads its result.
#        A result is written in WB, five stages after fetch. With three
#        nops in between, the consuming instruction reaches ID in the
#        same cycle the producer reaches WB - and because the register
#        file writes on the falling edge, the read sees the new value.
#
#    3 nops after every branch and jump.
#        Branches resolve in MEM. By then three instructions behind the
#        branch have already been fetched. Without flush logic they will
#        execute, so they must be harmless.
#
#  If this program produces the right answers, your pipeline registers
#  move data correctly and every stage is wired to the right place.
#  Forwarding, stalling and flushing come next, and their job is to let
#  you delete all of this padding.
#
#  EXPECTED FINAL REGISTER STATE
#     $t0 = 0x00000014    20
#     $t1 = 0x00000006    6
#     $t2 = 0x0000001A    26     t0 + t1
#     $t3 = 0x0000000E    14     t0 - t1
#     $t4 = 0x00002000           data base
#     $t5 = 0x0000001A    26     stored then loaded back
#     $t6 = 0x00000001    1      reached only if the branch was taken
#     $t7 = 0x00000000    0      skipped by the branch
#     $ra = 0x00000088           return address from jal
#     $s0 = 0x00000063    99     set inside func
#     $s1 = 0x00000005    5      runs after jr returns
#
#     memory[0x00002000] = 26
# =====================================================================

        .text
        addi $t0, $zero, 20
        addi $t1, $zero, 6
        nop
        nop

        add  $t2, $t0, $t1          # 26
        nop
        nop
        nop

        sub  $t3, $t0, $t1          # 14
        nop
        nop
        nop

        addi $t4, $zero, 0x2000     # data base
        nop
        nop
        nop

        sw   $t2, 0($t4)
        nop
        nop
        nop

        lw   $t5, 0($t4)            # 26
        nop
        nop
        nop

        bne  $t0, $t1, taken        # 20 != 6, taken
        nop
        nop
        nop
        addi $t7, $zero, 77         # must not run

taken:
        addi $t6, $zero, 1
        nop
        nop
        nop

        jal  func
        nop
        nop
        nop
        addi $s1, $zero, 5          # runs after the return

        j    done
        nop
        nop
        nop

func:
        addi $s0, $zero, 99
        nop
        nop
        nop
        jr   $ra
        nop
        nop
        nop

done:
        j    done                   # halt
        nop
        nop
        nop
