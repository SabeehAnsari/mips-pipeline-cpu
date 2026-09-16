//==========================================================================
//  leaf_tb.v  -  self-checking testbench for sign_extend, imem and dmem
//
//  All three small modules in one testbench, so you run it once rather
//  than three times. Do not edit - it is the specification.
//
//  Icarus : iverilog -I rtl -o leaf.out rtl/sign_extend.v rtl/imem.v rtl/dmem.v tb/leaf_tb.v && vvp leaf.out
//  Vivado : set leaf_tb as simulation top, Run Behavioral Simulation
//==========================================================================
`timescale 1ns / 1ps
`include "defines.vh"

module leaf_tb;

    integer passed = 0;
    integer failed = 0;

    task ck;
        input [8*26:1] name;
        input [31:0]   got, want;
        begin
            if (got === want) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("  FAIL  %0s  got %08h  want %08h", name, got, want);
            end
        end
    endtask

    //----------------------------------------------------- sign_extend
    reg  [15:0] imm;
    reg         ext_op;
    wire [31:0] ext_out;

    sign_extend u_ext (.imm(imm), .ext_op(ext_op), .out(ext_out));

    //------------------------------------------------------------ imem
    reg  [31:0] iaddr;
    wire [31:0] instr;

    imem #(.INIT_FILE("")) u_imem (.addr(iaddr), .instr(instr));

    //------------------------------------------------------------ dmem
    reg         clk = 0;
    reg  [31:0] daddr, dwd;
    reg         dwe, dre;
    wire [31:0] drd;

    dmem u_dmem (.clk(clk), .addr(daddr), .wd(dwd),
                 .we(dwe), .re(dre), .rd(drd));

    always #5 clk = ~clk;

    integer k;

    initial begin
        $display("");
        $display("==========  sign_extend / imem / dmem  ==========");

        //------------------------------------------------ sign_extend
        ext_op = `EXT_SIGN;
        imm = 16'h0001; #1; ck("sign small positive", ext_out, 32'h00000001);
        imm = 16'h7FFF; #1; ck("sign largest positive", ext_out, 32'h00007FFF);
        imm = 16'hFFFF; #1; ck("sign -1", ext_out, 32'hFFFFFFFF);
        imm = 16'h8000; #1; ck("sign most negative", ext_out, 32'hFFFF8000);
        imm = 16'hFFFE; #1; ck("sign -2", ext_out, 32'hFFFFFFFE);
        imm = 16'h0000; #1; ck("sign zero", ext_out, 32'h00000000);

        ext_op = `EXT_ZERO;
        imm = 16'h0001; #1; ck("zero small", ext_out, 32'h00000001);
        imm = 16'hFFFF; #1; ck("zero all ones", ext_out, 32'h0000FFFF);
        imm = 16'h8000; #1; ck("zero top bit set", ext_out, 32'h00008000);
        imm = 16'hABCD; #1; ck("zero pattern", ext_out, 32'h0000ABCD);

        //------------------------------------------------------- imem
        // no init file, so every word reads zero - but the INDEXING must
        // still be right, which we check by writing the array directly
        u_imem.mem[0] = 32'hDEADBEEF;
        u_imem.mem[1] = 32'h11112222;
        u_imem.mem[2] = 32'h33334444;
        u_imem.mem[9] = 32'hAAAABBBB;
        #1;
        iaddr = 32'h00000000; #1; ck("imem word 0", instr, 32'hDEADBEEF);
        iaddr = 32'h00000004; #1; ck("imem word 1", instr, 32'h11112222);
        iaddr = 32'h00000008; #1; ck("imem word 2", instr, 32'h33334444);
        iaddr = 32'h00000024; #1; ck("imem word 9", instr, 32'hAAAABBBB);
        iaddr = 32'h0000000C; #1; ck("imem empty word", instr, 32'h00000000);

        //------------------------------------------------------- dmem
        dwe = 0; dre = 1; dwd = 0; daddr = `DATA_BASE;
        @(posedge clk); #1;
        ck("dmem starts zero", drd, 32'h00000000);

        // write 0xCAFEBABE to the first word of the data segment
        daddr = `DATA_BASE; dwd = 32'hCAFEBABE; dwe = 1;
        @(posedge clk); #1;
        dwe = 0; #1;
        ck("dmem write/read base", drd, 32'hCAFEBABE);

        // second word, four bytes further on
        daddr = `DATA_BASE + 4; dwd = 32'h12345678; dwe = 1;
        @(posedge clk); #1;
        dwe = 0; #1;
        ck("dmem write/read base+4", drd, 32'h12345678);

        // the first word must be untouched - catches a broken index
        daddr = `DATA_BASE; #1;
        ck("dmem base still intact", drd, 32'hCAFEBABE);

        // a word further into the segment
        daddr = `DATA_BASE + 32'd40; dwd = 32'h0000FACE; dwe = 1;
        @(posedge clk); #1;
        dwe = 0; #1;
        ck("dmem write/read base+40", drd, 32'h0000FACE);

        // write enable low must not write
        daddr = `DATA_BASE + 32'd8; dwd = 32'hFFFFFFFF; dwe = 0;
        @(posedge clk); #1;
        ck("dmem we low blocks write", drd, 32'h00000000);

        $display("");
        $display("  passed %0d   failed %0d", passed, failed);
        if (failed == 0)
            $display("  leaf modules OK  -  ready for single-cycle integration");
        else
            $display("  leaf modules NOT READY  -  fix the failures above");
        $display("=================================================");
        $display("");
        $finish;
    end

endmodule
