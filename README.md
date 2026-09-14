# Five-Stage Pipelined MIPS32 CPU

Course project — Computer Organization and Architecture, BIT.
27 MIPS32 instructions, five stages, full hazard handling.

Design reference (instruction encodings, control tables, hazard rules):
see the proposal document, or the online spec sheet.

---

## Repository layout

```
rtl/        synthesisable Verilog        <- you write these
tb/         testbenches                  <- do NOT edit, they are the spec
tests/      MIPS assembly + hex dumps
docs/       design documents
build.tcl   regenerates the Vivado project from source
```

**Never commit the Vivado project.** `.xpr` files and the `*.sim`, `*.runs`,
`*.cache` directories are version-locked and three people editing them will
conflict constantly. `build.tcl` regenerates everything from the sources.

---

## Running a testbench

### Vivado (official — use for anything that goes in the report)

1. Add the `rtl/` file and its `tb/` file as **simulation sources**
2. Right-click the testbench → **Set as Top**
3. Flow Navigator → **Run Simulation → Run Behavioral Simulation**
4. Read the **Tcl Console**

Vivado needs the include path set for `defines.vh`:
Settings → Simulation → `xsim.compile.xvlog.more_options` → `-i ../../../rtl`

### Icarus (fast — use while developing)

Two seconds instead of forty-five. Same results.

```
iverilog -I rtl -o alu_tb.out    rtl/alu.v     tb/alu_tb.v     && vvp alu_tb.out
iverilog -I rtl -o rf_tb.out     rtl/regfile.v tb/regfile_tb.v && vvp rf_tb.out
iverilog -I rtl -o ctl_tb.out    rtl/control.v tb/control_tb.v && vvp ctl_tb.out
```

Download: <https://bleyer.org/icarus/>

---

## Current status

| Module | Owner | Testbench | Status |
|---|---|---|---|
| `alu.v` | Track A | `tb/alu_tb.v` — 41 checks | not started |
| `regfile.v` | Track A | `tb/regfile_tb.v` — 13 checks | not started |
| `control.v` | Track B | `tb/control_tb.v` — 28 checks | not started |
| `alu_control.v` | — | merged into `control.v` | n/a |
| `sign_extend.v` | Track A | — | not started |
| `imem.v` / `dmem.v` | Track A | — | not started |
| pipeline registers | Track A | — | not started |
| `forwarding_unit.v` | Track B | — | not started |
| `hazard_unit.v` | Track B | — | not started |
| test programs | Track C | — | in progress |

Update this table in every commit that changes a module's status. It is the
fastest way for three people to see where the project actually is.

---

## Ground rules

**One module, one testbench, one commit.** Do not start the next module
until the current one passes every check.

**The testbenches are the specification.** If you think a testbench is
wrong, the discussion is about the control table in the proposal, not
about the test. Change the table first, then the test, then the RTL —
in that order, and tell the other two.

**Sequential logic uses `<=`. Combinational logic uses `=`.** Mixing them
produces a design that simulates one way and synthesises another, and the
failure appears weeks later during implementation.

**Drive every output on every path** in an `always @(*)` block. An output
left unassigned on some path infers a latch. Vivado warns about it; believe
the warning.

---

## MARS configuration

All three of you must use identical settings, or your test programs will
not agree:

- Settings → **Permit extended (pseudo) instructions and formats** — **OFF**
- Settings → **Delayed branching** — **OFF**
- Settings → Memory Configuration → **Compact, Text at Address 0**

That configuration puts `.text` at `0x00000000` and `.data` at `0x00002000`.
Check it by trying to assemble `li $t1, 10` — MARS must reject it.

To produce a hex file for `$readmemh`:
File → Dump Memory → `.text` → **Hexadecimal Text**.
The result must be bare 8-digit words, one per line, with no `0x` prefix.

---

## Build order

1. **ALU** — 12 operations, self-contained, proves the test loop works
2. **Register file** — negedge write, `$zero` hardwired
3. **Control decoder** — transcription of Tables 5a and 5b
4. **Sign extender, memories**
5. **Single-cycle integration** — validates the control table before
   pipelining can hide control faults
6. **Pipeline registers** — test with `nop`-padded programs, no hazards yet
7. **Forwarding**
8. **Load-use stall**
9. **Branch and jump flush**
10. **Performance counters, benchmarks, synthesis**

Steps 6 through 9 are the whole project. Do them one at a time, each with
its own test program. Teams that enable all hazard handling at once and
then start debugging do not finish.
