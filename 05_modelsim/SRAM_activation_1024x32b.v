module SRAM_activation_1024x32b( 
    input wire clk,
    input wire [ 3:0] wea0,
    input wire [15:0] addr0,
    input wire [31:0] wdata0,
    output wire [31:0] rdata0,
    input wire [ 3:0] wea1,
    input wire [15:0] addr1,
    input wire [31:0] wdata1,
    output wire [31:0] rdata1
);

wire [7:0] rdata_from_bram0[0:3];
wire [7:0] rdata_from_bram1[0:3];
wire [7:0] wdata_to_bram0[0:3];
wire [7:0] wdata_to_bram1[0:3];

assign {wdata_to_bram0[3],wdata_to_bram0[2],wdata_to_bram0[1],wdata_to_bram0[0]} = wdata0;
assign {wdata_to_bram1[3],wdata_to_bram1[2],wdata_to_bram1[1],wdata_to_bram1[0]} = wdata1;


assign rdata0 = {rdata_from_bram0[3],rdata_from_bram0[2],rdata_from_bram0[1],rdata_from_bram0[0]};
assign rdata1 = {rdata_from_bram1[3],rdata_from_bram1[2],rdata_from_bram1[1],rdata_from_bram1[0]};


generate
    genvar i;
    for(i=0;i<4;i=i+1)begin:gen_bram
        BRAM_2048x8 BRAM( .CLK(clk), .A0({1'b0,addr0[9:0]}), .D0(wdata_to_bram0[i]), .Q0(rdata_from_bram0[i]), .WE0(wea0[i]), .WEM0(8'b00000000), .CE0(1'b1), .A1({1'b0,addr1[9:0]}), .D1(wdata_to_bram1[i]), .Q1(rdata_from_bram1[i]), .WE1(wea1[i]), .WEM1(8'b00000000), .CE1(1'b1) );
    end
endgenerate

endmodule