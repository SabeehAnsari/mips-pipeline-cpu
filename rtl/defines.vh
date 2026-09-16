//==========================================================================
//  defines.vh  -  shared constants for the MIPS32 pipelined CPU
//
//  Every module includes this file. Never write a raw magic number in the
//  RTL; add it here and use the name, so that a change is made in one place.
//==========================================================================
`ifndef MIPS_DEFINES_VH
`define MIPS_DEFINES_VH

//--------------------------------------------------------------- opcodes
`define OP_RTYPE  6'b000000
`define OP_J      6'b000010
`define OP_JAL    6'b000011
`define OP_BEQ    6'b000100
`define OP_BNE    6'b000101
`define OP_ADDI   6'b001000
`define OP_ADDIU  6'b001001
`define OP_SLTI   6'b001010
`define OP_ANDI   6'b001100
`define OP_ORI    6'b001101
`define OP_XORI   6'b001110
`define OP_LUI    6'b001111
`define OP_LW     6'b100011
`define OP_SW     6'b101011

//----------------------------------------------- funct codes (R-type)
`define FN_SLL    6'b000000
`define FN_SRL    6'b000010
`define FN_SRA    6'b000011
`define FN_JR     6'b001000
`define FN_ADD    6'b100000
`define FN_ADDU   6'b100001
`define FN_SUB    6'b100010
`define FN_SUBU   6'b100011
`define FN_AND    6'b100100
`define FN_OR     6'b100101
`define FN_XOR    6'b100110
`define FN_NOR    6'b100111
`define FN_SLT    6'b101010
`define FN_SLTU   6'b101011

//--------------------------------------------------- ALU operations
`define ALU_ADD   4'b0000
`define ALU_SUB   4'b0001
`define ALU_AND   4'b0010
`define ALU_OR    4'b0011
`define ALU_XOR   4'b0100
`define ALU_NOR   4'b0101
`define ALU_SLT   4'b0110
`define ALU_SLTU  4'b0111
`define ALU_SLL   4'b1000
`define ALU_SRL   4'b1001
`define ALU_SRA   4'b1010
`define ALU_LUI   4'b1011
`define ALU_NOP   4'b0000   // don't-care rows use ADD

//------------------------------------------------- control encodings
`define DST_RT    2'b00
`define DST_RD    2'b01
`define DST_RA    2'b10     // $31, for jal

`define WB_ALU    2'b00
`define WB_MEM    2'b01
`define WB_PC4    2'b10     // PC+4, for jal

`define BR_NONE   2'b00
`define BR_EQ     2'b01
`define BR_NE     2'b10

`define JMP_NONE  2'b00
`define JMP_J     2'b01     // j and jal - target from instruction
`define JMP_JR    2'b10     // jr        - target from rs

`define EXT_ZERO  1'b0
`define EXT_SIGN  1'b1

//------------------------------------------------- forwarding select
`define FWD_REG   2'b00     // straight from the register file
`define FWD_WB    2'b01     // from MEM/WB - the write-back value
`define FWD_MEM   2'b10     // from EX/MEM - the newer ALU result

//------------------------------------------------- memory geometry
//  MARS "Compact, Text at Address 0" configuration
`define TEXT_BASE 32'h0000_0000
`define DATA_BASE 32'h0000_2000
`define IMEM_WORDS 1024
`define DMEM_WORDS 1024

`endif
