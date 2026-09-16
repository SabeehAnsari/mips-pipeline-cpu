//==========================================================================
//  imem.v  -  instruction memory (read only)
//
//  TRACK A.  A word-addressed ROM loaded from a hex file at time zero.
//
//  The one thing to get right is INDEXING. The PC counts in BYTES and
//  increments by 4, but this array is indexed in WORDS. So the array
//  index is the address shifted right by two - which in Verilog you take
//  as a bit slice rather than an actual shift:
//
//      addr[11:2]     for a 1024-word memory
//
//  Feeding the byte address straight in reads every fourth word and
//  produces nonsense that looks like a decoder bug.
//
//  Reads are combinational - the instruction appears in the same cycle
//  the PC presents its address. Real instruction memory is synchronous,
//  but for this project a combinational read keeps the single-cycle
//  design honest and the pipeline simple.
//
//  INIT_FILE is a parameter so different tests can load different
//  programs without editing this file.
//
//  You will see a warning like "Not enough words in the file for the
//  requested range [0:1023]". That is expected and harmless - the test
//  program is far shorter than the memory, and the remaining words stay
//  at the zeros they were initialised to.
//==========================================================================
`include "defines.vh"

module imem #(
    parameter INIT_FILE = ""
) (
    input  wire [31:0] addr,
    output wire [31:0] instr
);

    reg [31:0] mem [0:`IMEM_WORDS-1];

    integer i;
    initial begin
        for (i = 0; i < `IMEM_WORDS; i = i + 1) mem[i] = 32'd0;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    assign instr = mem[addr[11:2]];

endmodule