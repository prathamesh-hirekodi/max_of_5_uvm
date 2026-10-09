`timescale 1ns/1ps
// Package: pulls in every UVM component in dependency order
package max5_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam int W    = 8;            // data width
    localparam int MAXV = (1 << W) - 1;
    localparam int WIN  = 5;            // window size

    typedef enum {DATA, IDLE, RESET} kind_e;

    // agent
    `include "agent/max5_item.sv"
    `include "agent/max5_sequencer.sv"
    `include "agent/max5_driver.sv"
    `include "agent/max5_monitor.sv"
    `include "agent/max5_agent.sv"

    // sequences
    `include "seq/max5_basic_seq.sv"

    // env
    `include "env/max5_predictor.sv"
    `include "env/max5_scoreboard.sv"
    `include "env/max5_env.sv"

    // tests
    `include "tests/max5_basic_test.sv"
endpackage
