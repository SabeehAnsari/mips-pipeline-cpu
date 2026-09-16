//==========================================================================
//  cpu_compare_tb.v  -  the headline test
//
//  Runs tests/05_hazards.hex on BOTH processors at once and checks three
//  things:
//
//    1. the pipelined CPU produces the architecturally correct result
//    2. both CPUs produce IDENTICAL results, register for register
//    3. how many cycles each one took
//
//  05_hazards.asm contains no padding: forwarding at both distances, a
//  load-use pair, a taken branch with three live instructions behind it,
//  and jal/jr. If this passes, the hazard logic is genuinely working.
//
//  ---- READING THE CYCLE COUNTS ----------------------------------------
//
//  The pipelined CPU will take MORE cycles than the single-cycle one, and
//  that is correct, not a bug. Pipeline fill costs four cycles, each stall
//  costs one, each taken branch costs three.
//
//  The speedup does not come from cycles - it comes from the clock. The
//  single-cycle CPU's period must cover the entire datapath: fetch,
//  decode, ALU, memory and write-back in series. The pipelined CPU's
//  period need only cover the slowest single stage. Execution time is
//
//        cycles  x  clock period
//
//  so the comparison is only complete once you have Fmax for both designs
//  from Vivado synthesis. Report both numbers, then the product.
//
//  ---------------------------------------------------------------------
//  EDIT THE PATH BELOW if your clone lives somewhere else.
//  ---------------------------------------------------------------------
//==========================================================================
`timescale 1ns / 1ps
`include "defines.vh"

module cpu_compare_tb;

    localparam HEX = "D:/fpga/mips_pipeline/tests/05_hazards.hex";

    localparam MAXC   = 400;
    localparam INSTRS = 27;     // dynamic instructions up to and including the
                                //  sentinel store, which is where both CPUs are
                                //  measured. The halt loop is not counted.
                                //  Cross-check: the single-cycle CPU must report
                                //  exactly this many cycles, i.e. CPI 1.00.

    reg clk = 0;
    reg rst = 1;

    integer passed = 0, failed = 0, mismatched = 0;
    integer c, r;
    integer s_cycles = -1, p_cycles = -1;
    integer p_stalls = 0, p_flushes = 0;
    reg [31:0] sv, pv;

    cpu_single    #(.INIT_FILE(HEX)) s (.clk(clk), .rst(rst));
    cpu_pipelined #(.INIT_FILE(HEX)) p (.clk(clk), .rst(rst));

    always #5 clk = ~clk;

    task ck;
        input [8*10:1] name;
        input [31:0]   got, want;
        begin
            if (got === want) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("  FAIL  %0s  got %08h  want %08h", name, got, want);
            end
        end
    endtask

    initial begin
        $display("");
        $display("==========  single-cycle vs pipelined  ==========");
        $display("  program: %0s", HEX);

        #1;
        if (p.u_imem.mem[0] === 32'h0000_0000) begin
            $display("  *** instruction memory empty - check the HEX path ***");
            $finish;
        end

        @(posedge clk); @(posedge clk);
        #1 rst = 0;      // release reset BETWEEN clock edges, never on one.
                         //  Assigning rst at the instant of a posedge is a race:
                         //  whether the DUT's always @(posedge clk) blocks see the
                         //  old or new value is scheduler-dependent, and Icarus and
                         //  XSim resolve it differently - a one-cycle difference in
                         //  every measurement taken afterwards.

        for (c = 0; c < MAXC; c = c + 1) begin
            @(posedge clk); #1;
            if (s_cycles < 0 && s.u_dmem.mem[1] === 32'hDEADBEEF) s_cycles = c + 1;
            if (p_cycles < 0 && p.u_dmem.mem[1] === 32'hDEADBEEF) begin
                // snapshot the counters the moment the program finishes.
                // The halt loop is a jump, so it keeps flushing forever -
                // counting past this point would be meaningless.
                p_cycles  = c + 1;
                p_stalls  = p.stall_count;
                p_flushes = p.flush_count;
            end
        end

        //--------------------------------------- correctness, pipelined CPU
        $display("");
        $display("  --- pipelined CPU against the reference ---");
        ck("$t0", p.u_rf.regs[ 8], 32'h0000000A);
        ck("$t1", p.u_rf.regs[ 9], 32'h00000003);
        ck("$t2", p.u_rf.regs[10], 32'h0000000D);
        ck("$t3", p.u_rf.regs[11], 32'h0000000A);
        ck("$t4", p.u_rf.regs[12], 32'h00000008);
        ck("$t5", p.u_rf.regs[13], 32'h0000000F);
        ck("$t6", p.u_rf.regs[14], 32'h00000007);
        ck("$t7", p.u_rf.regs[15], 32'h00000034);
        ck("$s0", p.u_rf.regs[16], 32'h00000006);
        ck("$s1", p.u_rf.regs[17], 32'h00000001);
        ck("$s2", p.u_rf.regs[18], 32'h12345678);
        ck("$s3", p.u_rf.regs[19], 32'h00002000);
        ck("$s4", p.u_rf.regs[20], 32'h0000000D);
        ck("$s5", p.u_rf.regs[21], 32'h0000000E);   // load-use: needs the stall
        ck("$s6", p.u_rf.regs[22], 32'h00000001);   // branch not taken
        ck("$s7", p.u_rf.regs[23], 32'h00000000);   // branch taken: needs flush
        ck("$t8", p.u_rf.regs[24], 32'h0000002A);
        ck("$t9", p.u_rf.regs[25], 32'h00000063);
        ck("$a0", p.u_rf.regs[ 4], 32'hDEADBEEF);
        ck("mem0", p.u_dmem.mem[0], 32'h0000000D);
        ck("mem1", p.u_dmem.mem[1], 32'hDEADBEEF);

        //------------------------------------------- the two CPUs agree
        $display("");
        $display("  --- the two CPUs, register for register ---");
        for (r = 1; r < 32; r = r + 1) begin
            sv = s.u_rf.regs[r];
            pv = p.u_rf.regs[r];
            if (sv !== pv) begin
                mismatched = mismatched + 1;
                $display("  DIFFER  r%0d  single %08h  pipelined %08h", r, sv, pv);
            end
        end
        if (mismatched == 0)
            $display("  all 31 registers identical");

        //--------------------------------------------------- performance
        $display("");
        $display("  --- performance ---");
        $display("  dynamic instructions        %0d", INSTRS);
        $display("  single-cycle, cycles        %0d   (CPI 1.00 by construction)",
                 s_cycles);
        $display("  pipelined, cycles           %0d", p_cycles);
        $display("    of which stall cycles     %0d", p_stalls);
        $display("    of which flush cycles     %0d", p_flushes);
        $display("");
        $display("  pipelined CPI               %0d.%02d",
                 p_cycles / INSTRS, ((p_cycles * 100) / INSTRS) % 100);
        $display("  cycle overhead              %0d.%02dx",
                 p_cycles / s_cycles, ((p_cycles * 100) / s_cycles) % 100);
        $display("");
        $display("  More cycles in the pipeline is expected: four to fill,");
        $display("  one per stall, three per taken branch. The speedup comes");
        $display("  from the clock period, which synthesis will give you.");
        $display("  Execution time = cycles / Fmax - report both.");

        $display("");
        $display("  passed %0d   failed %0d   register mismatches %0d",
                 passed, failed, mismatched);
        if (failed == 0 && mismatched == 0)
            $display("  HAZARD LOGIC COMPLETE - the unpadded program runs correctly");
        else
            $display("  not there yet - see above");
        $display("=================================================");
        $display("");
        $finish;
    end

endmodule
