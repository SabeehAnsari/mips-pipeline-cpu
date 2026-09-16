//==========================================================================
//  forwarding_unit.v  -  PHASE 7
//
//  Decides, for each ALU operand, where its value should come from.
//
//  The problem: an instruction in EX needs a register that an instruction
//  ahead of it has computed but not yet written back. The value exists -
//  it is sitting in a pipeline register - so route it straight to the ALU
//  input instead of waiting.
//
//  Two sources, and PRIORITY MATTERS. If a register appears in both
//  EX/MEM and MEM/WB, the EX/MEM copy is newer and must win. Get this
//  backwards and you forward a stale value, which looks like an
//  intermittent fault and is miserable to find.
//
//  For operand A (which comes from rs):
//
//      if  EX/MEM writes a register
//      and that register is not $zero
//      and it is the same register as idex_rs
//          -> forward_a = 2'b10        take EX/MEM's ALU result
//
//      else if MEM/WB writes a register
//      and   that register is not $zero
//      and   it is the same register as idex_rs
//          -> forward_a = 2'b01        take the write-back value
//
//      else
//          -> forward_a = 2'b00        take the register file output
//
//  Operand B is identical with idex_rt in place of idex_rs.
//
//  The "not $zero" test matters: $zero always reads as zero, so forwarding
//  a write to it would hand out a value that the register file would never
//  have returned.
//
//  Write it as one always @(*) block with defaults at the top, the same
//  shape as control.v.
//==========================================================================
`include "defines.vh"

module forwarding_unit (
    input  wire [4:0] idex_rs,
    input  wire [4:0] idex_rt,

    input  wire [4:0] exmem_rd,
    input  wire       exmem_regwrite,

    input  wire [4:0] memwb_rd,
    input  wire       memwb_regwrite,

    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

    always @(*) begin
        // Safe defaults: read directly from register file / ID/EX pipeline register
        forward_a = `FWD_REG;
        forward_b = `FWD_REG;

        //---------------------------------------------------------- Operand A (rs)
        // Highest priority: Forward from EX/MEM stage (newer data)
        if (exmem_regwrite && (exmem_rd != 5'd0) && (exmem_rd == idex_rs)) begin
            forward_a = `FWD_MEM;
        end
        // Second priority: Forward from MEM/WB stage
        else if (memwb_regwrite && (memwb_rd != 5'd0) && (memwb_rd == idex_rs)) begin
            forward_a = `FWD_WB;
        end

        //---------------------------------------------------------- Operand B (rt)
        // Highest priority: Forward from EX/MEM stage (newer data)
        if (exmem_regwrite && (exmem_rd != 5'd0) && (exmem_rd == idex_rt)) begin
            forward_b = `FWD_MEM;
        end
        // Second priority: Forward from MEM/WB stage
        else if (memwb_regwrite && (memwb_rd != 5'd0) && (memwb_rd == idex_rt)) begin
            forward_b = `FWD_WB;
        end
    end

endmodule