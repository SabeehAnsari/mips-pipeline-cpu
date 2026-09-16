//==========================================================================
//  cpu_pipelined_tb.v  -  step 6 test: pipeline registers
//
//  Runs tests/04_pipeline_nops.hex, which is padded with nops so that no
//  hazard ever arises. Passing this means data moves through the five
//  stages correctly and every stage is wired to the right place.
//
//  It does NOT mean the CPU is finished. Forwarding, stalling and flushing
//  are steps 7, 8 and 9 - their job is to let you delete the padding.
//
//  ---------------------------------------------------------------------
//  EDIT THE PATH BELOW if your clone lives somewhere else.
//  ---------------------------------------------------------------------
//
//  Icarus : iverilog -I rtl -o pipe.out rtl/*.v tb/cpu_pipelined_tb.v && vvp pipe.out
//  Vivado : set cpu_pipelined_tb as simulation top, Run Behavioral Simulation
//==========================================================================
`timescale 1ns / 1ps
`include "defines.vh"

module cpu_pipelined_tb;

    localparam HEX = "D:/fpga/mips_pipeline/tests/04_pipeline_nops.hex";

    localparam CYCLES = 200;    // the program halts well before this

    reg clk = 0;
    reg rst = 1;

    integer passed = 0;
    integer failed = 0;
    integer c;

    cpu_pipelined #(.INIT_FILE(HEX)) dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;

    function [8*5:1] rname;
        input integer r;
        begin
            case (r)
                 0: rname = "$zero";
                 8: rname = "$t0";   9: rname = "$t1";  10: rname = "$t2";
                11: rname = "$t3";  12: rname = "$t4";  13: rname = "$t5";
                14: rname = "$t6";  15: rname = "$t7";
                16: rname = "$s0";  17: rname = "$s1";  31: rname = "$ra";
                default: rname = "?";
            endcase
        end
    endfunction

    task expect_reg;
        input integer r;
        input [31:0]  want;
        reg   [31:0]  got;
        begin
            got = (r == 0) ? 32'd0 : dut.u_rf.regs[r];
            if (got === want) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("  FAIL  %0s (r%0d)  got %08h  want %08h",
                         rname(r), r, got, want);
            end
        end
    endtask

    task expect_mem;
        input [31:0] byte_addr;
        input [31:0] want;
        reg   [31:0] got;
        begin
            got = dut.u_dmem.mem[(byte_addr - `DATA_BASE) >> 2];
            if (got === want) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("  FAIL  mem[%08h]  got %08h  want %08h",
                         byte_addr, got, want);
            end
        end
    endtask

    initial begin
        $display("");
        $display("=====  pipelined CPU - step 6, pipeline registers  =====");
        $display("  program: %0s", HEX);

        #1;
        if (dut.u_imem.mem[0] === 32'h0000_0000) begin
            $display("");
            $display("  *** instruction memory is empty ***");
            $display("  The hex file did not load. Check the HEX path above.");
            $display("");
            $finish;
        end

        @(posedge clk);
        @(posedge clk);
        rst = 0;

        for (c = 0; c < CYCLES; c = c + 1) @(posedge clk);

        #1;
        $display("  ran %0d cycles, final PC = %08h", CYCLES, dut.pc);
        $display("");

        expect_reg( 8, 32'h00000014);   // $t0  20
        expect_reg( 9, 32'h00000006);   // $t1  6
        expect_reg(10, 32'h0000001A);   // $t2  t0 + t1
        expect_reg(11, 32'h0000000E);   // $t3  t0 - t1
        expect_reg(12, 32'h00002000);   // $t4  data base
        expect_reg(13, 32'h0000001A);   // $t5  stored then loaded back
        expect_mem(32'h00002000, 32'h0000001A);

        expect_reg(14, 32'h00000001);   // $t6  branch taken, this ran
        expect_reg(15, 32'h00000000);   // $t7  skipped by the branch

        expect_reg(31, 32'h00000088);   // $ra  return address from jal
        expect_reg(16, 32'h00000063);   // $s0  set inside func
        expect_reg(17, 32'h00000005);   // $s1  runs after jr returned

        expect_reg(0, 32'h00000000);    // $zero holds

        $display("");
        $display("  passed %0d   failed %0d", passed, failed);
        if (failed == 0) begin
            $display("  PIPELINE REGISTERS WORK");
            $display("  Data flows correctly through all five stages.");
            $display("  Next: forwarding (step 7).");
        end else begin
            $display("  not working yet - read the failures above");
            $display("");
            $display("  Reading the failures:");
            $display("   - everything zero          ->  a pipeline register bank");
            $display("                                  is still empty, or the PC");
            $display("                                  never advances");
            $display("   - $t2/$t3 wrong            ->  ID/EX register, or the EX muxes");
            $display("   - $t5 or memory wrong      ->  EX/MEM not carrying rt_data,");
            $display("                                  or the MEM stage wiring");
            $display("   - $t7 got 77               ->  the branch was not taken;");
            $display("                                  check branch_taken_mem");
            $display("   - $s1 wrong but $s0 right  ->  jr target: EX/MEM must carry");
            $display("                                  rs_data through to MEM");
            $display("   - $ra wrong                ->  WB_PC4 path, or pc4 not");
            $display("                                  travelling down the pipe");
        end
        $display("========================================================");
        $display("");
        $finish;
    end

endmodule
