//==========================================================================
//  regfile_tb.v  -  self-checking testbench for the register file
//
//  Do not edit. Run it, fix regfile.v until it passes.
//
//  Icarus : iverilog -I rtl -o rf_tb.out rtl/regfile.v tb/regfile_tb.v && vvp rf_tb.out
//==========================================================================
`timescale 1ns / 1ps

module regfile_tb;

    reg         clk = 0;
    reg  [4:0]  ra1 = 0, ra2 = 0, wa = 0;
    reg  [31:0] wd  = 0;
    reg         we  = 0;
    wire [31:0] rd1, rd2;

    integer passed = 0;
    integer failed = 0;

    regfile dut (.clk(clk), .ra1(ra1), .ra2(ra2), .wa(wa),
                 .wd(wd), .we(we), .rd1(rd1), .rd2(rd2));

    always #5 clk = ~clk;          // 10 ns period

    task expect1;
        input [8*24:1] name;
        input [31:0]   want;
        begin
            if (rd1 === want) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("  FAIL  %0s  rd1 got %08h  want %08h", name, rd1, want);
            end
        end
    endtask

    task expect2;
        input [8*24:1] name;
        input [31:0]   want;
        begin
            if (rd2 === want) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("  FAIL  %0s  rd2 got %08h  want %08h", name, rd2, want);
            end
        end
    endtask

    // Write value v into register r over one full clock cycle.
    // Inputs change 1 ns after an edge, never on one, so there is no race
    // between this testbench and the design under test.
    task write_reg;
        input [4:0]  r;
        input [31:0] v;
        begin
            @(posedge clk); #1;
            wa = r; wd = v; we = 1;
            @(negedge clk); #1;    // a negedge-write design writes here
            @(posedge clk); #1;
            we = 0;
        end
    endtask

    initial begin
        $display("");
        $display("==============  register file testbench  ==============");

        // everything starts at zero
        @(posedge clk);
        ra1 = 5'd7; ra2 = 5'd9; #1;
        expect1("r7 starts zero", 32'd0);
        expect2("r9 starts zero", 32'd0);

        // basic write then read
        write_reg(5'd7, 32'hDEADBEEF);
        ra1 = 5'd7; #1;
        expect1("write/read r7", 32'hDEADBEEF);

        // a different register is untouched
        ra1 = 5'd8; #1;
        expect1("r8 untouched", 32'd0);

        // both ports read independently
        write_reg(5'd9, 32'h12345678);
        ra1 = 5'd7; ra2 = 5'd9; #1;
        expect1("port 1 independent", 32'hDEADBEEF);
        expect2("port 2 independent", 32'h12345678);

        // same register on both ports
        ra1 = 5'd9; ra2 = 5'd9; #1;
        expect1("same reg port 1", 32'h12345678);
        expect2("same reg port 2", 32'h12345678);

        // overwrite
        write_reg(5'd7, 32'hCAFEBABE);
        ra1 = 5'd7; #1;
        expect1("overwrite r7", 32'hCAFEBABE);

        // register 0 must stay zero even when written
        write_reg(5'd0, 32'hFFFFFFFF);
        ra1 = 5'd0; #1;
        expect1("r0 ignores write", 32'd0);

        // write enable low must not write
        @(posedge clk); #1;
        wa = 5'd12; wd = 32'hAAAA5555; we = 0;
        @(negedge clk); #1;
        @(posedge clk); #1;
        ra1 = 5'd12; #1;
        expect1("we low blocks write", 32'd0);

        // highest register works
        write_reg(5'd31, 32'h0000FACE);
        ra1 = 5'd31; #1;
        expect1("r31 works", 32'h0000FACE);

        //-------------------------------------------------------------
        //  The negedge write test - the reason this whole file exists.
        //
        //  Drive a write and read the SAME register in the SAME cycle,
        //  then drop write-enable before the next rising edge. A design
        //  that writes on the FALLING edge has already stored the value
        //  and returns it. A design that writes on the RISING edge never
        //  gets the chance, and returns zero.
        //
        //  In the pipeline this is an instruction in WB writing the
        //  register an instruction in ID is reading. Get it wrong and
        //  perfectly correct forwarding logic still produces wrong
        //  results, which is a miserable thing to debug.
        //-------------------------------------------------------------
        @(posedge clk); #1;
        wa = 5'd20; wd = 32'h5A5A5A5A; we = 1; ra1 = 5'd20;
        @(negedge clk); #1;
        expect1("write visible same cycle", 32'h5A5A5A5A);
        we = 0;

        $display("");
        $display("  passed %0d   failed %0d", passed, failed);
        if (failed == 0)
            $display("  register file OK");
        else
            $display("  register file NOT READY  -  fix the failures above");
        $display("=======================================================");
        $display("");
        $finish;
    end

endmodule
