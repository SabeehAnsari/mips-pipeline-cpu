//==========================================================================
//  hazard_unit.v  -  PHASE 8
//
//  Detects the one data hazard that forwarding cannot fix.
//
//  A load produces its data in MEM. The instruction immediately behind it
//  is already in EX by then, and data cannot travel backwards in time. So
//  that instruction must be held for one cycle, and exactly one cycle -
//  after the bubble, ordinary forwarding takes over.
//
//  The condition:
//
//      the instruction in EX is a load          (idex_memread is high)
//      AND the register it will load into       (idex_rt)
//      matches either source register of the    (ifid_rs or ifid_rt)
//      instruction currently in ID
//
//  When that holds, assert stall. The top level responds by holding the
//  PC and IF/ID, and pushing a bubble into ID/EX.
//
//  Two details worth getting right:
//
//   - Compare against idex_rt, not the destination mux output. A load
//     always writes rt; using a general destination would also match
//     R-type instructions, which do not need a stall.
//
//   - You may guard on idex_rt != 0. A load into $zero is pointless but
//     legal, and stalling for it wastes a cycle. Not required for
//     correctness; the testbench accepts either.
//
//  This is combinational - a single continuous assign is enough.
//==========================================================================
`include "defines.vh"

module hazard_unit (
    input  wire       idex_memread,
    input  wire [4:0] idex_rt,

    input  wire [4:0] ifid_rs,
    input  wire [4:0] ifid_rt,

    output wire       stall
);

    assign stall = idex_memread && (idex_rt != 5'd0) &&
                   ((idex_rt == ifid_rs) || (idex_rt == ifid_rt));

endmodule