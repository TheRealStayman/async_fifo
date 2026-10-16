/* =============================================================================
 * FILE: tb_pkg.sv
 * -----------------------------------------------------------------------------
 * 1. WHAT IS THIS FILE? (EVERYDAY ANALOGY)
 *    A package is like a single binder where you clip all your testbench class 
 *    sheets together. Instead of having to include 5 separate files in your 
 *    top level, you just import this one binder.
 *
 * 2. KEY VOCABULARY (LAYMAN'S EXPLANATION + PROFESSIONAL TERM)
 *    - Shared binder / folder (Package / `package`): A SystemVerilog container 
 *      used to group classes, types, and functions together.
 *    - Make everything visible (Wildcard import / `import tb_pkg::*`): A line of 
 *      code that makes all the items inside the binder available to use.
 *
 * 3. STEP-BY-STEP BUILD INSTRUCTIONS (LEGO STYLE)
 *    Step 1: Wrap the file in `package tb_pkg; ... endpackage`.
 *    Step 2: Inside, use `` `include `` to add the files in dependency order:
 *            1. `transaction.sv`  (Must be first! Everyone uses the card)
 *            2. `generator.sv`
 *            3. `driver.sv`
 *            4. `monitor.sv`
 *            5. `scoreboard.sv`
 *    *NOTE:* Do NOT include `fifo_if.sv` here. Interfaces contain physical wires 
 *    and must be compiled separately, not inside a package!
 * ============================================================================= */

`ifndef TB_PKG_SV
`define TB_PKG_SV

package tb_pkg;
    `include "transaction.sv"
    `include "generator.sv"
    `include "driver.sv"
    `include "monitor.sv"
    `include "scoreboard.sv"
endpackage

`endif