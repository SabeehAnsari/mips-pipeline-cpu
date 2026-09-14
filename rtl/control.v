//==========================================================================
//  control.v  -  main control decoder
//
//  TRACK B.  This module is a direct transcription of Tables 5a and 5b in
//  the proposal. It is not a design problem - it is a careful copying
//  problem, and every later bug that looks like a datapath fault usually
//  turns out to be one wrong cell in here.
//
//  Note on scope: the proposal lists a separate alu_control module. We have
//  merged it into this decoder, because the decoder already sees both the
//  opcode and the funct field and a second module would just re-decode them.
//  Record this in the mid-term report as a documented simplification.
//
//  How to fill it in:
//   * default all outputs to a safe value at the top of the always block,
//     then override per instruction. A safe default means reg_write = 0 and
//     mem_write = 0, so that an unknown opcode cannot corrupt state.
//   * the R-type opcode is shared by 14 instructions - switch on funct
//     inside that branch.
//   * for don't-care cells in the table, drive 0 rather than leaving the
//     signal unassigned; an unassigned reg in an always @(*) block infers
//     a latch, which Vivado will warn about and which will bite you later.
//==========================================================================
`include "defines.vh"

module control (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,

    // EX stage
    output reg  [1:0] reg_dst,     // DST_RT / DST_RD / DST_RA
    output reg        alu_src,     // 0 = rt data, 1 = extended immediate
    output reg        shamt_src,   // 1 = ALU operand A is shamt
    output reg        ext_op,      // EXT_ZERO / EXT_SIGN
    output reg  [3:0] alu_ctrl,    // ALU_xxx

    // MEM stage
    output reg        mem_read,
    output reg        mem_write,
    output reg  [1:0] branch,      // BR_NONE / BR_EQ / BR_NE
    output reg  [1:0] jump,        // JMP_NONE / JMP_J / JMP_JR

    // WB stage
    output reg        reg_write,
    output reg  [1:0] mem_to_reg   // WB_ALU / WB_MEM / WB_PC4
);

    always @(*) begin
        // safe defaults - nothing writes anything
        reg_dst    = `DST_RT;
        alu_src    = 1'b0;
        shamt_src  = 1'b0;
        ext_op     = `EXT_SIGN;
        alu_ctrl   = `ALU_ADD;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = `BR_NONE;
        jump       = `JMP_NONE;
        reg_write  = 1'b0;
        mem_to_reg = `WB_ALU;

        case (opcode)

            `OP_RTYPE: begin
                case (funct)
                    // TODO  add addu sub subu and or xor nor slt sltu
                    // TODO  sll srl sra   (remember shamt_src = 1)
                    // TODO  jr            (jump = JMP_JR, reg_write = 0)
                    default: ;   // unknown funct - leave the safe defaults
                endcase
            end

            // TODO  addi addiu slti andi ori xori lui
            // TODO  lw sw
            // TODO  beq bne
            // TODO  j jal

            default: ;   // unknown opcode - behaves as a nop
        endcase
    end

endmodule
