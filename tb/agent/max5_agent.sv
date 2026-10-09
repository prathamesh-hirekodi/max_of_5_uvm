// Active agent: sequencer + driver + monitor
class max5_agent extends uvm_agent;
    `uvm_component_utils(max5_agent)

    max5_sequencer seqr;
    max5_driver    drv;
    max5_monitor   mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = max5_sequencer::type_id::create("seqr", this);
        drv  = max5_driver::type_id::create("drv", this);
        mon  = max5_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass
