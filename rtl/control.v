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
//    * default all outputs to a safe value at the top of the always block,
//      then override per instruction. A safe default means reg_write = 0 and
//      mem_write = 0, so that an unknown opcode cannot corrupt state.
//    * the R-type opcode is shared by 14 instructions - switch on funct
//      inside that branch.
//    * for don't-care cells in the table, drive 0 rather than leaving the
//      signal unassigned; an unassigned reg in an always @(*) block infers
//      a latch, which Vivado will warn about and which will bite you later.
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
                    // Arithmetic & Logical R-Type
                    `FN_ADD: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_ADD;
                    end
                    `FN_ADDU: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_ADD;
                    end
                    `FN_SUB: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_SUB;
                    end
                    `FN_SUBU: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_SUB;
                    end
                    `FN_AND: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_AND;
                    end
                    `FN_OR: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_OR;
                    end
                    `FN_XOR: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_XOR;
                    end
                    `FN_NOR: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_NOR;
                    end
                    `FN_SLT: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_SLT;
                    end
                    `FN_SLTU: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        alu_ctrl  = `ALU_SLTU;
                    end

                    // Shift R-Type Instructions
                    `FN_SLL: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        shamt_src = 1'b1;
                        alu_ctrl  = `ALU_SLL;
                    end
                    `FN_SRL: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        shamt_src = 1'b1;
                        alu_ctrl  = `ALU_SRL;
                    end
                    `FN_SRA: begin
                        reg_dst   = `DST_RD;
                        reg_write = 1'b1;
                        shamt_src = 1'b1;
                        alu_ctrl  = `ALU_SRA;
                    end

                    // Jump Register R-Type
                    `FN_JR: begin
                        jump = `JMP_JR;
                    end

                    default: ;   // unknown funct - leave the safe defaults
                endcase
            end

            // Arithmetic & Logical Immediate Instructions
            `OP_ADDI: begin
                alu_src   = 1'b1;
                ext_op    = `EXT_SIGN;
                reg_write = 1'b1;
                alu_ctrl  = `ALU_ADD;
            end
            `OP_ADDIU: begin
                alu_src   = 1'b1;
                ext_op    = `EXT_SIGN;
                reg_write = 1'b1;
                alu_ctrl  = `ALU_ADD;
            end
            `OP_SLTI: begin
                alu_src   = 1'b1;
                ext_op    = `EXT_SIGN;
                reg_write = 1'b1;
                alu_ctrl  = `ALU_SLT;
            end
            `OP_ANDI: begin
                alu_src   = 1'b1;
                ext_op    = `EXT_ZERO;
                reg_write = 1'b1;
                alu_ctrl  = `ALU_AND;
            end
            `OP_ORI: begin
                alu_src   = 1'b1;
                ext_op    = `EXT_ZERO;
                reg_write = 1'b1;
                alu_ctrl  = `ALU_OR;
            end
            `OP_XORI: begin
                alu_src   = 1'b1;
                ext_op    = `EXT_ZERO;
                reg_write = 1'b1;
                alu_ctrl  = `ALU_XOR;
            end
            `OP_LUI: begin
                alu_src   = 1'b1;
                ext_op    = `EXT_ZERO;
                reg_write = 1'b1;
                alu_ctrl  = `ALU_LUI;
            end

            // Memory Access Instructions
            `OP_LW: begin
                alu_src    = 1'b1;
                ext_op     = `EXT_SIGN;
                mem_read   = 1'b1;
                reg_write  = 1'b1;
                mem_to_reg = `WB_MEM;
                alu_ctrl   = `ALU_ADD;
            end
            `OP_SW: begin
                alu_src   = 1'b1;
                ext_op    = `EXT_SIGN;
                mem_write = 1'b1;
                alu_ctrl  = `ALU_ADD;
            end

            // Branch Instructions
            `OP_BEQ: begin
                branch   = `BR_EQ;
                alu_ctrl = `ALU_SUB;
            end
            `OP_BNE: begin
                branch   = `BR_NE;
                alu_ctrl = `ALU_SUB;
            end

            // Jump Instructions
            `OP_J: begin
                jump = `JMP_J;
            end
            `OP_JAL: begin
                jump       = `JMP_J;
                reg_dst    = `DST_RA;
                reg_write  = 1'b1;
                mem_to_reg = `WB_PC4;
            end

            default: ;   // unknown opcode - behaves as a nop
        endcase
    end

endmodule