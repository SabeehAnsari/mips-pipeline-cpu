//==========================================================================
//  dmem.v  -  data memory
//
//  TRACK A.  Word addressed, combinational read, clocked write.
//
//  Two things to get right:
//
//  1. THE BASE OFFSET.  Your MARS configuration puts the data segment at
//     0x00002000, so a program's first word lives at that address, not at
//     zero. Subtract `DATA_BASE before indexing, or the array would need
//     to be 2048 words of mostly nothing.
//
//  2. INDEXING.  As with imem, the address is in bytes and the array is in
//     words, so shift right by two. Combining both:
//
//         index = (addr - `DATA_BASE) >> 2
//
//     A local wire for the index keeps the read and the write consistent -
//     computing it twice is how the two end up disagreeing.
//
//  Writes happen on the rising clock edge when we is high. Reads are
//  combinational, so a load produces its data in the same cycle it is
//  presented with an address.
//
//  re is provided for completeness and to match the datapath; a
//  combinational read does not strictly need it.
//==========================================================================
`include "defines.vh"

module dmem (
    input  wire        clk,
    input  wire [31:0] addr,
    input  wire [31:0] wd,
    input  wire        we,
    input  wire        re,
    output wire [31:0] rd
);

    reg [31:0] mem [0:`DMEM_WORDS-1];

    integer i;
    initial begin
        for (i = 0; i < `DMEM_WORDS; i = i + 1) mem[i] = 32'd0;
    end

    // Word index, accounting for the data segment base
    wire [31:0] index = (addr - `DATA_BASE) >> 2;

    // Combinational read
    assign rd = mem[index];

    // Synchronous write on the rising edge when we is high
    always @(posedge clk) begin
        if (we) begin
            mem[index] <= wd;
        end
    end

endmodule