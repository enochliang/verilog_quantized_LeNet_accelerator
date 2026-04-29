# You can only modify "cycle" and "read files"
set cycle 13.9
read_file -format verilog { ../hdl/lenet_18B_opt2.v  }

source compile.tcl
