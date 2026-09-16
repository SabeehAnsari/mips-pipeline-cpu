//==========================================================================
//  cpu_single_tb.v  -  system test for the single-cycle CPU
//
//  Loads tests/03_single_cycle.hex, runs it, and compares the final
//  register file and data memory against the reference result.
//
//  The expected values come from an independent model of the instruction
//  set, and match what MARS produces for the same program. If your CPU
//  disagrees, your CPU is wrong.
//
//  ---------------------------------------------------------------------
//  EDIT THE PATH BELOW before the first run.
//
//  Vivado resolves a relative path against its own simulation run
//  directory rather than your project folder, so an absolute path with
//  forward slashes is the reliable choice.
//  ---------------------------------------------------------------------
//
//  Icarus : iverilog -I rtl -o cpu.out rtl/*.v tb/cpu_single_tb.v && vvp cpu.out
//  Vivado : set cpu_single_tb as simulation top, Run Behavioral Simulation
//==========================================================================
`timescale 1ns / 1ps
`include "defines.vh"

module cpu_single_tb;

    localparam HEX = "D:/fpga/mips_pipeline/tests/03_single_cycle.hex";

    localparam CYCLES = 80;     // the program halts well before this

    reg clk = 0;
    reg rst = 1;

    integer passed = 0;
    integer failed = 0;
    integer c;

    cpu_single #(.INIT_FILE(HEX)) dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;       // 10 ns period

    // register names, for readable failure messages
    function [8*5:1] rname;
        input integer r;
        begin
            case (r)
                 0: rname = "$zero";
                 8: rname = "$t0";   9: rname = "$t1";  10: rname = "$t2";
                11: rname = "$t3";  12: rname = "$t4";  13: rname = "$t5";
                14: rname = "$t6";  15: rname = "$t7";
                16: rname = "$s0";  17: rname = "$s1";  18: rname = "$s2";
                19: rname = "$s3";  20: rname = "$s4";  21: rname = "$s5";
                22: rname = "$s6";  23: rname = "$s7";
                24: rname = "$t8";  31: rname = "$ra";
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
        $display("==========  single-cycle CPU system test  ==========");
        $display("  program: %0s", HEX);

        // confirm the program actually loaded before blaming the CPU
        #1;
        if (dut.u_imem.mem[0] === 32'h0000_0000) begin
            $display("");
            $display("  *** instruction memory is empty ***");
            $display("  The hex file did not load. Check the HEX path at the");
            $display("  top of this file, and that the file contains bare");
            $display("  8-digit hex words with no 0x prefix.");
            $display("");
            $finish;
        end

        // release reset after two edges
        @(posedge clk);
        @(posedge clk);
        rst = 0;

        for (c = 0; c < CYCLES; c = c + 1) @(posedge clk);

        #1;
        $display("  ran %0d cycles, final PC = %08h", CYCLES, dut.pc);
        $display("");

        //---------------------------------------------------- arithmetic
        expect_reg( 8, 32'h0000000A);   // $t0  10
        expect_reg( 9, 32'h00000003);   // $t1  3
        expect_reg(10, 32'h0000000D);   // $t2  t0 + t1
        expect_reg(11, 32'h00000007);   // $t3  t0 - t1
        expect_reg(12, 32'h00000002);   // $t4  t0 & t1
        expect_reg(13, 32'h0000000B);   // $t5  t0 | t1
        expect_reg(14, 32'h00000009);   // $t6  t0 ^ t1

        //-------------------------------------------------------- shifts
        expect_reg(15, 32'h00000028);   // $t7  t0 << 2
        expect_reg(16, 32'h00000005);   // $s0  t0 >> 1

        //----------------------------------------------------- compare
        expect_reg(17, 32'h00000001);   // $s1  t1 < t0

        //------------------------------------------- lui + ori constant
        expect_reg(18, 32'h12345678);   // $s2

        //------------------------------------------------------- memory
        expect_reg(19, 32'h00002000);   // $s3  data base
        expect_reg(20, 32'h0000000D);   // $s4  loaded back
        expect_mem(32'h00002000, 32'h0000000D);

        //----------------------------------------------------- branches
        expect_reg(21, 32'h00000001);   // $s5  branch not taken, ran
        expect_reg(22, 32'h00000000);   // $s6  branch taken, skipped

        //------------------------------------------------ jal / jr / j
        expect_reg(24, 32'h00000037);   // $t8  set inside func
        expect_reg(23, 32'h00000007);   // $s7  reached after jr returned
        expect_reg(31, 32'h00000050);   // $ra  return address from jal

        //-------------------------------------------------- $zero holds
        expect_reg(0, 32'h00000000);

        $display("");
        $display("  passed %0d   failed %0d", passed, failed);
        if (failed == 0) begin
            $display("  SINGLE-CYCLE CPU WORKS");
            $display("  Your control table is validated. Start pipelining.");
        end else begin
            $display("  not working yet - read the failures above");
            $display("");
            $display("  Reading the failures:");
            $display("   - only $s7/$ra/$t8 wrong  ->  jal, jr or the jump target");
            $display("   - only $s5/$s6 wrong      ->  branch condition or target");
            $display("   - only $s4 or memory      ->  dmem base offset or indexing");
            $display("   - only $t7/$s0 wrong      ->  the shamt mux");
            $display("   - everything wrong        ->  next-PC logic or the");
            $display("                                 write-back mux");
        end
        $display("====================================================");
        $display("");
        $finish;
    end

endmodule
