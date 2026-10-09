// Basic test: runs max5_basic_seq (reset, then the spec table).
//   in : 3 10  4  7  2 12 13  1
//   max: 3 10 10 10 10 12 13 13
class max5_basic_test extends uvm_test;
    `uvm_component_utils(max5_basic_test)

    max5_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = max5_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        uvm_root::get().print_topology();
    endfunction

    task run_phase(uvm_phase phase);
        max5_basic_seq seq = max5_basic_seq::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass
