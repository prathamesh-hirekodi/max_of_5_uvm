// Driver: drives on the falling edge so inputs are stable at the rising edge.
// A RESET item holds rst_n low for 2 cycles.
class max5_driver extends uvm_driver #(max5_item);
    `uvm_component_utils(max5_driver)

    virtual max5_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual max5_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        vif.rst_n        <= 0;
        vif.in_valid     <= 0;
        vif.streaming_in <= 0;
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_item(max5_item it);
        @(negedge vif.clk);
        if (it.kind == RESET) begin
            vif.in_valid <= 0;
            vif.rst_n    <= 0;
            repeat (2) @(negedge vif.clk);
            vif.rst_n    <= 1;
        end else begin
            vif.rst_n        <= 1;
            vif.in_valid     <= (it.kind == DATA);
            vif.streaming_in <= it.data;
        end
    endtask
endclass
