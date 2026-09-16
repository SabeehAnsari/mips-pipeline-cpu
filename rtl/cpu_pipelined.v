//==========================================================================
//  cpu_pipelined.v  -  five-stage pipelined MIPS32 CPU
//==========================================================================
`include "defines.vh"

module cpu_pipelined #(
    parameter INIT_FILE = ""
) (
    input  wire clk,
    input  wire rst
);

    // Dynamic hazard/flush signals
    wire stall;
    wire flush;

    //======================================================================
    //  IF - instruction fetch
    //======================================================================
    reg  [31:0] pc;
    wire [31:0] pc4_if = pc + 32'd4;
    wire [31:0] instr_if;
    wire [31:0] pc_next;

    imem #(.INIT_FILE(INIT_FILE)) u_imem (
        .addr  (pc),
        .instr (instr_if)
    );

    // Phase 8 Edit 1: Hold PC on stall
    always @(posedge clk) begin
        if (rst) begin
            pc <= `TEXT_BASE;
        end else if (!stall) begin
            pc <= pc_next;
        end
    end

    //======================================================================
    //  IF/ID pipeline register
    //======================================================================
    reg [31:0] instr_id;
    reg [31:0] pc4_id;

    // Phase 8 Edit 2: Add flush (priority) and stall branches
    always @(posedge clk) begin
        if (rst || flush) begin
            instr_id <= 32'd0;      // Inject NOP on reset or branch/jump flush
            pc4_id   <= 32'd0;
        end else if (!stall) begin
            instr_id <= instr_if;
            pc4_id   <= pc4_if;
        end
    end

    //======================================================================
    //  ID - decode and register read
    //======================================================================
    wire [5:0]  opcode_id  = instr_id[31:26];
    wire [4:0]  rs_id      = instr_id[25:21];
    wire [4:0]  rt_id      = instr_id[20:16];
    wire [4:0]  rd_id      = instr_id[15:11];
    wire [4:0]  shamt_id   = instr_id[10:6];
    wire [5:0]  funct_id   = instr_id[5:0];
    wire [15:0] imm_id     = instr_id[15:0];
    wire [25:0] jtarget_id = instr_id[25:0];

    wire [1:0] reg_dst_id;
    wire       alu_src_id, shamt_src_id, ext_op_id;
    wire [3:0] alu_ctrl_id;
    wire       mem_read_id, mem_write_id;
    wire [1:0] branch_id, jump_id;
    wire       reg_write_id;
    wire [1:0] mem_to_reg_id;

    wire [31:0] rs_data_id, rt_data_id, imm_ext_id;

    control u_ctrl (
        .opcode     (opcode_id),
        .funct      (funct_id),
        .reg_dst    (reg_dst_id),
        .alu_src    (alu_src_id),
        .shamt_src  (shamt_src_id),
        .ext_op     (ext_op_id),
        .alu_ctrl   (alu_ctrl_id),
        .mem_read   (mem_read_id),
        .mem_write  (mem_write_id),
        .branch     (branch_id),
        .jump       (jump_id),
        .reg_write  (reg_write_id),
        .mem_to_reg (mem_to_reg_id)
    );

    regfile u_rf (
        .clk (clk),
        .ra1 (rs_id),
        .ra2 (rt_id),
        .wa  (wr_addr_wb),
        .wd  (wr_data_wb),
        .we  (reg_write_wb),
        .rd1 (rs_data_id),
        .rd2 (rt_data_id)
    );

    sign_extend u_ext (
        .imm    (imm_id),
        .ext_op (ext_op_id),
        .out    (imm_ext_id)
    );

    hazard_unit u_hazard (
        .idex_memread (mem_read_ex),
        .idex_rt      (rt_ex),
        .ifid_rs      (rs_id),
        .ifid_rt      (rt_id),
        .stall        (stall)
    );

    //======================================================================
    //  ID/EX pipeline register
    //======================================================================
    reg [1:0]  reg_dst_ex;
    reg        alu_src_ex, shamt_src_ex;
    reg [3:0]  alu_ctrl_ex;
    reg        mem_read_ex, mem_write_ex;
    reg [1:0]  branch_ex, jump_ex;
    reg        reg_write_ex;
    reg [1:0]  mem_to_reg_ex;

    reg [31:0] pc4_ex, rs_data_ex, rt_data_ex, imm_ext_ex;
    reg [4:0]  rs_ex, rt_ex, rd_ex, shamt_ex;
    reg [25:0] jtarget_ex;

    // Phase 8 Edit 3: Bubble/clear on rst, stall, or flush
    always @(posedge clk) begin
        if (rst || stall || flush) begin
            reg_dst_ex    <= `DST_RT;
            alu_src_ex    <= 1'b0;
            shamt_src_ex  <= 1'b0;
            alu_ctrl_ex   <= `ALU_ADD;
            mem_read_ex   <= 1'b0;
            mem_write_ex  <= 1'b0;
            branch_ex     <= `BR_NONE;
            jump_ex       <= `JMP_NONE;
            reg_write_ex  <= 1'b0;
            mem_to_reg_ex <= `WB_ALU;

            pc4_ex        <= 32'd0;
            rs_data_ex    <= 32'd0;
            rt_data_ex    <= 32'd0;
            imm_ext_ex    <= 32'd0;
            rs_ex         <= 5'd0;
            rt_ex         <= 5'd0;
            rd_ex         <= 5'd0;
            shamt_ex      <= 5'd0;
            jtarget_ex    <= 26'd0;
        end else begin
            reg_dst_ex    <= reg_dst_id;
            alu_src_ex    <= alu_src_id;
            shamt_src_ex  <= shamt_src_id;
            alu_ctrl_ex   <= alu_ctrl_id;
            mem_read_ex   <= mem_read_id;
            mem_write_ex  <= mem_write_id;
            branch_ex     <= branch_id;
            jump_ex       <= jump_id;
            reg_write_ex  <= reg_write_id;
            mem_to_reg_ex <= mem_to_reg_id;

            pc4_ex        <= pc4_id;
            rs_data_ex    <= rs_data_id;
            rt_data_ex    <= rt_data_id;
            imm_ext_ex    <= imm_ext_id;
            rs_ex         <= rs_id;
            rt_ex         <= rt_id;
            rd_ex         <= rd_id;
            shamt_ex      <= shamt_id;
            jtarget_ex    <= jtarget_id;
        end
    end

    //======================================================================
    //  EX - execute
    //======================================================================
    wire [1:0] forward_a, forward_b;

    forwarding_unit u_fwd (
        .idex_rs        (rs_ex),
        .idex_rt        (rt_ex),
        .exmem_rd       (wr_addr_mem),
        .exmem_regwrite (reg_write_mem),
        .memwb_rd       (wr_addr_wb),
        .memwb_regwrite (reg_write_wb),
        .forward_a      (forward_a),
        .forward_b      (forward_b)
    );

    wire [31:0] rs_fwd_ex = (forward_a == `FWD_MEM) ? alu_result_mem :
                            (forward_a == `FWD_WB)  ? wr_data_wb : rs_data_ex;

    wire [31:0] rt_fwd_ex = (forward_b == `FWD_MEM) ? alu_result_mem :
                            (forward_b == `FWD_WB)  ? wr_data_wb : rt_data_ex;

    wire [31:0] alu_result_ex;
    wire        zero_ex;

    wire [4:0] wr_addr_ex = (reg_dst_ex == `DST_RD) ? rd_ex :
                            (reg_dst_ex == `DST_RA) ? 5'd31 : rt_ex;

    wire [31:0] alu_a_ex = shamt_src_ex ? {27'd0, shamt_ex} : rs_fwd_ex;
    wire [31:0] alu_b_ex = alu_src_ex   ? imm_ext_ex        : rt_fwd_ex;

    wire [31:0] branch_target_ex = pc4_ex + (imm_ext_ex << 2);
    wire [31:0] jump_target_ex   = {pc4_ex[31:28], jtarget_ex, 2'b00};

    alu u_alu (
        .a        (alu_a_ex),
        .b        (alu_b_ex),
        .alu_ctrl (alu_ctrl_ex),
        .result   (alu_result_ex),
        .zero     (zero_ex)
    );

    //======================================================================
    //  EX/MEM pipeline register
    //======================================================================
    reg        mem_read_mem, mem_write_mem;
    reg [1:0]  branch_mem, jump_mem;
    reg        reg_write_mem;
    reg [1:0]  mem_to_reg_mem;

    reg [31:0] alu_result_mem, rt_data_mem, rs_data_mem;
    reg [31:0] branch_target_mem, jump_target_mem, pc4_mem;
    reg [4:0]  wr_addr_mem;
    reg        zero_mem;

    // Phase 9 Edit 1: Clear EX/MEM on reset or control flush
    always @(posedge clk) begin
        if (rst || flush) begin
            mem_read_mem      <= 1'b0;
            mem_write_mem     <= 1'b0;
            branch_mem        <= `BR_NONE;
            jump_mem          <= `JMP_NONE;
            reg_write_mem     <= 1'b0;
            mem_to_reg_mem    <= `WB_ALU;

            alu_result_mem    <= 32'd0;
            rt_data_mem       <= 32'd0;
            rs_data_mem       <= 32'd0;
            branch_target_mem <= 32'd0;
            jump_target_mem   <= 32'd0;
            pc4_mem           <= 32'd0;
            wr_addr_mem       <= 5'd0;
            zero_mem          <= 1'b0;
        end else begin
            mem_read_mem      <= mem_read_ex;
            mem_write_mem     <= mem_write_ex;
            branch_mem        <= branch_ex;
            jump_mem          <= jump_ex;
            reg_write_mem     <= reg_write_ex;
            mem_to_reg_mem    <= mem_to_reg_ex;

            alu_result_mem    <= alu_result_ex;
            rt_data_mem       <= rt_fwd_ex;
            rs_data_mem       <= rs_fwd_ex;
            branch_target_mem <= branch_target_ex;
            jump_target_mem   <= jump_target_ex;
            pc4_mem           <= pc4_ex;
            wr_addr_mem       <= wr_addr_ex;
            zero_mem          <= zero_ex;
        end
    end

    //======================================================================
    //  MEM - memory access, branch & jump resolution
    //======================================================================
    wire [31:0] mem_data_mem;

    dmem u_dmem (
        .clk  (clk),
        .addr (alu_result_mem),
        .wd   (rt_data_mem),
        .we   (mem_write_mem),
        .re   (mem_read_mem),
        .rd   (mem_data_mem)
    );

    wire branch_taken_mem = ((branch_mem == `BR_EQ) &&  zero_mem) ||
                            ((branch_mem == `BR_NE) && !zero_mem);

    assign pc_next = (jump_mem == `JMP_JR) ? rs_data_mem :
                     (jump_mem == `JMP_J)  ? jump_target_mem :
                     branch_taken_mem      ? branch_target_mem : pc4_if;

    // Phase 9 Edit 2: Continuous assign for control flush (taken branch or any jump)
    assign flush = branch_taken_mem || (jump_mem != `JMP_NONE);

    //======================================================================
    //  MEM/WB pipeline register
    //======================================================================
    reg        reg_write_wb;
    reg [1:0]  mem_to_reg_wb;
    reg [31:0] alu_result_wb, mem_data_wb, pc4_wb;
    reg [4:0]  wr_addr_wb;

    always @(posedge clk) begin
        if (rst) begin
            reg_write_wb  <= 1'b0;
            mem_to_reg_wb <= `WB_ALU;
            alu_result_wb <= 32'd0;
            mem_data_wb   <= 32'd0;
            pc4_wb        <= 32'd0;
            wr_addr_wb    <= 5'd0;
        end else begin
            reg_write_wb  <= reg_write_mem;
            mem_to_reg_wb <= mem_to_reg_mem;
            alu_result_wb <= alu_result_mem;
            mem_data_wb   <= mem_data_mem;
            pc4_wb        <= pc4_mem;
            wr_addr_wb    <= wr_addr_mem;
        end
    end

    //======================================================================
    //  WB - write back
    //======================================================================
    wire [31:0] wr_data_wb = (mem_to_reg_wb == `WB_MEM) ? mem_data_wb :
                             (mem_to_reg_wb == `WB_PC4) ? pc4_wb : alu_result_wb;

    //======================================================================
    //  Performance counters - instrumentation for the report
    //
    //  cpu_compare_tb reads stall_count and flush_count to break the cycle
    //  total down into pipeline fill, stalls and flushes. The dynamic
    //  instruction count comes from the program rather than from hardware,
    //  which keeps these trivial and the measurement easy to defend.
    //======================================================================
    reg [31:0] cycle_count;
    reg [31:0] stall_count;
    reg [31:0] flush_count;

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 32'd0;
            stall_count <= 32'd0;
            flush_count <= 32'd0;
        end else begin
            cycle_count <= cycle_count + 32'd1;
            if (stall) stall_count <= stall_count + 32'd1;
            if (flush) flush_count <= flush_count + 32'd1;
        end
    end

endmodule