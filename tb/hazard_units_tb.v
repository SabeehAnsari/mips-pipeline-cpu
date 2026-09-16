//==========================================================================
//  hazard_units_tb.v  -  unit tests for forwarding_unit and hazard_unit
//
//  Run this BEFORE wiring either unit into cpu_pipelined. Debugging a
//  forwarding fault inside a running pipeline is far harder than checking
//  the truth table directly.
//
//  Icarus : iverilog -I rtl -o hz.out rtl/forwarding_unit.v rtl/hazard_unit.v tb/hazard_units_tb.v && vvp hz.out
//==========================================================================
`timescale 1ns / 1ps
`include "defines.vh"

module hazard_units_tb;

    integer passed = 0;
    integer failed = 0;

    reg  [4:0] idex_rs, idex_rt, exmem_rd, memwb_rd;
    reg        exmem_rw, memwb_rw;
    wire [1:0] fa, fb;

    reg  [4:0] hz_idex_rt, hz_ifid_rs, hz_ifid_rt;
    reg        hz_memread;
    wire       stall;

    forwarding_unit u_fwd (
        .idex_rs(idex_rs), .idex_rt(idex_rt),
        .exmem_rd(exmem_rd), .exmem_regwrite(exmem_rw),
        .memwb_rd(memwb_rd), .memwb_regwrite(memwb_rw),
        .forward_a(fa), .forward_b(fb)
    );

    hazard_unit u_hz (
        .idex_memread(hz_memread), .idex_rt(hz_idex_rt),
        .ifid_rs(hz_ifid_rs), .ifid_rt(hz_ifid_rt),
        .stall(stall)
    );

    task fw;
        input [8*30:1] name;
        input [4:0] rs, rt, erd, mrd;
        input       erw, mrw;
        input [1:0] want_a, want_b;
        begin
            idex_rs = rs; idex_rt = rt;
            exmem_rd = erd; exmem_rw = erw;
            memwb_rd = mrd; memwb_rw = mrw;
            #1;
            if (fa === want_a && fb === want_b) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("  FAIL  %0s  got a=%b b=%b  want a=%b b=%b",
                         name, fa, fb, want_a, want_b);
            end
        end
    endtask

    task hz;
        input [8*30:1] name;
        input       mr;
        input [4:0] irt, frs, frt;
        input       want;
        begin
            hz_memread = mr; hz_idex_rt = irt;
            hz_ifid_rs = frs; hz_ifid_rt = frt;
            #1;
            if (stall === want) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("  FAIL  %0s  stall=%b  want %b", name, stall, want);
            end
        end
    endtask

    initial begin
        $display("");
        $display("======  forwarding_unit and hazard_unit  ======");

        //--------------------------------------------- forwarding unit
        //                        rs rt  exmem memwb  erw mrw   wantA wantB
        fw("no dependency",        8, 9,   20,   21,   1,  1, `FWD_REG, `FWD_REG);
        fw("A from EX/MEM",        8, 9,    8,   21,   1,  1, `FWD_MEM, `FWD_REG);
        fw("B from EX/MEM",        8, 9,    9,   21,   1,  1, `FWD_REG, `FWD_MEM);
        fw("both from EX/MEM",     8, 8,    8,   21,   1,  1, `FWD_MEM, `FWD_MEM);
        fw("A from MEM/WB",        8, 9,   20,    8,   1,  1, `FWD_WB,  `FWD_REG);
        fw("B from MEM/WB",        8, 9,   20,    9,   1,  1, `FWD_REG, `FWD_WB);
        fw("A EX/MEM beats MEM/WB",8, 9,    8,    8,   1,  1, `FWD_MEM, `FWD_REG);
        fw("B EX/MEM beats MEM/WB",8, 9,    9,    9,   1,  1, `FWD_REG, `FWD_MEM);
        fw("A from each source",   8, 9,    8,    9,   1,  1, `FWD_MEM, `FWD_WB);
        fw("EX/MEM not writing",   8, 9,    8,   21,   0,  1, `FWD_REG, `FWD_REG);
        fw("MEM/WB not writing",   8, 9,   20,    8,   1,  0, `FWD_REG, `FWD_REG);
        fw("neither writing",      8, 9,    8,    9,   0,  0, `FWD_REG, `FWD_REG);
        fw("zero reg not forwarded",0,0,    0,    0,   1,  1, `FWD_REG, `FWD_REG);
        fw("zero in EX/MEM only",  0, 9,    0,   21,   1,  1, `FWD_REG, `FWD_REG);
        fw("zero in MEM/WB only",  8, 0,   20,    0,   1,  1, `FWD_REG, `FWD_REG);
        fw("r31 forwards",        31,31,   31,   21,   1,  1, `FWD_MEM, `FWD_MEM);

        //------------------------------------------------- hazard unit
        //                       memread  idex_rt ifid_rs ifid_rt  want
        hz("load-use on rs",        1,       9,      9,     20,    1'b1);
        hz("load-use on rt",        1,       9,     20,      9,    1'b1);
        hz("load-use on both",      1,       9,      9,      9,    1'b1);
        hz("load, no dependency",   1,       9,     20,     21,    1'b0);
        hz("not a load",            0,       9,      9,      9,    1'b0);
        hz("no load, no match",     0,       9,     20,     21,    1'b0);

        $display("");
        $display("  passed %0d   failed %0d", passed, failed);
        if (failed == 0)
            $display("  both units OK  -  wire them into cpu_pipelined");
        else
            $display("  NOT READY  -  fix the failures above");
        $display("===============================================");
        $display("");
        $finish;
    end

endmodule
