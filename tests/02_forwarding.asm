# =====================================================================
#  02_forwarding.asm   -  data hazards at every distance
#
#  What this tests:
#     Distance 1  (EX/MEM -> EX)   back-to-back dependency
#     Distance 2  (MEM/WB -> EX)   one instruction in between
#     Both operands forwarded in the same instruction
#     Same register read on both ports
#
#     Priority matters: when a register sits in both EX/MEM and MEM/WB,
#     the newer value in EX/MEM must win. Getting that backwards gives a
#     stale result that looks like an intermittent fault.
#
#     No stalls should occur anywhere in this program. Once the pipeline
#     is full, every instruction here should retire at one per cycle. If
#     your counters show stall cycles, something is stalling that should
#     have been forwarded.
#
#  EXPECTED FINAL STATE   (verify in MARS before trusting these)
#     $t0 = 0x0000000A      10
#     $t1 = 0x00000014      20
#     $t2 = 0x0000001E      30     t0 + t1
#     $t3 = 0x00000032      50     t2 + t1    distance 1 on t2
#     $t4 = 0x00000028      40     t2 + t0    distance 2 on t2
#     $t5 = 0x0000005A      90     t3 + t4    both operands forwarded
#     $t6 = 0x00000064      100    t5 + t0    distance 1 on t5
#     $t7 = 0x00000000      0      t5 - t5    distance 2, both ports
# =====================================================================

        .text
        addi $t0, $zero, 10
        addi $t1, $zero, 20

        add  $t2, $t0, $t1          # 30
        add  $t3, $t2, $t1          # distance 1 on $t2
        add  $t4, $t2, $t0          # distance 2 on $t2
        add  $t5, $t3, $t4          # both operands come from the pipeline
        add  $t6, $t5, $t0          # distance 1 on $t5
        sub  $t7, $t5, $t5          # distance 2, same register both ports
