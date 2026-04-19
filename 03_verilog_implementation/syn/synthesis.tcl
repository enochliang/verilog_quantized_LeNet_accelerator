# You can only modify "cycle" and "read files"
set cycle 19.3
read_file -format verilog { ../hdl/lenet_18B.v  }

source compile.tcl
