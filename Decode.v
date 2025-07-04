`include "defines.vh"
module Decode (
    input   wire            clk,
    input   wire            rst,
    input   wire    [127:0] inst_4W_in,
    input   wire    [3:0]   inst_4W_valid_in,
    input   wire    [27:0]  inst_4W_pc_in,
    //握手信号
    input  wire             pre_valid,
    input  wire             next_ready,
    output wire             out_valid,
    output wire             out_ready
);
    reg     valid;
    wire    ready_go = 1'b1;//根据实现定义未完成
    assign  out_ready= !valid||(ready_go&&next_ready);
    assign  out_valid= valid&&ready_go;

    always @(posedge clk ) begin
        if(rst)begin
            valid <=1'b0;
        end else if (out_ready) begin
            valid <= pre_valid;
        end
    end
    reg [127:0] inst_4W;
    reg [3:0]   inst_4W_valid;
    reg [27:0]  inst_4W_pc;
    always @(posedge clk ) begin
        if (out_ready&&pre_valid) begin
            inst_4W <= inst_4W_in;
            inst_4W_valid <= inst_4W_valid_in;
            inst_4W_pc <= inst_4W_pc_in;
        end
    end
    //拆分出四条指令和对应的有效信号
    wire    [31:0]  inst_0,inst_1,inst_2,inst_3;
    wire    [31:0]  pc0,pc1,pc2,pc3;
    wire            inst_valid_0,inst_valid_1,inst_valid_2,inst_valid_3;
    assign inst_0 = inst_4W[127:96];
    assign inst_1 = inst_4W[ 95:64];
    assign inst_2 = inst_4W[ 63:32];
    assign inst_3 = inst_4W[ 31:0 ];
    assign inst_valid_0 = inst_4W_valid[3];
    assign inst_valid_1 = inst_4W_valid[2];
    assign inst_valid_2 = inst_4W_valid[1];
    assign inst_valid_3 = inst_4W_valid[0];
    assign pc0 = {inst_4W_pc,2'b00,2'b00};
    assign pc1 = {inst_4W_pc,2'b01,2'b00};
    assign pc2 = {inst_4W_pc,2'b10,2'b00};
    assign pc3 = {inst_4W_pc,2'b11,2'b00};
    wire [84:0] decode0_res,decode1_res,decode2_res,decode3_res;
    SingleInstDecode decoder0(inst_0,pc0,decode0_res);
    SingleInstDecode decoder1(inst_1,pc1,decode1_res);
    SingleInstDecode decoder2(inst_2,pc2,decode2_res);
    SingleInstDecode decoder3(inst_3,pc3,decode3_res);
endmodule
module SingleInstDecode (
    input   wire [31:0]  inst,
    input   wire [31:0]  pc,
    output  reg  [84:0]  decode_res
);
    //字段解析
    wire    [ 5:0]  inst31_26 = inst[31:26];
    wire    [ 3:0]  inst25_22 = inst[25:22];
    wire    [ 6:0]  inst21_15 = inst[21:15];
    wire    [15:0]  offs15_0  = inst[25:10];
    wire    [ 9:0]  offs25_16 = inst[ 9: 0];
    wire    [19:0]  si20      = inst[24: 5];
    wire    [11:0]  si12      = inst[21:10];
    wire    [11:0]  ui12      = inst[21:10];
    wire    [ 4:0]  ui5       = inst[14:10];
    wire    [ 4:0]  rk        = inst[14:10];
    wire    [ 4:0]  rj        = inst[ 9: 5];
    wire    [ 4:0]  rd        = inst[ 4: 0];

    //控制信号
    reg     [1:0]   inst_type;//指令类型
    reg     [3:0]      alu_op;//计算操作
    reg    [31:0]      imm;//立即数
    reg                use_imm;//使用立即数
    reg                r_w_mem;//读(0)或写(1)内存
    reg     [4:0]      rs1;//源寄存器
    reg     [4:0]      rs2;//源寄存器
    reg     [4:0]      dest;//目的寄存器
    reg                rf_we;//写寄存器
    reg     [2:0]      branch_cond;//分支条件

    always @(*) begin
        case (inst_type)
            `INST_ALU   :begin
                decode_res = {inst_type,rs1,rs2,dest,rf_we,imm,use_imm,alu_op,30'b0};//55
            end
            `INST_MEM   :begin
                decode_res = {inst_type,rs1,rs2,dest,rf_we,imm,r_w_mem,34'b0};//51
            end
            `INST_BRANCH:begin
                decode_res = {inst_type,rs1,rs2,dest,rf_we,imm,branch_cond,pc};//85
            end
            default: begin
                decode_res = 0;
            end
        endcase
    end   

    always @(*) begin
        inst_type   = `INST_NOT;
        alu_op      = `ALU_OP_NULL;
        r_w_mem     = 1'b0;
        imm         = 32'b0;
        rf_we       = 1'b0;
        rs1         = rj;
        rs2         = rk;
        dest        = rd;
        branch_cond = `BRANCH_NULL;
        case (inst31_26)
            6'b00_0101: begin
                case(inst[25])
                    1'b0:begin
                        //LU12I.W
                        inst_type = `INST_ALU;
                        alu_op    = `ALU_OP_LU12I;
                        imm       = {si20,12'b0};
                        rf_we     = 1'b1;
                    end 
                default:;
                endcase
            end
            6'b00_0000:begin
                case (inst25_22)
                    4'b1010:begin
                        //ADDI.W
                        inst_type = `INST_ALU;
                        alu_op    = `ALU_OP_ADD;
                        imm       = {{20{si12[11]}},si12};
                        use_imm   = 1'b1;
                        rf_we     = 1'b1;
                    end
                    4'b0000:begin
                        case (inst21_15)
                            7'b010_0000:begin
                                //ADD.W
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_ADD;
                                rf_we     = 1'b1;
                            end 
                            7'b010_0010:begin
                                //SUB.W
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_SUB;
                                rf_we     = 1'b1;
                            end
                            7'b010_0100:begin
                                //SLT
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_SLT;
                                rf_we     = 1'b1;
                            end
                            7'b010_0101:begin
                                //SLTU
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_SLTU;
                                rf_we     = 1'b1;
                            end
                            7'b010_1000:begin
                                //NOR
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_NOR;
                                rf_we     = 1'b1;
                            end
                            7'b010_1001:begin
                                //AND
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_AND;
                                rf_we     = 1'b1;
                            end
                            7'b010_1010:begin
                                //OR
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_OR;
                                rf_we     = 1'b1;
                            end
                            7'b010_1011:begin
                                //XOR
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_XOR;
                                rf_we     = 1'b1;
                            end
                            default: ;
                        endcase
                    end 
                    4'b0001:begin
                        case (inst21_15)
                            7'b0000_001:begin
                                //SLLI.W
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_SLL;
                                imm       =  {27'b0,ui5};
                                use_imm   = 1'b1;
                                rf_we     = 1'b1;
                            end 
                            7'b0001_001:begin
                                //SRLI.W
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_SRL;
                                imm       =  {27'b0,ui5};
                                use_imm   = 1'b1;
                                rf_we     = 1'b1;
                            end
                            7'b0010_001:begin
                                //SRAI.W
                                inst_type = `INST_ALU;
                                alu_op    = `ALU_OP_SRA;
                                imm       =  {27'b0,ui5};
                                use_imm   = 1'b1;
                                rf_we     = 1'b1;
                            end
                            default: ;
                        endcase
                    end
                    default:; 
                endcase
            end
            6'b00_1010:begin
                case (inst25_22)
                    4'b0010:begin
                        //LD.W
                        inst_type = `INST_MEM;
                        r_w_mem   = 1'b0;
                        imm       = {{20{si12[11]}},si12};
                        rf_we     = 1'b1;
                    end 
                    4'b0110:begin
                        //ST.W
                        inst_type = `INST_MEM;
                        r_w_mem   = 1'b1;
                        imm       = {{20{si12[11]}},si12};
                        rs2       = rd;
                    end
                    default: ;
                endcase
            end
            6'b01_0110:begin
                //BEQ
                inst_type = `INST_BRANCH;
                imm       = {{14{offs15_0[15]}},offs15_0,2'b00};
                rs2       = rd;
                branch_cond = `BRANCH_EQ;
            end
            6'b01_0111:begin
                //BNE
                inst_type = `INST_BRANCH;
                imm       = {{14{offs15_0[15]}},offs15_0,2'b00};
                rs2       = rd;
                branch_cond = `BRANCH_NE;
            end
            6'b01_0101:begin
                //BL
                inst_type = `INST_BRANCH;
                imm       = {{6{offs25_16[9]}},offs25_16,offs15_0,2'b00};
                rf_we     = 1'b1;
                dest      = 5'b00001;
                branch_cond = `BRANCH_J;
            end
            6'b01_0011:begin
                //JIRL
                inst_type = `INST_BRANCH;
                imm       = {{14{offs15_0[15]}},offs15_0,2'b00};
                rf_we     = 1'b1;
                branch_cond = `BRANCH_J;
            end
            6'b01_0100:begin
                //B
                inst_type = `INST_BRANCH;
                imm       = {{6{offs25_16[9]}},offs25_16,offs15_0,2'b00};
                branch_cond = `BRANCH_J;
            end
            default: ;
        endcase
    end
endmodule