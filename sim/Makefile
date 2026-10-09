# Run from this folder:  make questa | make vcs | make xrun
TEST ?= max5_basic_test

questa:
	qrun -uvm -f files.f -top tb_top +UVM_TESTNAME=$(TEST) -l sim.log

vcs:
	vcs -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps -f files.f -top tb_top -o simv -l comp.log
	./simv +UVM_TESTNAME=$(TEST) -l sim.log

xrun:
	xrun -uvm -f files.f -top tb_top +UVM_TESTNAME=$(TEST) -l sim.log

clean:
	rm -rf qrun.out work simv simv.daidir csrc xcelium.d *.log *.vcd *.key ucli.key transcript

.PHONY: questa vcs xrun clean
