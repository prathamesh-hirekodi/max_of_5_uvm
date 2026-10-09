// Transaction: one cycle of stimulus (DATA / IDLE / RESET).
// The monitor and predictor also use it to carry DUT outputs.
class max5_item extends uvm_sequence_item;
    rand kind_e      kind;
    rand bit [W-1:0] data;

    // filled in by the monitor / predictor
    int              cycle;
    bit [W-1:0]      data_out;
    bit [W-1:0]      max_out;

    `uvm_object_utils_begin(max5_item)
        `uvm_field_enum(kind_e, kind, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(data_out, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(max_out, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_object_utils_end

    function new(string name = "max5_item");
        super.new(name);
    endfunction
endclass
