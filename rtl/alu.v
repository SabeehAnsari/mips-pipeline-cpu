//==========================================================================
//  alu.v  -  32-bit arithmetic and logic unit
//
//  TRACK A.  Twelve operations, selected by alu_ctrl. Purely combinational.
//
//  Read this before you start:
//
//   * For the three SHIFT operations the shift AMOUNT arrives on port a and
//     the value being SHIFTED arrives on port b. This is deliberate - the
//     datapath puts shamt on the a input via the ShamtSrc mux. Only the low
//     five bits of a are used.
//
//   * SRA must fill with the sign bit. In Verilog the >>> operator only does
//     that when the left operand is declared signed, so use $signed(b) >>> ...
//     A plain b >>> n behaves exactly like >> and the test will fail.
//
//   * SLTU must compare without sign. A plain a < b on two reg [31:0] values
//     is already unsigned in Verilog; it is SLT that needs $signed on both.
//
//   * zero is used by beq and bne. It is already written for you.
//
//  Fill in the case statement. Nothing else in this file needs to change.
//==========================================================================
`include "defines.vh"

module alu (
    input  wire [31:0] a,          // operand A  (or shift amount in a[4:0])
    input  wire [31:0] b,          // operand B  (value shifted, for shifts)
    input  wire [3:0]  alu_ctrl,   // operation select - see defines.vh
    output reg  [31:0] result,
    output wire        zero        // asserted when result == 0
);

    assign zero = (result == 32'd0);

    always @(*) begin
        case (alu_ctrl)
            `ALU_ADD  : result = a + b;
            `ALU_SUB  : result = a - b;
            `ALU_AND  : result = a & b;
            `ALU_OR   : result = a | b;
            `ALU_XOR  : result = a ^ b;
            `ALU_NOR  : result = ~(a | b);
            `ALU_SLT  : result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            `ALU_SLTU : result = (a < b)                   ? 32'd1 : 32'd0;
            `ALU_SRA  : result = $signed(b) >>> a[4:0];
            `ALU_SLL  : result = b << a[4:0];
            `ALU_SRL  : result = b >> a[4:0];
            `ALU_SRA  : result = b >>> a[4:0];
            `ALU_LUI  : result = b << 16;
            default   : result = 32'd0;
        endcase
    end

endmodule
