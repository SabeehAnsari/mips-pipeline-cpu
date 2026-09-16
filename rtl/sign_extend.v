//==========================================================================
//  sign_extend.v  -  16 to 32 bit immediate extender
//
//  TRACK A.  The smallest module in the project. Two lines.
//
//  MIPS immediates are 16 bits but the ALU is 32 bits, so the gap has to
//  be filled. How it is filled depends on the instruction:
//
//    EXT_SIGN  - replicate bit 15 into the top 16 bits, so that a negative
//                immediate stays negative.  addi $t0,$t1,-1 must produce
//                0xFFFFFFFF, not 0x0000FFFF.
//    EXT_ZERO  - fill the top 16 bits with zeros. The logical immediate
//                instructions (andi, ori, xori) treat the immediate as a
//                bit pattern, not a number, so sign extension would be wrong.
//
//  Verilog's replication operator makes this a one-liner:
//      {16{imm[15]}}          is bit 15 repeated sixteen times
//      {16'd0, imm}           is sixteen zeros followed by imm
//      {a, b}                 concatenates a and b
//
//  Write it as a single continuous assign with a ternary on ext_op.
//==========================================================================
`include "defines.vh"

module sign_extend (
    input  wire [15:0] imm,
    input  wire        ext_op,     // EXT_ZERO or EXT_SIGN
    output wire [31:0] out
);

    assign out = (ext_op == `EXT_SIGN) ? {{16{imm[15]}}, imm} : {16'h0000, imm};

endmodule