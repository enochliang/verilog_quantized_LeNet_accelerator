# You can only modify "cycle" and "read files"
set cycle 13.8
read_file -format verilog { ../hdl/lenet_18B_opt3.v  }

source compile.tcl
