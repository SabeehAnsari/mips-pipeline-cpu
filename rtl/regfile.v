//==========================================================================
//  regfile.v  -  32 x 32-bit register file
//
//  TRACK A.  Two read ports, one write port.
//
//  Two rules that are easy to miss and expensive to debug:
//
//   1. WRITE ON THE NEGATIVE CLOCK EDGE.
//      In the pipeline, an instruction in WB writes the same register that
//      an instruction in ID is reading, in the same cycle. Writing on negedge
//      means the write lands in the first half of the cycle and the read in
//      the second half sees the new value. If you write on posedge instead,
//      your forwarding logic can be perfectly correct and the CPU will still
//      produce wrong answers.
//
//   2. REGISTER 0 IS ALWAYS ZERO.
//      Reads of register 0 return 0 no matter what. Writes to register 0 are
//      silently discarded. Do not special-case this in the reader only - if a
//      write to r0 ever lands, forwarding will later hand out a stale value.
//
//  Reads are combinational (asynchronous). Writes are clocked.
//==========================================================================
`include "defines.vh"

module regfile (
    input  wire        clk,
    input  wire [4:0]  ra1,        // read address 1  (rs)
    input  wire [4:0]  ra2,        // read address 2  (rt)
    input  wire [4:0]  wa,         // write address
    input  wire [31:0] wd,         // write data
    input  wire        we,         // write enable
    output wire [31:0] rd1,
    output wire [31:0] rd2
);

    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0;
    end

    // Combinational reads, with register 0 reading as zero
    assign rd1 = (ra1 == 5'd0) ? 32'd0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : regs[ra2];

    // Write on the NEGATIVE edge, when we is high and wa is not zero
    always @(negedge clk) begin
        if (we && wa != 5'd0) begin
            regs[wa] <= wd;
        end
    end

endmodule
