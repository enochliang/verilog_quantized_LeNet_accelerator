module lenet (
    input wire clk,
    input wire rst_n,

    input wire compute_start,
    output reg compute_finish,

    // Quantization scale
    input wire [31:0] scale_CONV1,
    input wire [31:0] scale_CONV2,
    input wire [31:0] scale_CONV3,
    input wire [31:0] scale_FC1,
    input wire [31:0] scale_FC2,

    // Weight sram, dual port
    output reg [ 3:0] sram_weight_wea0,
    output reg [15:0] sram_weight_addr0,
    output reg [31:0] sram_weight_wdata0,
    input wire [31:0] sram_weight_rdata0,
    output reg [ 3:0] sram_weight_wea1,
    output reg [15:0] sram_weight_addr1,
    output reg [31:0] sram_weight_wdata1,
    input wire [31:0] sram_weight_rdata1,

    // Activation sram, dual port
    output reg [ 3:0] sram_act_wea0,
    output reg [15:0] sram_act_addr0,
    output reg [31:0] sram_act_wdata0,
    input wire [31:0] sram_act_rdata0,
    output reg [ 3:0] sram_act_wea1,
    output reg [15:0] sram_act_addr1,
    output reg [31:0] sram_act_wdata1,
    input wire [31:0] sram_act_rdata1
);
    // Add your design here
    parameter RESET = 4'b0000;
    parameter CONV1 = 4'b0001;
    parameter CONV1_write = 4'b0010;
    parameter CONV2 = 4'b0011;
    parameter CONV2_write = 4'b0100;
    parameter CONV3 = 4'b0101;
    parameter CONV3_write = 4'b0110;
    parameter FC1 = 4'b0111;
    parameter FC1_write = 4'b1000;
    parameter FC2 = 4'b1001;
    parameter FC2_write = 4'b1010;
    parameter OUTPUT = 4'b1011;


    //=====================================
    //    FSM VARs
    //=====================================
    reg [3:0] cur_state, next_state;

    //=====================================
    //    COMPUTE VARs
    //=====================================
    //reg [15:0] next_sram_weight_addr0;
    //reg [15:0] next_sram_weight_addr1;
    reg [15:0] next_sram_weight_addr;

    reg [63:0] weight_buf_1; // 8 * 8bits
    reg [63:0] weight_buf_2; // 8 * 8bits
    reg [63:0] act_buf_1; // 8 * 8bits
    reg [63:0] act_buf_2; // 8 * 8bits
    reg signed [31:0] bias_buf;


    reg [15:0] sram_act_r_addr;
    reg [15:0] sram_act_w_addr;
    reg [15:0] next_sram_act_r_addr;
    reg [15:0] next_sram_act_w_addr;
    reg [4:0]  row_counter;
    reg [5:0]  timer;

    // flag
    reg [4:0] conv_cnt;// conv1: 0~3, conv2: 0~19
    reg [4:0] conv2_cnt;// conv2: 0~24
    reg [2:0] conv_page; // to count the pages in conv2 from 0 to 5
    reg [3:0] conv_kernal_cnt;// to count the kernals in conv2 from 0 to 15

    reg signed [31:0] scale_factor;

    wire conv1_change_row;
    wire conv1_change_kernal;
    wire conv1_w_flag;
    wire conv1_end;

    wire conv2_change_row;
    wire conv2_change_kernal;
    wire conv2_change_page;
    wire conv2_w_flag;
    wire conv2_end;
    wire conv2_once;

    wire conv3_w_flag;
    wire conv3_end;
    wire conv3_once;

    wire fc1_w_flag;
    wire fc1_end;
    wire fc1_once;

    wire fc2_w_flag;
    wire fc2_end;
    wire fc2_once;

    //scale_factor
    always@(*)begin
        case(cur_state)
            CONV1,CONV1_write: scale_factor = scale_CONV1;
            CONV2,CONV2_write: scale_factor = scale_CONV2;
            CONV3,CONV3_write: scale_factor = scale_CONV3;
            FC1,FC1_write: scale_factor = scale_FC1;
            FC2,FC2_write: scale_factor = scale_FC2;
            default:scale_factor = 0;
        endcase
    end

    assign conv1_change_row = (sram_act_r_addr[2:0] == 3'b110) ? 1 : 0;
    assign conv1_change_kernal = ( (sram_act_w_addr == 'd310)||
                                   (sram_act_w_addr == 'd366)||
                                   (sram_act_w_addr == 'd422)||
                                   (sram_act_w_addr == 'd478)||
                                   (sram_act_w_addr == 'd534)) ? 1 : 0;
    // signal to write activations in conv1
    assign conv1_w_flag = (((!conv1_change_row) && (conv_cnt == 3)) || ((conv1_change_row) && (conv_cnt == 2))) ? 1 : 0;
    assign conv1_end = (sram_act_w_addr == 590) ? 1 : 0;


    assign conv2_change_row = (sram_act_r_addr[1:0] == 2'b10) ? 1 : 0;
    assign conv2_change_kernal = (conv2_cnt == 14) ? 1 : 0;
    assign conv2_change_page = ((conv_page != 5) && (timer == 8)) ? 1 : 0;
    assign conv2_w_flag = ((conv_cnt == 1) || (conv_cnt == 6) || (conv_cnt == 11)) ? 1 : 0;
    assign conv2_once = (conv_page == 5 && timer == 9) ? 1 : 0;
    assign conv2_end = ((conv_kernal_cnt == 15) && conv2_change_kernal) ? 1 : 0;
    // && (conv_cnt == 11) && conv2_change_kernal

    assign conv3_w_flag = (conv_cnt == 7) ? 1 : 0;
    assign conv3_end = (conv_kernal_cnt == 14) ? 1 : 0;
    assign conv3_once = (timer == 53) ? 1 : 0 ;

    assign fc1_w_flag = ((conv_cnt == 7) || ((conv_cnt == 3) && (fc1_end))) ? 1 : 0;
    assign fc1_end = (conv_kernal_cnt == 10) ? 1 : 0;
    assign fc1_once = (timer == 18) ? 1 : 0 ;

    //assign fc2_w_flag = ((conv_cnt == 7) || ((conv_cnt == 3) && (fc1_end))) ? 1 : 0;
    assign fc2_end = (conv_cnt == 9) ? 1 : 0;
    assign fc2_once = (timer == 14) ? 1 : 0 ;

    always@(posedge clk)begin
        if(!rst_n) conv_cnt <= 0;
        else begin
            case(cur_state)
                CONV1:if(timer == 9)begin
                    case(conv_cnt)
                        0:conv_cnt <= 1;
                        1:conv_cnt <= 2;
                        2:begin
                            if(!conv1_change_row)conv_cnt <= 3;
                            else                 conv_cnt <= 0;
                        end
                        3:conv_cnt <= 0;
                    endcase
                end
                CONV1_write: conv_cnt <= 0;
                CONV2:if(conv2_once)begin
                    case(conv_cnt)
                        0 :conv_cnt <=  1;
                        1 :conv_cnt <=  2;
                        2 :conv_cnt <=  3;
                        3 :conv_cnt <=  4;
                        4 :conv_cnt <=  5;
                        5 :conv_cnt <=  6;
                        6 :conv_cnt <=  7;
                        7 :conv_cnt <=  8;
                        8 :conv_cnt <=  9;
                        9 :conv_cnt <= 10;
                        10:conv_cnt <= 11;
                        11:conv_cnt <=  0;
                    endcase
                end
                CONV3:if(conv3_once)begin
                    case(conv_cnt)
                        0 :conv_cnt <=  1;
                        1 :conv_cnt <=  2;
                        2 :conv_cnt <=  3;
                        3 :conv_cnt <=  4;
                        4 :conv_cnt <=  5;
                        5 :conv_cnt <=  6;
                        6 :conv_cnt <=  7;
                        7 :conv_cnt <=  0;
                    endcase
                end
                FC1:if(fc1_once)begin
                    case(conv_cnt)
                        0 :conv_cnt <=  1;
                        1 :conv_cnt <=  2;
                        2 :conv_cnt <=  3;
                        3 :conv_cnt <=  4;
                        4 :conv_cnt <=  5;
                        5 :conv_cnt <=  6;
                        6 :conv_cnt <=  7;
                        7 :conv_cnt <=  0;
                    endcase
                end
                FC1_write:if(fc1_end)begin
                    conv_cnt <=  0;
                end
                FC2_write:begin
                    case(conv_cnt)
                        0 :conv_cnt <=  1;
                        1 :conv_cnt <=  2;
                        2 :conv_cnt <=  3;
                        3 :conv_cnt <=  4;
                        4 :conv_cnt <=  5;
                        5 :conv_cnt <=  6;
                        6 :conv_cnt <=  7;
                        7 :conv_cnt <=  8;
                        8 :conv_cnt <=  9;
                        9 :conv_cnt <=  0;
                    endcase
                end
                OUTPUT:conv_cnt <= 0;
            endcase
        end
    end

    always@(posedge clk)begin
        if(!rst_n)conv2_cnt <= 0;
        else begin
            case(cur_state)
                CONV2:begin
                    if(conv2_once) begin
                        case(conv2_cnt)
                            0 : conv2_cnt <=  1;
                            1 : conv2_cnt <=  2;
                            2 : conv2_cnt <=  3;
                            3 : conv2_cnt <=  4;
                            4 : conv2_cnt <=  5;
                            5 : conv2_cnt <=  6;
                            6 : conv2_cnt <=  7;
                            7 : conv2_cnt <=  8;
                            8 : conv2_cnt <=  9;
                            9 : conv2_cnt <= 10;
                            10: conv2_cnt <= 11;
                            11: conv2_cnt <= 12;
                            12: conv2_cnt <= 13;
                            13: conv2_cnt <= 14;
                            14: if(conv_kernal_cnt != 15)conv2_cnt <=  0;
                        endcase
                    end
                end
                OUTPUT:conv2_cnt <= 0;
            endcase
        end
    end

    always@(posedge clk)begin
        if(!rst_n)conv_page <= 0;
        else begin
            case(cur_state)
                CONV2:begin
                    if(conv2_once) conv_page <= 0;
                    else if(conv2_change_page) conv_page <= conv_page + 1;
                end
                OUTPUT:conv_page <= 0;
            endcase
        end
    end

    
    always@(posedge clk)begin
        if(!rst_n)conv_kernal_cnt <= 0;
        else begin
            case(cur_state)
                CONV2:begin
                    if(conv2_once && conv2_change_kernal) begin
                        case(conv_kernal_cnt)
                            0 : conv_kernal_cnt <= 1 ;
                            1 : conv_kernal_cnt <= 2 ;
                            2 : conv_kernal_cnt <= 3 ;
                            3 : conv_kernal_cnt <= 4 ;
                            4 : conv_kernal_cnt <= 5 ;
                            5 : conv_kernal_cnt <= 6 ;
                            6 : conv_kernal_cnt <= 7 ;
                            7 : conv_kernal_cnt <= 8 ;
                            8 : conv_kernal_cnt <= 9 ;
                            9 : conv_kernal_cnt <= 10;
                            10: conv_kernal_cnt <= 11;
                            11: conv_kernal_cnt <= 12;
                            12: conv_kernal_cnt <= 13;
                            13: conv_kernal_cnt <= 14;
                            14: conv_kernal_cnt <= 15;
                        endcase
                    end
                end
                CONV2_write:begin
                    if(conv2_end)conv_kernal_cnt <= 0;
                end
                CONV3_write:begin
                    case(conv_kernal_cnt)
                        0 : conv_kernal_cnt <= 1 ;
                        1 : conv_kernal_cnt <= 2 ;
                        2 : conv_kernal_cnt <= 3 ;
                        3 : conv_kernal_cnt <= 4 ;
                        4 : conv_kernal_cnt <= 5 ;
                        5 : conv_kernal_cnt <= 6 ;
                        6 : conv_kernal_cnt <= 7 ;
                        7 : conv_kernal_cnt <= 8 ;
                        8 : conv_kernal_cnt <= 9 ;
                        9 : conv_kernal_cnt <= 10;
                        10: conv_kernal_cnt <= 11;
                        11: conv_kernal_cnt <= 12;
                        12: conv_kernal_cnt <= 13;
                        13: conv_kernal_cnt <= 14;
                        14: conv_kernal_cnt <= 0 ;
                    endcase
                end
                FC1_write:begin
                    case(conv_kernal_cnt)
                        0 : conv_kernal_cnt <= 1 ;
                        1 : conv_kernal_cnt <= 2 ;
                        2 : conv_kernal_cnt <= 3 ;
                        3 : conv_kernal_cnt <= 4 ;
                        4 : conv_kernal_cnt <= 5 ;
                        5 : conv_kernal_cnt <= 6 ;
                        6 : conv_kernal_cnt <= 7 ;
                        7 : conv_kernal_cnt <= 8 ;
                        8 : conv_kernal_cnt <= 9 ;
                        9 : conv_kernal_cnt <= 10;
                        10: conv_kernal_cnt <= 0;
                    endcase
                end
                OUTPUT:conv_kernal_cnt <= 0;
            endcase
        end
    end
    

    

    // weight_buf_wire, act_buf_wire
    wire [7:0] weight_buf_wire_1[0:7];
    wire [7:0] act_buf_wire_1[0:7];
    wire [7:0] weight_buf_wire_2[0:7];
    wire [7:0] act_buf_wire_2[0:7];
    generate
        genvar i;
        for(i=0;i<8;i=i+1)begin:gen_weight_and_act_buf_wire
            assign weight_buf_wire_1[i] = weight_buf_1[i*8+7:i*8];
            assign weight_buf_wire_2[i] = weight_buf_2[i*8+7:i*8];
            assign act_buf_wire_1[i] = act_buf_1[i*8+7:i*8];
            assign act_buf_wire_2[i] = act_buf_2[i*8+7:i*8];
        end
    endgenerate
    //integer d;
    //-------------------------------------
    /* always@(posedge clk)begin
        if((1))begin
            $write("state: %h",cur_state);
            
            $write(", w_bf:%h",weight_buf_1);
            $write(",\033[31m sram_weight_addr0:%h\033[m",sram_weight_addr0);
            $write(", conv_cnt:%1d",conv_cnt);

            $write(", fc_sum:%d",fc_sum);
            $write(", bias_buf:%d",bias_buf);
            
            //$write(", act_wd0,1:%h,%h",sram_act_wdata0,sram_act_wdata1);
            $write(", timer",timer);
            $display();
        end
        
    end */
    //=====================================
    //    I/O
    //=====================================
    always@(posedge clk)begin
        sram_weight_wea0 <= 4'b0000;
        sram_weight_wea1 <= 4'b0000;
    end
    always@(posedge clk)begin
        case(next_state)
            CONV1_write,CONV3_write:begin
                sram_act_wea0 <= 4'b1111;
                sram_act_wea1 <= 4'b1111;
            end
            CONV2_write:begin
                if(conv_cnt == 1)begin
                    sram_act_wea0 <= 4'b1111;
                    sram_act_wea1 <= 4'b0000;
                end
                else begin
                    sram_act_wea0 <= 4'b1111;
                    sram_act_wea1 <= 4'b1111;
                end
            end
            FC1_write:begin
                if(conv_kernal_cnt == 10)begin
                    sram_act_wea0 <= 4'b1111;
                    sram_act_wea1 <= 4'b0000;
                end
                else begin
                    sram_act_wea0 <= 4'b1111;
                    sram_act_wea1 <= 4'b1111;
                end
            end
            FC2_write:begin
                sram_act_wea0 <= 4'b1111;
                sram_act_wea1 <= 4'b0000;
            end
            default:begin
                sram_act_wea0 <= 4'b0000;
                sram_act_wea1 <= 4'b0000;
            end
        endcase
    end
    always@(posedge clk)begin
        if(!rst_n)compute_finish<=0;
        else begin
            if(cur_state == OUTPUT) compute_finish<=1;
            else if(compute_finish) compute_finish<=0;
        end
    end


    // sram_act_addr0,1
    always@(posedge clk)begin
        case(next_state)
            CONV1_write,CONV2_write,CONV3_write,FC1_write,FC2_write:begin
                sram_act_addr0 <= next_sram_act_w_addr;
                sram_act_addr1 <= next_sram_act_w_addr+1;
            end
            default:begin
                sram_act_addr0 <= next_sram_act_r_addr;
                sram_act_addr1 <= next_sram_act_r_addr+1;
            end
        endcase
    end

    //=====================================
    //    FSM Circuits
    //=====================================
    // cur_state
    always@(posedge clk) begin
        cur_state <= next_state;
    end
    // next_state
    always@(*) begin
        if(!rst_n) next_state = RESET;
        else begin
            case (cur_state)
                RESET:begin
                    if(compute_start) next_state = CONV1;
                    else              next_state = cur_state;
                end
                CONV1:begin
                    if(conv1_w_flag && (timer == 9)) next_state = CONV1_write;
                    else                                  next_state = cur_state;
                end
                CONV1_write:begin
                    if(conv1_end) next_state = CONV2;
                    else next_state = CONV1;
                end
                CONV2:begin
                    if(conv2_w_flag && conv2_once) next_state = CONV2_write;
                    else next_state = cur_state;
                end
                CONV2_write:begin
                    if(conv2_end) next_state = CONV3;
                    else next_state = CONV2;
                end
                CONV3:begin
                    if(conv3_w_flag && conv3_once) next_state = CONV3_write;
                    else next_state = cur_state;
                end
                CONV3_write:begin
                    if(conv3_end) next_state = FC1;
                    else next_state = CONV3;
                end
                FC1:begin
                    if(fc1_w_flag && fc1_once) next_state = FC1_write;
                    else next_state = cur_state;
                end
                FC1_write:begin
                    if(fc1_end) next_state = FC2;
                    else next_state = FC1;
                end
                FC2:begin
                    if(fc2_once) next_state = FC2_write;
                    else next_state = cur_state;
                end
                FC2_write:begin
                    if(fc2_end) next_state = OUTPUT;
                    else next_state = FC2;
                end

                OUTPUT:begin
                    if(compute_finish) next_state = RESET;
                    else               next_state = cur_state;
                end
                default:next_state = cur_state;
            endcase
        end
    end


    
    
    //=====================================
    //    COMPUTE Circuits
    //=====================================
    wire signed [7:0]  mac_A[0:39];
    wire signed [7:0]  mac_B[0:39];
    wire signed [17:0] mac_C[0:39];
    wire signed [17:0] mac_O[0:39];
    reg  signed [17:0] mac_reg[0:39];
    wire signed [17:0] conv_sum[0:7];
    wire signed [17:0] fc_sum;
    wire signed [17:0] pool_out[0:1];
    wire signed [31:0] quantized_pool_out[0:1];
    wire signed [15:0] shifted_pool_out[0:1];
    wire signed [7:0] clamped_pool_out[0:1];
    wire signed [17:0] relued_fc_sum;
    wire signed [31:0] quantized_relued_fc_sum;
    wire signed [31:0] shifted_reluwd_fc_sum;
    wire signed [7:0] clamped_relued_fc_sum;
    wire signed [31:0] quantized_fc_sum;
    wire signed [31:0] shifted_fc_sum;


    // weight_buf, act_buf
    always@(posedge clk)begin
        weight_buf_1 <= {sram_weight_rdata1,sram_weight_rdata0};
        weight_buf_2 <= weight_buf_1;
        act_buf_1 <= {sram_act_rdata1,sram_act_rdata0};
        act_buf_2 <= {sram_act_rdata1,sram_act_rdata0};
        if((cur_state == FC2) && (timer == 11))bias_buf <= sram_weight_rdata1;
    end


    // next_sram_weight_addr
    always@(posedge clk)begin
        if(!rst_n) begin
            sram_weight_addr0 <= 0;
        end
        else begin
            case(cur_state)
                CONV1:begin
                    case(timer)
                        // addr + 2
                        0,1,2,3: begin
                            sram_weight_addr0 <= {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                        end      
                        9:begin
                            // addr - 8
                            sram_weight_addr0 <= {sram_weight_addr0[15:3]-1,sram_weight_addr0[2:0]};
                        end
                    endcase
                end
                CONV1_write:begin
                    // addr + 10 to the head of next kernal
                    if(conv1_change_kernal) begin
                        sram_weight_addr0 <= {sram_weight_addr0[15:1]+5,sram_weight_addr0[0]};
                    end
                    else if(next_state == CONV2) begin
                        sram_weight_addr0 <= 60;
                    end
                end
                CONV2:begin
                    case(timer)
                        // addr + 2
                        0,1,2,3,4: begin
                            sram_weight_addr0 <= {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                        end
                        // addr - 60
                        9:if(!conv2_change_kernal) begin
                            sram_weight_addr0 <= {sram_weight_addr0[15:2]-4'b1111,sram_weight_addr0[1:0]};
                        end
                    endcase
                end
                CONV2_write:begin
                    if(next_state == CONV3) begin
                        sram_weight_addr0 <= 1020;
                    end
                end
                CONV3:begin
                    // addr + 2
                    if(timer < 50) begin
                        sram_weight_addr0 <= sram_weight_addr0+2;
                    end
                end
                FC1:begin
                    // addr + 2
                    if(timer < 15) begin
                        sram_weight_addr0 <= sram_weight_addr0+2;
                    end
                end
                FC2:begin
                    case(timer)
                        0,1,2,3,4,5,6,7,8:begin
                            sram_weight_addr0 <= {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                        end
                        9:begin
                            sram_weight_addr0 <= {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                        end
                        10:begin
                            sram_weight_addr0 <= sram_weight_addr0+1;
                        end
                    endcase
                end
                OUTPUT:begin
                    sram_weight_addr0 <= 'd0;
                end
            endcase
        end
    end
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
            sram_weight_addr1 <= 1;
        end
        else begin
            case(cur_state)
                CONV1:begin
                    case(timer)
                        // addr + 2
                        0,1,2,3: begin
                            sram_weight_addr1 <= {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]}+1;
                        end      
                        9:begin
                            // addr - 8
                            sram_weight_addr1 <= {sram_weight_addr0[15:3]-1,sram_weight_addr0[2:0]}+1;
                        end
                    endcase
                end
                CONV1_write:begin
                    // addr + 10 to the head of next kernal
                    if(conv1_change_kernal) begin
                        sram_weight_addr1 <= {sram_weight_addr0[15:1]+5,sram_weight_addr0[0]}+1;
                    end
                    else if(next_state == CONV2) begin
                        sram_weight_addr1 <= 61;
                    end
                end
                CONV2:begin
                    case(timer)
                        // addr + 2
                        0,1,2,3,4: begin
                            sram_weight_addr1 <= {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]}+1;
                        end
                        // addr - 60
                        9:if(!conv2_change_kernal) begin
                            sram_weight_addr1 <= {sram_weight_addr0[15:2]-4'b1111,sram_weight_addr0[1:0]}+1;
                        end
                    endcase
                end
                CONV2_write:begin
                    if(next_state == CONV3) begin
                        sram_weight_addr1 <= 1021;
                    end
                end
                CONV3:begin
                    // addr + 2
                    if(timer < 50) begin
                        sram_weight_addr1 <= sram_weight_addr0+3;
                    end
                end
                FC1:begin
                    // addr + 2
                    if(timer < 15) begin
                        sram_weight_addr1 <= sram_weight_addr0+3;
                    end
                end
                FC2:begin
                    case(timer)
                        0,1,2,3,4,5,6,7,8:begin
                            sram_weight_addr1 <= {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]}+1;
                        end
                        9:begin
                            case(conv_cnt)
                                0:sram_weight_addr1 <= 15750;
                                1:sram_weight_addr1 <= 15751;
                                2:sram_weight_addr1 <= 15752;
                                3:sram_weight_addr1 <= 15753;
                                4:sram_weight_addr1 <= 15754;
                                5:sram_weight_addr1 <= 15755;
                                6:sram_weight_addr1 <= 15756;
                                7:sram_weight_addr1 <= 15757;
                                8:sram_weight_addr1 <= 15758;
                                9:sram_weight_addr1 <= 15759;
                            endcase
                        end
                        10:begin
                            sram_weight_addr1 <= sram_weight_addr0+2;
                        end
                    endcase
                end
                OUTPUT:begin
                    sram_weight_addr1 <= 'd1;
                end
            endcase
        end
    end
    /* always@(*)begin
        if(!rst_n) begin
            next_sram_weight_addr = 0;
        end
        else begin
            case(cur_state)
                CONV1:begin
                    case(timer)
                        // addr + 2
                        0,1,2,3: begin
                            next_sram_weight_addr = {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                        end      
                        9:begin
                            // addr - 8
                            next_sram_weight_addr = {sram_weight_addr0[15:3]-1,sram_weight_addr0[2:0]};
                        end
                        default: begin
                            next_sram_weight_addr = sram_weight_addr0;
                        end
                    endcase
                end
                CONV1_write:begin
                    // addr + 10 to the head of next kernal
                    if(conv1_change_kernal) begin
                        next_sram_weight_addr = {sram_weight_addr0[15:1]+5,sram_weight_addr0[0]};
                    end
                    else if(next_state == CONV2) begin
                        next_sram_weight_addr = 60;
                    end
                    else begin
                        next_sram_weight_addr = sram_weight_addr0;
                    end
                end
                CONV2:begin
                    case(timer)
                        // addr + 2
                        0,1,2,3,4: begin
                            next_sram_weight_addr = {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                        end
                        // addr - 60
                        9:if(!conv2_change_kernal) begin
                            next_sram_weight_addr = {sram_weight_addr0[15:2]-4'b1111,sram_weight_addr0[1:0]};
                        end
                        default: begin
                            next_sram_weight_addr = sram_weight_addr0;
                        end
                    endcase
                end
                CONV2_write:begin
                    if(next_state == CONV3) begin
                        next_sram_weight_addr = 1020;
                    end
                    else begin
                        next_sram_weight_addr = sram_weight_addr0;
                    end
                end
                CONV3:begin
                    // addr + 2
                    if(timer < 50) begin
                        next_sram_weight_addr = {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                    end
                    else begin
                        next_sram_weight_addr = sram_weight_addr0;
                    end
                end
                FC1:begin
                    // addr + 2
                    if(timer < 15) begin
                        next_sram_weight_addr = {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                    end
                    else begin
                        next_sram_weight_addr = sram_weight_addr0;
                    end
                end
                FC2:begin
                    case(timer)
                        0,1,2,3,4,5,6,7,8:begin
                            next_sram_weight_addr = {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                        end
                        9:begin
                            next_sram_weight_addr = {sram_weight_addr0[15:1]+1,sram_weight_addr0[0]};
                        end
                        10:begin
                            next_sram_weight_addr = sram_weight_addr0+1;
                        end
                        default:begin
                            next_sram_weight_addr = sram_weight_addr0;
                        end
                    endcase
                end
                OUTPUT:begin
                    next_sram_weight_addr = 'd0;
                end
                default:begin
                    next_sram_weight_addr = sram_weight_addr0;
                end
            endcase
        end
    end */
    // sram_weight_addr
    /* always@(posedge clk)begin
        if(!rst_n) begin
            sram_weight_addr0 <= 0;
            sram_weight_addr1 <= 1;
        end
        else begin
            case(cur_state)
                CONV1,CONV1_write,CONV2,CONV2_write,CONV3,FC1,FC2,OUTPUT:begin
                    sram_weight_addr0 <= next_sram_weight_addr0;
                    sram_weight_addr1 <= next_sram_weight_addr1;
                end
            endcase
        end
    end */
    /* always@(posedge clk)begin
        case(cur_state)
            FC2:begin
                case(timer)
                    9:begin
                        sram_weight_addr0 <= next_sram_weight_addr;
                        case(conv_cnt)
                            0:sram_weight_addr1 <= 15750;
                            1:sram_weight_addr1 <= 15751;
                            2:sram_weight_addr1 <= 15752;
                            3:sram_weight_addr1 <= 15753;
                            4:sram_weight_addr1 <= 15754;
                            5:sram_weight_addr1 <= 15755;
                            6:sram_weight_addr1 <= 15756;
                            7:sram_weight_addr1 <= 15757;
                            8:sram_weight_addr1 <= 15758;
                            9:sram_weight_addr1 <= 15759;
                        endcase
                    end
                    default:begin
                        sram_weight_addr0 <= next_sram_weight_addr;
                        sram_weight_addr1 <= next_sram_weight_addr+1;
                    end
                endcase
            end
            default:begin
                sram_weight_addr0 <= next_sram_weight_addr;
                sram_weight_addr1 <= next_sram_weight_addr+1;
            end
        endcase
    end */


    // next_sram_act_r_addr
    always@(*)begin
        if(!rst_n) next_sram_act_r_addr = 0;
        else begin
            case(cur_state)
                CONV1:begin
                    case(timer)
                        // addr + 8
                        0,1,2,3,4: next_sram_act_r_addr = {sram_act_r_addr[15:3]+1,sram_act_r_addr[2:0]};
                        // addr - 40
                        5:         next_sram_act_r_addr = {sram_act_r_addr[15:3]-5,sram_act_r_addr[2:0]};
                        9:begin
                            // addr - 6 + 16
                            if(conv1_change_row) next_sram_act_r_addr = {sram_act_r_addr[15:4]+1,sram_act_r_addr[3],3'b000};
                            // addr + 1
                            else                 next_sram_act_r_addr = sram_act_r_addr+1;
                        end
                        default:next_sram_act_r_addr=sram_act_r_addr;
                    endcase
                end
                CONV1_write:begin
                    if(conv1_change_kernal)next_sram_act_r_addr = 0;
                    else if(next_state == CONV2)next_sram_act_r_addr = 256;
                    else next_sram_act_r_addr=sram_act_r_addr;
                end
                CONV2:begin
                    case(timer)
                        // addr + 4
                        0,1,2,3,4: next_sram_act_r_addr = {sram_act_r_addr[15:2]+1,sram_act_r_addr[1:0]};
                        // addr - 20
                        5:         next_sram_act_r_addr = {sram_act_r_addr[15:2]-5,sram_act_r_addr[1:0]};
                        8:begin
                            if(conv_page == 5) begin
                                // addr - 280 : change back to the first page from the last page
                                next_sram_act_r_addr = {sram_act_r_addr[15:3]-6'b100011,sram_act_r_addr[2:0]};
                            end
                            else begin
                                // addr + 56 : change to the next page
                                next_sram_act_r_addr = {sram_act_r_addr[15:3]+3'b111,sram_act_r_addr[2:0]};
                            end
                        end
                        9:begin
                            if(conv2_change_kernal)next_sram_act_r_addr = 256;
                            // addr - 2 + 8 : change row but not change kernal
                            else if(conv2_change_row) next_sram_act_r_addr = {sram_act_r_addr[15:3]+1,sram_act_r_addr[2],2'b00};
                            // addr + 1
                            else next_sram_act_r_addr = sram_act_r_addr+1;
                        end
                        default:next_sram_act_r_addr=sram_act_r_addr;
                    endcase
                end
                CONV2_write:begin
                    if(conv2_end) next_sram_act_r_addr = 592;
                    else next_sram_act_r_addr=sram_act_r_addr;
                end
                CONV3:begin
                    if(timer<50) next_sram_act_r_addr = {sram_act_r_addr[15:1]+1,sram_act_r_addr[0]};
                    else if(timer == 53) next_sram_act_r_addr = 592;
                    else next_sram_act_r_addr=sram_act_r_addr;
                end
                CONV3_write:begin
                    if (next_state == FC1) next_sram_act_r_addr = 692;
                    else next_sram_act_r_addr=sram_act_r_addr;
                end
                FC1:begin
                    if(timer<15) next_sram_act_r_addr = {sram_act_r_addr[15:1]+1,sram_act_r_addr[0]};
                    else if(timer == 18) next_sram_act_r_addr = 692;
                    else next_sram_act_r_addr=sram_act_r_addr;
                end
                FC1_write:begin
                    if (next_state == FC2) next_sram_act_r_addr = 722;
                    else next_sram_act_r_addr=sram_act_r_addr;
                end
                FC2:begin
                    if(timer<10) next_sram_act_r_addr = {sram_act_r_addr[15:1]+1,sram_act_r_addr[0]};
                    else if(timer == 10) next_sram_act_r_addr = sram_act_r_addr+1;
                    else next_sram_act_r_addr=sram_act_r_addr;
                end
                FC2_write:begin
                    next_sram_act_r_addr = 722;
                end
                OUTPUT:next_sram_act_r_addr = 0;
                default:next_sram_act_r_addr=sram_act_r_addr;
            endcase
        end
    end
    // sram_act_r_addr
    always@(posedge clk)begin
        if(!rst_n) sram_act_r_addr <= 0;
        else begin
            sram_act_r_addr <= next_sram_act_r_addr;
        end
    end

    // next_sram_act_w_addr
    always@(*)begin
        if(!rst_n) next_sram_act_w_addr = 'd256;
        else begin
            case(cur_state)
                CONV1_write,CONV3_write:begin
                    next_sram_act_w_addr = sram_act_w_addr+2;
                end
                CONV2_write:begin
                    if(conv_cnt == 2) next_sram_act_w_addr = sram_act_w_addr+1;
                    else              next_sram_act_w_addr = sram_act_w_addr+2;
                end
                FC1_write:begin
                    if(!fc1_end) next_sram_act_w_addr = sram_act_w_addr+2;
                    else next_sram_act_w_addr = sram_act_w_addr+1;
                end
                FC2_write:begin
                    next_sram_act_w_addr = sram_act_w_addr+1;
                end
                OUTPUT:next_sram_act_w_addr = 'd256;
                default:next_sram_act_w_addr = sram_act_w_addr;
            endcase
        end
    end
    // sram_act_w_addr
    always@(posedge clk)begin
        if(!rst_n) sram_act_w_addr <= 256;
        else begin
            sram_act_w_addr <= next_sram_act_w_addr;
        end
    end

    // sram_act_wdata0, sram_act_wdata1
    always@(posedge clk)begin
        case(cur_state)
            CONV1:begin
                if(timer == 9) begin
                    case(conv_cnt)
                        0:sram_act_wdata0[15:0]  <= {clamped_pool_out[1],clamped_pool_out[0]};
                        1:sram_act_wdata0[31:16] <= {clamped_pool_out[1],clamped_pool_out[0]};
                        2:begin
                            sram_act_wdata1[15:0]  <= {clamped_pool_out[1],clamped_pool_out[0]};
                            if(conv1_change_row)
                            sram_act_wdata1[31:16] <= 0;
                        end
                        3:sram_act_wdata1[31:16] <= {clamped_pool_out[1],clamped_pool_out[0]};
                    endcase
                end
            end
            CONV2:begin
                if(timer == 9) begin
                    case(conv_cnt)
                        0,7:sram_act_wdata0[15:0]  <= {clamped_pool_out[1],clamped_pool_out[0]};
                        1:sram_act_wdata0[31:16] <= {clamped_pool_out[1],clamped_pool_out[0]};
                        //w
                        2:sram_act_wdata0[7:0] <= clamped_pool_out[0];//1
                        3:sram_act_wdata0[23:8] <= {clamped_pool_out[1],clamped_pool_out[0]};
                        4,9:{sram_act_wdata1[7:0],sram_act_wdata0[31:24]} <= {clamped_pool_out[1],clamped_pool_out[0]};
                        5:sram_act_wdata1[15:8] <= clamped_pool_out[0];//1
                        6:sram_act_wdata1[31:16] <= {clamped_pool_out[1],clamped_pool_out[0]};
                        //w
                        //7==========
                        8:sram_act_wdata0[23:16] <= clamped_pool_out[0];//1
                        //9==========
                        10:sram_act_wdata1[23:8] <= {clamped_pool_out[1],clamped_pool_out[0]};
                        11:sram_act_wdata1[31:24] <= clamped_pool_out[0];//1
                    endcase
                end
            end
            CONV3:begin
                if(timer == 53) begin
                    case(conv_cnt)
                        0:sram_act_wdata0[7:0]   <= clamped_relued_fc_sum;
                        1:sram_act_wdata0[15:8]  <= clamped_relued_fc_sum;
                        2:sram_act_wdata0[23:16] <= clamped_relued_fc_sum;
                        3:sram_act_wdata0[31:24] <= clamped_relued_fc_sum;
                        4:sram_act_wdata1[7:0]   <= clamped_relued_fc_sum;
                        5:sram_act_wdata1[15:8]  <= clamped_relued_fc_sum;
                        6:sram_act_wdata1[23:16] <= clamped_relued_fc_sum;
                        7:sram_act_wdata1[31:24] <= clamped_relued_fc_sum;
                    endcase
                end
            end
            FC1:begin
                if(timer == 18) begin
                    case(conv_cnt)
                        0:sram_act_wdata0[7:0]   <= clamped_relued_fc_sum;
                        1:sram_act_wdata0[15:8]  <= clamped_relued_fc_sum;
                        2:sram_act_wdata0[23:16] <= clamped_relued_fc_sum;
                        3:sram_act_wdata0[31:24] <= clamped_relued_fc_sum;
                        4:sram_act_wdata1[7:0]   <= clamped_relued_fc_sum;
                        5:sram_act_wdata1[15:8]  <= clamped_relued_fc_sum;
                        6:sram_act_wdata1[23:16] <= clamped_relued_fc_sum;
                        7:sram_act_wdata1[31:24] <= clamped_relued_fc_sum;
                    endcase
                end
            end
            FC2:begin
                if(timer == 14) begin
                    sram_act_wdata0  <= fc_sum + bias_buf;
                end
            end
        endcase
    end

    // timer
    always@(posedge clk)begin
        if(!rst_n) timer <= 0;
        else begin
            case(cur_state)
                CONV1:begin
                    if(timer == 9) timer <= 0;
                    else timer <= timer + 1;
                end
                CONV2:begin
                    if(conv2_once || conv2_change_page) timer <= 0;
                    else timer <= timer + 1;
                end
                CONV3:begin
                    if(timer == 53) timer <= 0;
                    else timer <= timer + 1;
                end
                FC1:begin
                    if(timer == 18) timer <= 0;
                    else timer <= timer + 1;
                end
                FC2:begin
                    if(timer == 14) timer <= 0;
                    else timer <= timer + 1;
                end
                OUTPUT:timer <= 0;
            endcase
        end
    end

    // mac module
    generate
        genvar gen_mac_i;
        for(gen_mac_i=0; gen_mac_i<40; gen_mac_i=gen_mac_i+1)begin:gen_macs
            MAC mac(mac_A[gen_mac_i],mac_B[gen_mac_i],mac_C[gen_mac_i],mac_O[gen_mac_i]);
        end
    endgenerate

    
    assign mac_A[0] = weight_buf_wire_1[0];
    assign mac_B[0] = act_buf_wire_1[0]   ;
    assign mac_A[1] = weight_buf_wire_1[1];
    assign mac_B[1] = act_buf_wire_1[1]   ;
    assign mac_A[2] = weight_buf_wire_1[2];
    assign mac_B[2] = act_buf_wire_1[2]   ;
    assign mac_A[3] = weight_buf_wire_1[3];
    assign mac_B[3] = act_buf_wire_1[3]   ;
    assign mac_A[4] = weight_buf_wire_1[4];
    assign mac_B[4] = act_buf_wire_1[4]   ;
    assign mac_A[5] = (cur_state < 5) ? weight_buf_wire_1[0] : weight_buf_wire_1[5] ;
    assign mac_B[5] = (cur_state < 5) ? act_buf_wire_1[1]    : act_buf_wire_1[5]    ;
    assign mac_A[6] = (cur_state < 5) ? weight_buf_wire_1[1] : weight_buf_wire_1[6] ;
    assign mac_B[6] = (cur_state < 5) ? act_buf_wire_1[2]    : act_buf_wire_1[6]    ;
    assign mac_A[7] = (cur_state < 5) ? weight_buf_wire_1[2] : weight_buf_wire_1[7] ;
    assign mac_B[7] = (cur_state < 5) ? act_buf_wire_1[3]    : act_buf_wire_1[7]    ;
    assign mac_A[8] = weight_buf_wire_1[3];
    assign mac_B[8] = act_buf_wire_1[4]   ;
    assign mac_A[9] = weight_buf_wire_1[4];
    assign mac_B[9] = act_buf_wire_1[5]   ;
    // connect weight & act buffer to mac input ports
    generate
        genvar j;
        // assign mac_A,B
        for(i=2;i<4;i=i+1)begin:gen_mac_AB_wire_2
            for(j=0;j<5;j=j+1)begin:gen_mac_AB_wire_1
                assign mac_A[i*5+j] = weight_buf_wire_1[j];
                assign mac_B[i*5+j] = act_buf_wire_1[i+j];
            end
        end
        for(i=0;i<4;i=i+1)begin:gen_mac_AB_wire_4
            for(j=0;j<5;j=j+1)begin:gen_mac_AB_wire_3
                assign mac_A[i*5+j+20] = weight_buf_wire_2[j];
                assign mac_B[i*5+j+20] = act_buf_wire_2[i+j];
            end
        end
    endgenerate
    
    // connect the Psum register to mac input
    generate
        for(i=0;i<40;i=i+1)begin:gen_mac_C
            assign mac_C[i] = mac_reg[i];
        end
    endgenerate

    // 
    generate
        for(i=0;i<4;i=i+1)begin:gen_mac_reg_1
            always@(posedge clk)begin
                if(!rst_n) mac_reg[i] <= 0;
                else begin
                    case(cur_state)
                        CONV1:begin
                            case(timer)
                                0:mac_reg[i] <= 0;
                                2,3,4,5,6:mac_reg[i] <= mac_O[i];
                            endcase
                        end
                        CONV2:begin
                            case(timer)
                                0:if(conv_page == 0) mac_reg[i] <= 0;
                                2,3,4,5,6:mac_reg[i] <= mac_O[i];
                            endcase
                        end
                        CONV3:begin
                            if((timer > 1) && (timer < 52)) mac_reg[i] <= mac_O[i];
                            else if(timer == 0) mac_reg[i] <= 0;
                        end
                        FC1:begin
                            if((timer > 1) && (timer < 17)) mac_reg[i] <= mac_O[i];
                            else if(timer == 0) mac_reg[i] <= 0;
                        end
                        FC2:begin
                            if((timer > 1) && (timer < 13))mac_reg[i] <= mac_O[i];
                            else if(timer == 0) mac_reg[i] <= 0;
                        end
                        OUTPUT:mac_reg[i] <= 0;
                    endcase
                end
            end
        end
        for(i=4;i<8;i=i+1)begin:gen_mac_reg_2
            always@(posedge clk)begin
                if(!rst_n) mac_reg[i] <= 0;
                else begin
                    case(cur_state)
                        CONV1:begin
                            case(timer)
                                0:mac_reg[i] <= 0;
                                2,3,4,5,6:mac_reg[i] <= mac_O[i];
                            endcase
                        end
                        CONV2:begin
                            case(timer)
                                0:if(conv_page == 0) mac_reg[i] <= 0;
                                2,3,4,5,6:mac_reg[i] <= mac_O[i];
                            endcase
                        end
                        CONV3:begin
                            if((timer > 1) && (timer < 52)) mac_reg[i] <= mac_O[i];
                            else if(timer == 0) mac_reg[i] <= 0;
                        end
                        FC1:begin
                            if((timer > 1) && (timer < 17)) mac_reg[i] <= mac_O[i];
                            else if(timer == 0) mac_reg[i] <= 0;
                        end
                        FC2:begin
                            if((timer > 1) && (timer < 12))mac_reg[i] <= mac_O[i];
                            else if(timer == 0) mac_reg[i] <= 0;
                        end
                        OUTPUT:mac_reg[i] <= 0;
                    endcase
                end
            end
        end
        for(i=8;i<20;i=i+1)begin:gen_mac_reg_3
            always@(posedge clk)begin
                if(!rst_n) mac_reg[i] <= 0;
                else begin
                    case(cur_state)
                        CONV1:begin
                            case(timer)
                                0:mac_reg[i] <= 0;
                                2,3,4,5,6:mac_reg[i] <= mac_O[i];
                            endcase
                        end
                        CONV2:begin
                            case(timer)
                                0:if(conv_page == 0) mac_reg[i] <= 0;
                                2,3,4,5,6:mac_reg[i] <= mac_O[i];
                            endcase
                        end
                        OUTPUT:mac_reg[i] <= 0;
                    endcase
                end
            end
        end
        for(i=20;i<40;i=i+1)begin:gen_mac_reg_4
            always@(posedge clk)begin
                if(!rst_n) mac_reg[i] <= 0;
                else begin
                    case(cur_state)
                        CONV1:begin
                            case(timer)
                                0:mac_reg[i] <= 0;
                                3,4,5,6,7:mac_reg[i] <= mac_O[i];
                            endcase
                        end
                        CONV2:begin
                            case(timer)
                                0:if(conv_page == 0) mac_reg[i] <= 0;
                                3,4,5,6,7:mac_reg[i] <= mac_O[i];
                            endcase
                        end
                        OUTPUT:mac_reg[i] <= 0;
                    endcase
                end
            end
        end
    endgenerate

    
    generate
        for (i=0;i<8;i=i+1)begin:gen_conv_sum
            assign conv_sum[i] = ((mac_reg[i*5] + mac_reg[i*5+1]) + mac_reg[i*5+2]) + (mac_reg[i*5+3] + mac_reg[i*5+4]);
        end
    endgenerate

    assign fc_sum = ((mac_reg[0]+mac_reg[1]) + (mac_reg[2]+mac_reg[3])) + ((mac_reg[4]+mac_reg[5]) + (mac_reg[6]+mac_reg[7]));

    generate
        for (i=0;i<2;i=i+1)begin:gen_pool
            POOL pool(conv_sum[i*2],conv_sum[i*2+1],conv_sum[i*2+4],conv_sum[i*2+5],pool_out[i]);
        end
    endgenerate

    //generate
    //    for (i=0;i<2;i=i+1)begin:gen_pool_out
    //        assign quantized_pool_out[i] = pool_out[i]*scale_factor;
    //        assign shifted_pool_out[i] = quantized_pool_out[i][31:16];
    //        assign clamped_pool_out[i] = (shifted_pool_out[i]>127) ? 127 : shifted_pool_out[i][7:0];
    //    end
    //endgenerate
    //
    reg signed [17:0] ma;
    wire signed [31:0] mb;
    wire signed [31:0] mo;
    MUL32 mul32 (ma, mb, mo);
    
    always@(*)begin
        case(cur_state)
            CONV1, CONV2: ma = pool_out[0];
            CONV3, FC1: ma = relued_fc_sum;
            FC2: ma = fc_sum;
            default: ma = 0;
        endcase
    end
    assign mb = scale_factor;
    
    
    //assign quantized_pool_out[0] = pool_out[0]*scale_factor;
    assign quantized_pool_out[0] = mo;
    assign shifted_pool_out[0] = quantized_pool_out[0][31:16];
    assign clamped_pool_out[0] = (shifted_pool_out[0]>127) ? 127 : shifted_pool_out[0][7:0];
    assign quantized_pool_out[1] = pool_out[1]*scale_factor;
    assign shifted_pool_out[1] = quantized_pool_out[1][31:16];
    assign clamped_pool_out[1] = (shifted_pool_out[1]>127) ? 127 : shifted_pool_out[1][7:0];

    assign relued_fc_sum = (fc_sum < 0) ? 0 : fc_sum;
    assign quantized_relued_fc_sum = mo;
    assign shifted_reluwd_fc_sum = {{16{quantized_relued_fc_sum[31]}},quantized_relued_fc_sum[31:16]};
    assign clamped_relued_fc_sum = (shifted_reluwd_fc_sum>127) ? 127 : shifted_reluwd_fc_sum;

    assign quantized_fc_sum = mo;
    assign shifted_fc_sum = {{16{quantized_fc_sum[31]}},quantized_fc_sum[31:16]};


    //==================================================
    //                    Functions
    //==================================================
    



endmodule


//=====================================================
//                   SUB-MODULEs
//=====================================================
module MAC(
    input wire  signed [7:0]  Ain,
    input wire  signed [7:0]  Bin,
    input wire  signed [17:0] Cin,
    output wire signed [17:0] Out);

    wire signed[15:0] Prod;
    
    assign Prod = Ain*Bin;
    assign Out = Prod+Cin;
endmodule
module MUL32(
    input wire  signed [17:0]  Ain,
    input wire  signed [31:0]  Bin,
    output wire signed [31:0] Out);
    assign Out = Ain * Bin;
endmodule

module POOL(
    input wire  signed [17:0] Ain,
    input wire  signed [17:0] Bin,
    input wire  signed [17:0] Cin,
    input wire  signed [17:0] Din,
    output wire signed [17:0] Out);

    wire signed [17:0] max1,max2,max3;

    assign max1 = (Ain>Bin) ? Ain : Bin;
    assign max2 = (Cin>Din) ? Cin : Din;
    assign max3 = (max1>max2) ? max1 : max2;
    assign Out  = (max3>0) ? max3 : 0;
endmodule
