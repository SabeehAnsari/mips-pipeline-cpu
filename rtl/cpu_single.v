//==========================================================================
//  cpu_single.v  -  single-cycle MIPS32 CPU
//
//  ALL TRACKS.  This is the integration step: every module you have built
//  so far, wired into something that executes instructions.
//
//  Why build a single-cycle version at all, when the deliverable is a
//  pipeline? Because it validates the control table in an afternoon, in a
//  design with no pipeline registers to hide a control fault. Every module
//  here is reused unchanged in the pipelined version, so it costs almost
//  nothing - and it gives you the baseline you need to report speedup.
//
//  The module instances below are already wired. Do NOT rename them: the
//  testbench reaches into u_rf to read the register file.
//
//  What you write is the five multiplexers and the next-PC logic. That is
//  the whole of the integration work, and it is where the control signals
//  stop being a table and start being hardware.
//
//  ---- THE FIVE MULTIPLEXERS -------------------------------------------
//
//  wr_addr     reg_dst selects which register is written:
//                  DST_RT -> rt      (I-type)
//                  DST_RD -> rd      (R-type)
//                  DST_RA -> 5'd31   (jal)
//
//  alu_a       shamt_src selects the ALU's first operand:
//                  0 -> rs_data
//                  1 -> shamt, zero-extended to 32 bits
//
//  alu_b       alu_src selects the ALU's second operand:
//                  0 -> rt_data
//                  1 -> imm_ext
//
//  wr_data     mem_to_reg selects what is written back:
//                  WB_ALU -> alu_result
//                  WB_MEM -> mem_data
//                  WB_PC4 -> pc_plus4   (jal stores the return address)
//
//  pc_next     described below
//
//  A three-way mux is a nested ternary:
//      assign x = (sel == A) ? valA : (sel == B) ? valB : valC;
//
//  ---- NEXT PC ---------------------------------------------------------
//
//  branch_taken is true when   branch == BR_EQ and zero is set,
//                          or   branch == BR_NE and zero is clear.
//
//  branch_target = pc_plus4 + (imm_ext << 2)
//      The offset counts instructions, not bytes, and is relative to the
//      instruction AFTER the branch - which is why it is pc_plus4 and not pc.
//
//  jump_target = { pc_plus4[31:28], jtarget, 2'b00 }
//      26 bits of target, shifted left by two, with the top four bits
//      inherited from the current PC. Use the concatenation operator.
//
//  Priority, highest first:
//      jump == JMP_JR   -> rs_data          (jr)
//      jump == JMP_J    -> jump_target      (j, jal)
//      branch_taken     -> branch_target
//      otherwise        -> pc_plus4
//
//  ---- RESET -----------------------------------------------------------
//
//  Synchronous, active high. On reset the PC returns to `TEXT_BASE.
//==========================================================================
`include "defines.vh"

module cpu_single #(
    parameter INIT_FILE = ""
) (
    input  wire clk,
    input  wire rst
);

    //---------------------------------------------------------- program counter
    reg  [31:0] pc;
    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] pc_next;

    //---------------------------------------------------------- instruction
    wire [31:0] instr;

    wire [5:0]  opcode  = instr[31:26];
    wire [4:0]  rs      = instr[25:21];
    wire [4:0]  rt      = instr[20:16];
    wire [4:0]  rd      = instr[15:11];
    wire [4:0]  shamt   = instr[10:6];
    wire [5:0]  funct   = instr[5:0];
    wire [15:0] imm     = instr[15:0];
    wire [25:0] jtarget = instr[25:0];

    //---------------------------------------------------------- control signals
    wire [1:0] reg_dst;
    wire       alu_src, shamt_src, ext_op;
    wire [3:0] alu_ctrl;
    wire       mem_read, mem_write;
    wire [1:0] branch, jump;
    wire       reg_write;
    wire [1:0] mem_to_reg;

    //---------------------------------------------------------- datapath wires
    wire [31:0] rs_data, rt_data, imm_ext;
    wire [31:0] alu_result, mem_data;
    wire        zero;

    //======================================================================
    //  Module instances - already wired. Do not rename them.
    //======================================================================

    imem #(.INIT_FILE(INIT_FILE)) u_imem (
        .addr  (pc),
        .instr (instr)
    );

    control u_ctrl (
        .opcode     (opcode),
        .funct      (funct),
        .reg_dst    (reg_dst),
        .alu_src    (alu_src),
        .shamt_src  (shamt_src),
        .ext_op     (ext_op),
        .alu_ctrl   (alu_ctrl),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .branch     (branch),
        .jump       (jump),
        .reg_write  (reg_write),
        .mem_to_reg (mem_to_reg)
    );

    regfile u_rf (
        .clk (clk),
        .ra1 (rs),
        .ra2 (rt),
        .wa  (wr_addr),
        .wd  (wr_data),
        .we  (reg_write),
        .rd1 (rs_data),
        .rd2 (rt_data)
    );

    sign_extend u_ext (
        .imm    (imm),
        .ext_op (ext_op),
        .out    (imm_ext)
    );

    alu u_alu (
        .a        (alu_a),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .result   (alu_result),
        .zero     (zero)
    );

    dmem u_dmem (
        .clk  (clk),
        .addr (alu_result),
        .wd   (rt_data),
        .we   (mem_write),
        .re   (mem_read),
        .rd   (mem_data)
    );

    //======================================================================
    //  Multiplexers & Datapath Logic
    //======================================================================

    // Destination register: rt, rd, or $31 (RA)
    wire [4:0] wr_addr = (reg_dst == `DST_RD) ? rd :
                         (reg_dst == `DST_RA) ? 5'd31 : rt;

    // ALU operand A: rs_data, or shamt zero-extended to 32 bits
    wire [31:0] alu_a = shamt_src ? {27'd0, shamt} : rs_data;

    // ALU operand B: rt_data or sign/zero-extended immediate
    wire [31:0] alu_b = alu_src ? imm_ext : rt_data;

    // Write-back value: ALU result, memory data, or return address (pc_plus4)
    wire [31:0] wr_data = (mem_to_reg == `WB_MEM) ? mem_data :
                          (mem_to_reg == `WB_PC4) ? pc_plus4 : alu_result;

    // Branch condition logic
    wire branch_taken = ((branch == `BR_EQ) &&  zero) ||
                        ((branch == `BR_NE) && !zero);

    // Branch target: relative to instruction after branch (pc_plus4)
    wire [31:0] branch_target = pc_plus4 + (imm_ext << 2);

    // Jump target: 26-bit target shifted left 2, appended to PC+4[31:28]
    wire [31:0] jump_target = {pc_plus4[31:28], jtarget, 2'b00};

    // Next PC selection in priority order: jr -> j/jal -> branch -> +4
    assign pc_next = (jump == `JMP_JR) ? rs_data :
                     (jump == `JMP_J)  ? jump_target :
                     branch_taken      ? branch_target : pc_plus4;

    // Synchronous PC state register with active-high reset
    always @(posedge clk) begin
        if (rst) begin
            pc <= `TEXT_BASE;
        end else begin
            pc <= pc_next;
        end
    end

endmodule