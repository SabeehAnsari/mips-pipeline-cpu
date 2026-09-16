# Five-Stage Pipelined MIPS32 CPU

Course project — Computer Organization and Architecture, BIT.
27 MIPS32 instructions, five stages, full hazard handling.

**Status: complete. Both CPUs working, 179 of 179 checks passing, verified
against MARS 4.5.**

Design reference (instruction encodings, control tables, hazard rules):
see the final report, or the proposal document.

---

## Repository layout

```
rtl/            synthesisable Verilog
tb/             testbenches — do NOT edit, they are the spec
tests/          MIPS assembly, hex dumps, and MARS machine-code dumps
docs/           design documents and the datapath diagram
build.tcl       regenerates the Vivado project from source
synth.tcl       synthesises both CPUs and reports Fmax and area
constraints.xdc 10 ns clock constraint, used by synthesis
```

**Never commit the Vivado project.** `.xpr` files and the `*.sim`, `*.runs`,
`*.cache` directories are version-locked and three people editing them will
conflict constantly. `build.tcl` regenerates everything from the sources.

*For submission this is reversed:* the assignment asks for a Vivado project,
so the zip you hand in must include `vivado_project/` even though Git ignores
it. Delete `synth_cpu_single/` and `synth_cpu_pipelined/` first — they are
throwaway work directories worth hundreds of megabytes.

---

## Current status

| Module | Testbench | Result |
|---|---|---|
| `alu.v` | `tb/alu_tb.v` — 41 checks | **passing** |
| `regfile.v` | `tb/regfile_tb.v` — 13 checks | **passing** |
| `control.v` | `tb/control_tb.v` — 28 checks | **passing** |
| `sign_extend.v` | `tb/leaf_tb.v` — 21 checks | **passing** |
| `imem.v` | `tb/leaf_tb.v` | **passing** |
| `dmem.v` | `tb/leaf_tb.v` | **passing** |
| `forwarding_unit.v` | `tb/hazard_units_tb.v` — 22 checks | **passing** |
| `hazard_unit.v` | `tb/hazard_units_tb.v` | **passing** |
| `cpu_single.v` | `tb/cpu_single_tb.v` — 20 checks | **passing** |
| `cpu_pipelined.v` | `tb/cpu_pipelined_tb.v` — 13 checks | **passing** |
| Both CPUs compared | `tb/cpu_compare_tb.v` — 21 checks | **passing** |
| `alu_control.v` | merged into `control.v` | n/a |
| Performance counters | inside `cpu_pipelined.v` | **working** |

**179 checks passing across eight testbenches. Zero failures.**

**Do not modify `cpu_single.v`.** It is the performance baseline: the
pipelined CPU's results are compared against it register for register, and
that equality is the headline result of the report.

---

## Results

Measured on `tests/05_hazards.asm`, the unpadded program in which every
hazard is real:

| | Single-cycle | Pipelined |
|---|---|---|
| Dynamic instructions | 27 | 27 |
| Clock cycles | 27 | 43 |
| CPI | 1.00 | 1.59 |
| Stall cycles | — | 1 |
| Flush events | — | 4 |
| Instruction slots annulled | — | 12 |

All 31 architectural registers identical between the two CPUs.

The 43 cycles account exactly: 27 useful instructions + 12 annulled by four
flushes + 1 load-use stall + 3 cycles for the last instruction to reach MEM.

MARS 4.5 independently produces the same final register state, and the
machine code it generates matches all three `.hex` files word for word.

Synthesis results (Fmax, LUTs, flip-flops) go in the final report once
`synth.tcl` has been run.

---

## Test programs

| File | Purpose |
|---|---|
| `tests/01_load_use.asm` | load-use hazard — one bubble required |
| `tests/02_forwarding.asm` | data hazards at distance 1 and 2, both operands |
| `tests/03_single_cycle.asm` | integration, 25 instructions, single-cycle CPU |
| `tests/04_pipeline_nops.asm` | full instruction mix, `nop`-padded — isolates the pipeline registers from hazard logic |
| `tests/05_hazards.asm` | the same work unpadded — every hazard live |

Each has a `.hex` file for `$readmemh` and a `.txt` file, which is the
machine-code dump straight out of MARS, submitted as the test-code
deliverable.

---

## Running a testbench

### Vivado (official — use for anything that goes in the report)

Generate the project once:

**Tools → Run Tcl Script…** → select `build.tcl`

That creates `vivado_project/`, adds every file in `rtl/` and `tb/`, adds
`constraints.xdc`, sets the include path for `defines.vh`, and sets both the
synthesis and simulation tops. Then:

1. **File → Project → Open** → `vivado_project/mips_pipeline.xpr`
2. Sources panel → Simulation Sources → right-click a testbench → **Set as Top**
3. Flow Navigator → **Run Simulation → Run Behavioral Simulation**
4. Read the **Tcl Console** for the pass/fail summary

Start with `cpu_compare_tb` — it runs both CPUs on the hardest program and
compares them register by register.

If the project ever misbehaves, delete `vivado_project/` and run `build.tcl`
again. Nothing is lost — it is generated entirely from the sources.

### Headless (no GUI needed)

```
vivado -mode batch -source build.tcl

xvlog -i rtl rtl/*.v tb/cpu_compare_tb.v
xelab -debug typical cpu_compare_tb -s cmp_sim
xsim cmp_sim -runall
```

Useful when the Vivado GUI will not start — batch mode skips it entirely.

### Icarus (fast — use while developing)

Two seconds instead of forty-five. Same results.

```
iverilog -I rtl -o alu.out  rtl/alu.v     tb/alu_tb.v     && vvp alu.out
iverilog -I rtl -o rf.out   rtl/regfile.v tb/regfile_tb.v && vvp rf.out
iverilog -I rtl -o ctl.out  rtl/control.v tb/control_tb.v && vvp ctl.out

iverilog -I rtl -o leaf.out rtl/sign_extend.v rtl/imem.v rtl/dmem.v \
                            tb/leaf_tb.v && vvp leaf.out

iverilog -I rtl -o hz.out   rtl/forwarding_unit.v rtl/hazard_unit.v \
                            tb/hazard_units_tb.v && vvp hz.out

iverilog -I rtl -o cmp.out  rtl/*.v tb/cpu_compare_tb.v && vvp cmp.out
```

The CPU testbenches hold an absolute path to their hex file at the top of
the file — check it matches your clone before the first run.

---

## Synthesis

```
vivado -mode batch -source synth.tcl
```

Synthesises both CPUs separately against `constraints.xdc` and prints worst
negative slack, Fmax, LUTs, flip-flops and block RAM for each. Reports land
in `synth_reports/`.

    Fmax = 1 / (constrained period - worst negative slack)

**The script loads `tests/05_hazards.hex` into the instruction ROM, and this
is not optional.** With an empty ROM the instruction word is a constant, so
synthesis constant-folds the decoder, the ALU and the register file out of
existence and reports a tiny area and a meaningless timing result that still
looks plausible. The script warns if the design comes back under 100 LUTs.

---

## Ground rules

**One module, one testbench, one commit.** Do not start the next module
until the current one passes every check.

**The testbenches are the specification.** If you think a testbench is
wrong, the discussion is about the control table in the report, not about
the test. Change the table first, then the test, then the RTL — in that
order, and tell the other two.

**Sequential logic uses `<=`. Combinational logic uses `=`.** Mixing them
produces a design that simulates one way and synthesises another, and the
failure appears weeks later during implementation.

**Drive every output on every path** in an `always @(*)` block. An output
left unassigned on some path infers a latch. Vivado warns about it; believe
the warning.

**Save the file before you run the testbench.** An editor buffer is not a
file. If results look impossible, check the file actually changed on disk.

---

## Deviations from the proposal

All of these are written up in Section 11 of the final report.

**The branch penalty is 3 cycles, not 2.** The proposal said two. A branch
resolves in MEM, by which time three instructions are in flight behind it in
IF, ID and EX, and all three are annulled. The hardware was always correct;
the error was in the proposal's prose. The measured flush count confirms it:
4 flush events annul 12 instruction slots.

**`alu_control` is merged into `control.v`.** The proposal lists them as
separate modules. The decoder already sees both the opcode and the funct
field, so a second module would only re-decode them.

**`lui` zero-extends its immediate.** Table 5a of the proposal lists this as
a don't-care, which is defensible — `lui` shifts the immediate left by 16, so
the upper bits are discarded either way. The implementation pins it to
zero-extend and the control testbench checks for that, so the final report
states `Z` rather than a don't-care.

**`add`/`addu`, `sub`/`subu` and `addi`/`addiu` map to identical hardware.**
They differ only in whether signed overflow raises an exception, and
exceptions are outside the project's scope.

**The four benchmark programs were not written.** Bubble sort, GCD, Fibonacci
and matrix multiply were promised in the proposal. That time went into the
directed hazard tests and the two-CPU comparison instead, so the performance
figures rest on one program rather than four.

**Branch resolution was not moved to the ID stage.** This was the optional
week-9 optimisation. It would cut the penalty from 3 cycles to 1 — on the
measured program, 8 of the 43 cycles. It remains the clearest available
improvement.

---

## MARS configuration

All three of you must use identical settings, or your test programs will
not agree:

- Settings → **Permit extended (pseudo) instructions and formats** — **OFF**
- Settings → **Delayed branching** — **OFF**
- Settings → Memory Configuration → **Compact, Text at Address 0**

That configuration puts `.text` at `0x00000000` and `.data` at `0x00002000`,
matching `TEXT_BASE` and `DATA_BASE` in `rtl/defines.vh`. Check it by trying
to assemble `li $t1, 10` — MARS must reject it.

To produce a hex file for `$readmemh`:
File → Dump Memory → `.text` → **Hexadecimal Text**.
The result must be bare 8-digit words, one per line. Choosing **Binary**
instead produces a file that looks like garbage in a text editor — that is a
format mistake, not a corrupt dump.

---

## Git from mainland China

GitHub is frequently unreachable on campus networks. If a push times out,
point Git at your proxy — scoped to GitHub only, so domestic mirrors stay
direct:

```
git config --global http.https://github.com.proxy http://127.0.0.1:<port>
```

Use whatever local port your proxy client listens on. If the client runs in
TUN mode, traffic is already routed and no Git configuration is needed at
all — in that case remove the setting, because a stale proxy entry fails
exactly like no network.

```
git config --global --get-regexp proxy      # show what is set
git config --global --unset http.https://github.com.proxy
```

---

## Build order — all complete

1. ~~**ALU** — 12 operations, self-contained, proves the test loop works~~
2. ~~**Register file** — negedge write, `$zero` hardwired~~
3. ~~**Control decoder** — transcription of Tables 5a and 5b~~
4. ~~**Sign extender, memories**~~
5. ~~**Single-cycle integration** — validates the control table before
   pipelining can hide control faults~~
6. ~~**Pipeline registers** — tested with `nop`-padded programs~~
7. ~~**Forwarding** — EX/MEM and MEM/WB into the ALU inputs~~
8. ~~**Load-use stall** — the one hazard forwarding cannot solve~~
9. ~~**Branch and jump flush**~~
10. ~~**Performance counters**~~ — synthesis figures still to be recorded

Steps 6 through 9 were the whole project. Doing them one at a time, each
with its own test program, is what made them debuggable: every failure had
exactly one plausible cause.
