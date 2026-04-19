module SRAM_weight_16384x32b( 
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

wire [7:0] rdata_from_bram0[0:31];
wire [7:0] rdata_from_bram1[0:31];
wire [7:0] wdata_to_bram0[0:31];
wire [7:0] wdata_to_bram1[0:31];

wire wea0_wire [0:31];
wire wea1_wire [0:31];

//========================================
assign wdata_to_bram0[0]  = wdata0[7:0];
assign wdata_to_bram0[1]  = wdata0[15:8];
assign wdata_to_bram0[2]  = wdata0[23:16];
assign wdata_to_bram0[3]  = wdata0[31:24];
assign wdata_to_bram0[4]  = wdata0[7:0];
assign wdata_to_bram0[5]  = wdata0[15:8];
assign wdata_to_bram0[6]  = wdata0[23:16];
assign wdata_to_bram0[7]  = wdata0[31:24];
assign wdata_to_bram0[8]  = wdata0[7:0];
assign wdata_to_bram0[9]  = wdata0[15:8];
assign wdata_to_bram0[10] = wdata0[23:16];
assign wdata_to_bram0[11] = wdata0[31:24];
assign wdata_to_bram0[12] = wdata0[7:0];
assign wdata_to_bram0[13] = wdata0[15:8];
assign wdata_to_bram0[14] = wdata0[23:16];
assign wdata_to_bram0[15] = wdata0[31:24];
assign wdata_to_bram0[16] = wdata0[7:0];
assign wdata_to_bram0[17] = wdata0[15:8];
assign wdata_to_bram0[18] = wdata0[23:16];
assign wdata_to_bram0[19] = wdata0[31:24];
assign wdata_to_bram0[20] = wdata0[7:0];
assign wdata_to_bram0[21] = wdata0[15:8];
assign wdata_to_bram0[22] = wdata0[23:16];
assign wdata_to_bram0[23] = wdata0[31:24];
assign wdata_to_bram0[24] = wdata0[7:0];
assign wdata_to_bram0[25] = wdata0[15:8];
assign wdata_to_bram0[26] = wdata0[23:16];
assign wdata_to_bram0[27] = wdata0[31:24];
assign wdata_to_bram0[28] = wdata0[7:0];
assign wdata_to_bram0[29] = wdata0[15:8];
assign wdata_to_bram0[30] = wdata0[23:16];
assign wdata_to_bram0[31] = wdata0[31:24];

assign wdata_to_bram1[0]  = wdata1[7:0];
assign wdata_to_bram1[1]  = wdata1[15:8];
assign wdata_to_bram1[2]  = wdata1[23:16];
assign wdata_to_bram1[3]  = wdata1[31:24];
assign wdata_to_bram1[4]  = wdata1[7:0];
assign wdata_to_bram1[5]  = wdata1[15:8];
assign wdata_to_bram1[6]  = wdata1[23:16];
assign wdata_to_bram1[7]  = wdata1[31:24];
assign wdata_to_bram1[8]  = wdata1[7:0];
assign wdata_to_bram1[9]  = wdata1[15:8];
assign wdata_to_bram1[10] = wdata1[23:16];
assign wdata_to_bram1[11] = wdata1[31:24];
assign wdata_to_bram1[12] = wdata1[7:0];
assign wdata_to_bram1[13] = wdata1[15:8];
assign wdata_to_bram1[14] = wdata1[23:16];
assign wdata_to_bram1[15] = wdata1[31:24];
assign wdata_to_bram1[16] = wdata1[7:0];
assign wdata_to_bram1[17] = wdata1[15:8];
assign wdata_to_bram1[18] = wdata1[23:16];
assign wdata_to_bram1[19] = wdata1[31:24];
assign wdata_to_bram1[20] = wdata1[7:0];
assign wdata_to_bram1[21] = wdata1[15:8];
assign wdata_to_bram1[22] = wdata1[23:16];
assign wdata_to_bram1[23] = wdata1[31:24];
assign wdata_to_bram1[24] = wdata1[7:0];
assign wdata_to_bram1[25] = wdata1[15:8];
assign wdata_to_bram1[26] = wdata1[23:16];
assign wdata_to_bram1[27] = wdata1[31:24];
assign wdata_to_bram1[28] = wdata1[7:0];
assign wdata_to_bram1[29] = wdata1[15:8];
assign wdata_to_bram1[30] = wdata1[23:16];
assign wdata_to_bram1[31] = wdata1[31:24];
//==========================================


//==========================================
assign rdata0 = (addr0[13]) ? ((addr0[12]) ? ((addr0[11]) ? {rdata_from_bram0[31],rdata_from_bram0[30],rdata_from_bram0[29],rdata_from_bram0[28]} : {rdata_from_bram0[27],rdata_from_bram0[26],rdata_from_bram0[25],rdata_from_bram0[24]} ) 
                                           : ((addr0[11]) ? {rdata_from_bram0[23],rdata_from_bram0[22],rdata_from_bram0[21],rdata_from_bram0[20]} : {rdata_from_bram0[19],rdata_from_bram0[18],rdata_from_bram0[17],rdata_from_bram0[16]} ) )
                            : ((addr0[12]) ? ((addr0[11]) ? {rdata_from_bram0[15],rdata_from_bram0[14],rdata_from_bram0[13],rdata_from_bram0[12]} : {rdata_from_bram0[11],rdata_from_bram0[10],rdata_from_bram0[9] ,rdata_from_bram0[8] } ) 
                                           : ((addr0[11]) ? {rdata_from_bram0[7] ,rdata_from_bram0[6] ,rdata_from_bram0[5] ,rdata_from_bram0[4] } : {rdata_from_bram0[3] ,rdata_from_bram0[2] ,rdata_from_bram0[1] ,rdata_from_bram0[0] } ) );

assign rdata1 = (addr1[13]) ? ((addr1[12]) ? ((addr1[11]) ? {rdata_from_bram1[31],rdata_from_bram1[30],rdata_from_bram1[29],rdata_from_bram1[28]} : {rdata_from_bram1[27],rdata_from_bram1[26],rdata_from_bram1[25],rdata_from_bram1[24]} ) 
                                           : ((addr1[11]) ? {rdata_from_bram1[23],rdata_from_bram1[22],rdata_from_bram1[21],rdata_from_bram1[20]} : {rdata_from_bram1[19],rdata_from_bram1[18],rdata_from_bram1[17],rdata_from_bram1[16]} ) )
                            : ((addr1[12]) ? ((addr1[11]) ? {rdata_from_bram1[15],rdata_from_bram1[14],rdata_from_bram1[13],rdata_from_bram1[12]} : {rdata_from_bram1[11],rdata_from_bram1[10],rdata_from_bram1[9] ,rdata_from_bram1[8] } ) 
                                           : ((addr1[11]) ? {rdata_from_bram1[7] ,rdata_from_bram1[6] ,rdata_from_bram1[5] ,rdata_from_bram1[4] } : {rdata_from_bram1[3] ,rdata_from_bram1[2] ,rdata_from_bram1[1] ,rdata_from_bram1[0] } ) );
//==========================================

//==========================================
assign wea0_wire[0]  = (addr0[13:11] == 3'd0) ? wea0[0] : 1'b0;
assign wea0_wire[1]  = (addr0[13:11] == 3'd0) ? wea0[1] : 1'b0;
assign wea0_wire[2]  = (addr0[13:11] == 3'd0) ? wea0[2] : 1'b0;
assign wea0_wire[3]  = (addr0[13:11] == 3'd0) ? wea0[3] : 1'b0;
assign wea0_wire[4]  = (addr0[13:11] == 3'd1) ? wea0[0] : 1'b0;
assign wea0_wire[5]  = (addr0[13:11] == 3'd1) ? wea0[1] : 1'b0;
assign wea0_wire[6]  = (addr0[13:11] == 3'd1) ? wea0[2] : 1'b0;
assign wea0_wire[7]  = (addr0[13:11] == 3'd1) ? wea0[3] : 1'b0;
assign wea0_wire[8]  = (addr0[13:11] == 3'd2) ? wea0[0] : 1'b0;
assign wea0_wire[9]  = (addr0[13:11] == 3'd2) ? wea0[1] : 1'b0;
assign wea0_wire[10] = (addr0[13:11] == 3'd2) ? wea0[2] : 1'b0;
assign wea0_wire[11] = (addr0[13:11] == 3'd2) ? wea0[3] : 1'b0;
assign wea0_wire[12] = (addr0[13:11] == 3'd3) ? wea0[0] : 1'b0;
assign wea0_wire[13] = (addr0[13:11] == 3'd3) ? wea0[1] : 1'b0;
assign wea0_wire[14] = (addr0[13:11] == 3'd3) ? wea0[2] : 1'b0;
assign wea0_wire[15] = (addr0[13:11] == 3'd3) ? wea0[3] : 1'b0;
assign wea0_wire[16] = (addr0[13:11] == 3'd4) ? wea0[0] : 1'b0;
assign wea0_wire[17] = (addr0[13:11] == 3'd4) ? wea0[1] : 1'b0;
assign wea0_wire[18] = (addr0[13:11] == 3'd4) ? wea0[2] : 1'b0;
assign wea0_wire[19] = (addr0[13:11] == 3'd4) ? wea0[3] : 1'b0;
assign wea0_wire[20] = (addr0[13:11] == 3'd5) ? wea0[0] : 1'b0;
assign wea0_wire[21] = (addr0[13:11] == 3'd5) ? wea0[1] : 1'b0;
assign wea0_wire[22] = (addr0[13:11] == 3'd5) ? wea0[2] : 1'b0;
assign wea0_wire[23] = (addr0[13:11] == 3'd5) ? wea0[3] : 1'b0;
assign wea0_wire[24] = (addr0[13:11] == 3'd6) ? wea0[0] : 1'b0;
assign wea0_wire[25] = (addr0[13:11] == 3'd6) ? wea0[1] : 1'b0;
assign wea0_wire[26] = (addr0[13:11] == 3'd6) ? wea0[2] : 1'b0;
assign wea0_wire[27] = (addr0[13:11] == 3'd6) ? wea0[3] : 1'b0;
assign wea0_wire[28] = (addr0[13:11] == 3'd7) ? wea0[0] : 1'b0;
assign wea0_wire[29] = (addr0[13:11] == 3'd7) ? wea0[1] : 1'b0;
assign wea0_wire[30] = (addr0[13:11] == 3'd7) ? wea0[2] : 1'b0;
assign wea0_wire[31] = (addr0[13:11] == 3'd7) ? wea0[3] : 1'b0;

assign wea1_wire[0]  = (addr1[13:11] == 3'd0) ? wea1[0] : 1'b0;
assign wea1_wire[1]  = (addr1[13:11] == 3'd0) ? wea1[1] : 1'b0;
assign wea1_wire[2]  = (addr1[13:11] == 3'd0) ? wea1[2] : 1'b0;
assign wea1_wire[3]  = (addr1[13:11] == 3'd0) ? wea1[3] : 1'b0;
assign wea1_wire[4]  = (addr1[13:11] == 3'd1) ? wea1[0] : 1'b0;
assign wea1_wire[5]  = (addr1[13:11] == 3'd1) ? wea1[1] : 1'b0;
assign wea1_wire[6]  = (addr1[13:11] == 3'd1) ? wea1[2] : 1'b0;
assign wea1_wire[7]  = (addr1[13:11] == 3'd1) ? wea1[3] : 1'b0;
assign wea1_wire[8]  = (addr1[13:11] == 3'd2) ? wea1[0] : 1'b0;
assign wea1_wire[9]  = (addr1[13:11] == 3'd2) ? wea1[1] : 1'b0;
assign wea1_wire[10] = (addr1[13:11] == 3'd2) ? wea1[2] : 1'b0;
assign wea1_wire[11] = (addr1[13:11] == 3'd2) ? wea1[3] : 1'b0;
assign wea1_wire[12] = (addr1[13:11] == 3'd3) ? wea1[0] : 1'b0;
assign wea1_wire[13] = (addr1[13:11] == 3'd3) ? wea1[1] : 1'b0;
assign wea1_wire[14] = (addr1[13:11] == 3'd3) ? wea1[2] : 1'b0;
assign wea1_wire[15] = (addr1[13:11] == 3'd3) ? wea1[3] : 1'b0;
assign wea1_wire[16] = (addr1[13:11] == 3'd4) ? wea1[0] : 1'b0;
assign wea1_wire[17] = (addr1[13:11] == 3'd4) ? wea1[1] : 1'b0;
assign wea1_wire[18] = (addr1[13:11] == 3'd4) ? wea1[2] : 1'b0;
assign wea1_wire[19] = (addr1[13:11] == 3'd4) ? wea1[3] : 1'b0;
assign wea1_wire[20] = (addr1[13:11] == 3'd5) ? wea1[0] : 1'b0;
assign wea1_wire[21] = (addr1[13:11] == 3'd5) ? wea1[1] : 1'b0;
assign wea1_wire[22] = (addr1[13:11] == 3'd5) ? wea1[2] : 1'b0;
assign wea1_wire[23] = (addr1[13:11] == 3'd5) ? wea1[3] : 1'b0;
assign wea1_wire[24] = (addr1[13:11] == 3'd6) ? wea1[0] : 1'b0;
assign wea1_wire[25] = (addr1[13:11] == 3'd6) ? wea1[1] : 1'b0;
assign wea1_wire[26] = (addr1[13:11] == 3'd6) ? wea1[2] : 1'b0;
assign wea1_wire[27] = (addr1[13:11] == 3'd6) ? wea1[3] : 1'b0;
assign wea1_wire[28] = (addr1[13:11] == 3'd7) ? wea1[0] : 1'b0;
assign wea1_wire[29] = (addr1[13:11] == 3'd7) ? wea1[1] : 1'b0;
assign wea1_wire[30] = (addr1[13:11] == 3'd7) ? wea1[2] : 1'b0;
assign wea1_wire[31] = (addr1[13:11] == 3'd7) ? wea1[3] : 1'b0;
//=============================================

generate
    genvar i;
    for(i=0;i<32;i=i+1)begin:gen_bram
        BRAM_2048x8 BRAM( .CLK(clk), .A0(addr0[10:0]), .D0(wdata_to_bram0[i]), .Q0(rdata_from_bram0[i]), .WE0(wea0_wire[i]), .WEM0(8'b00000000), .CE0(1'b1), .A1(addr1[10:0]), .D1(wdata_to_bram1[i]), .Q1(rdata_from_bram1[i]), .WE1(wea1_wire[i]), .WEM1(8'b00000000), .CE1(1'b1) );
    end
endgenerate

endmodule