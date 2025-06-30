module PredictUnit (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] fetch_start_addr,//取指起始地址
    output wire [3:0]  fetch_pos_valid,//指令块内指令有效标志
    //握手信号
    input  wire        next_ready,
    output wire        out_valid
);
    //握手信号
    reg     valid;
    wire    ready_go = 1'b1;
    wire    out_ready= !valid||(ready_go&&next_ready);
    assign  out_valid= valid&&ready_go;
    always @(posedge clk ) begin
        if (rst) begin
            valid <= 1'b0;
        end else begin
            valid <= 1'b1;
        end
    end

    //跳转类型定义
    parameter B         = 2'b01;
    parameter CALL      = 2'b11;
    parameter RET       = 2'b10;
    parameter OTHER     = 2'b00;
    //pc初始化和更新
    reg     [31:0]  pc;
    wire    [31:0]  nextpc;
    always @(posedge clk ) begin
        if (rst) begin
            pc <= 32'h1C000000;
        end else if(out_ready&&valid)begin
            pc <= nextpc;
        end
    end
    //pc生成
    wire    [31:0]  pc0    =   pc;
    wire    [31:0]  pc4    =   pc + 32'd4;
    wire    [31:0]  pc8    =   pc + 32'd8;
    wire    [31:0]  pc12   =   pc + 32'd12;
    wire    [31:0]  pc16   =   pc + 32'd16;

    wire    [3:0]   takens;
    wire    [3:0]   hits;
    wire    [127:0] TargetAddrs;
    wire    [7:0]   br_types;
    DirectPredict direct_predict(clk,
                                 rst,
                                 pc0,
                                 pc4,
                                 pc8,
                                 pc12,
                                 takens);
    TargetPredict target_predict(clk,
                                 rst,
                                 pc0,
                                 pc4,
                                 pc8,
                                 pc12,
                                 hits,
                                 TargetAddrs,
                                 br_types);
    //BTB未命中时默认执行下一条
    reg    [127:0]  miss_replace;
    always @(*) begin
        miss_replace[ 31: 0] = hits[0]?TargetAddrs[ 31: 0]:pc4 ;
        miss_replace[ 63:32] = hits[1]?TargetAddrs[ 63:32]:pc8 ;
        miss_replace[ 95:64] = hits[2]?TargetAddrs[ 95:64]:pc12;
        miss_replace[127:96] = hits[3]?TargetAddrs[127:96]:pc16;
    end
    //记录可选取位置
    reg     [3:0]   align_valid;
    always @(*) begin
        case (pc[3:2])
            2'b00:align_valid=4'b1111;
            2'b01:align_valid=4'b1110;
            2'b10:align_valid=4'b1100;
            2'b11:align_valid=4'b1000;
            default:; 
        endcase
    end
    //记录跳转位置以及该位置前的指令
    reg     [3:0]  branch_len_valid;
    always @(*) begin
        if (takens[0]) begin
            branch_len_valid = 4'b0001;
        end else if (takens[1]) begin
            branch_len_valid = 4'b0011;
        end else if (takens[2]) begin
            branch_len_valid = 4'b0111;
        end else if (takens[3]) begin
            branch_len_valid = 4'b1111;
        end else begin
            branch_len_valid = 4'b1111;
        end
    end
    //选择第一条要跳转的指令pc
    //记录第一条要跳转的指令pc的类型
    reg  [31:0] taken_pc;
    reg  [1:0]  br_type;
    wire [7:0]  group_valid =  align_valid&(branch_len_valid<<pc[3:2]);
    assign      fetch_pos_valid = group_valid[3:0];
    wire [3:0]  branch_valid = group_valid>>pc[3:2];
    always @(*) begin
        if (branch_valid[3]) begin
            taken_pc = miss_replace[127:96];
            br_type = br_types[7:6];
        end else if (branch_valid[2]) begin
            taken_pc = miss_replace[95:64];
            br_type = br_types[5:4];
        end else if (branch_valid[1]) begin
            taken_pc = miss_replace[63:32];
            br_type = br_types[3:2];
        end else if (branch_valid[0]) begin
            taken_pc = miss_replace[31: 0];
            br_type = br_types[1:0];
        end else begin
            taken_pc = 32'hffff_ffff;
            br_type = OTHER;
        end
    end
    //地址返回栈
    wire     [31:0]  ras_push_pc = taken_pc + 4;
    wire     [31:0]  ras_pop_pc;
    wire             push,pop;
    assign      push = (br_type==CALL);
    assign      pop  = (br_type==RET);
    RAS ras(clk,rst,push,pop,ras_push_pc,ras_pop_pc);
    assign nextpc = ((takens!=4'b0)&(br_type==RET))?ras_pop_pc:taken_pc;
    assign fetch_start_addr = pc;
    
endmodule
module DirectPredict#(
    parameter BHT_NUM   = 1024,
    parameter BHT_WIDTH = 5,
    parameter PHT_NUM = 1 << BHT_WIDTH
    )(
    input  wire             clk,
    input  wire             rst,
    input  wire     [31:0]  pc0,
    input  wire     [31:0]  pc4,
    input  wire     [31:0]  pc8,
    input  wire     [31:0]  pc12,
    output  wire    [3:0]   takens
    );
    //状态定义
    parameter STRONG_NT  = 2'b01;
    parameter WEAKLY_NT  = 2'b00;
    parameter WEAKLY_T   = 2'b10;
    parameter STRONG_T   = 2'b11;
    //初始化
    reg [1:0]           phts [0:PHT_NUM-1];
    reg [BHT_WIDTH-1:0] bhts [0:BHT_NUM-1];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < PHT_NUM; i = i + 1) begin
                phts[i] <= WEAKLY_NT;
            end
            for (i = 0; i < BHT_NUM; i = i + 1) begin
                bhts[i] <= 0;
            end
        end
    end
    //访问bhts和phts
    reg    [BHT_WIDTH-1:0] bht0,bht4,bht8,bht12;
    always @(*) begin
        bht0  = bhts[ pc0[21:12]^ pc0[11:2]];
        bht4  = bhts[ pc4[21:12]^ pc4[11:2]];
        bht8  = bhts[ pc8[21:12]^ pc8[11:2]];
        bht12 = bhts[pc12[21:12]^pc12[11:2]];
    end
    reg    [1:0]   pht0,pht4,pht8,pht12;
    always @(*) begin
        pht0  = phts[bht0 ];
        pht4  = phts[bht4 ];
        pht8  = phts[bht8 ];
        pht12 = phts[bht12];
    end
    taken_judge  u0(pht0 ,takens[0]);
    taken_judge  u4(pht4 ,takens[1]);
    taken_judge  u8(pht8 ,takens[2]);
    taken_judge u12(pht12,takens[3]);
endmodule
module taken_judge (
    input  wire [1:0] state,
    output reg        taken
    );
    //状态定义
    parameter STRONG_NT  = 2'b01;
    parameter WEAKLY_NT  = 2'b00;
    parameter WEAKLY_T   = 2'b10;
    parameter STRONG_T   = 2'b11;
    always @(*) begin
        case (state)
            STRONG_NT:taken = 1'b0;
            WEAKLY_NT:taken = 1'b0;
            WEAKLY_T :taken = 1'b1;
            STRONG_T :taken = 1'b1;
            default  :taken = 1'b0;
        endcase
    end    
endmodule
module TargetPredict (
    input  wire             clk,
    input  wire             rst,
    input  wire     [31:0]  pc0,
    input  wire     [31:0]  pc4,
    input  wire     [31:0]  pc8,
    input  wire     [31:0]  pc12,
    output reg      [3:0]   hits,
    output reg      [127:0] TargetAddrs,
    output reg      [7:0]   br_types 
    );
    //4MB 10bitTAG,1024项
    reg         valid       [0:1023];
    reg [9:0]   tags        [0:1023];
    reg [31:0]  branchAddr  [0:1023];
    reg [1:0]   br_type_list[0:1023];
    integer i;
    always @(posedge clk ) begin
        if (rst) begin
            for (i = 0; i<1024; i=i+1) begin
                valid[i] <= 1'b0;
            end
        end
    end
    wire    [9:0] idx0  =  pc0[11:2];
    wire    [9:0] idx4  =  pc4[11:2];
    wire    [9:0] idx8  =  pc8[11:2];
    wire    [9:0] idx12 = pc12[11:2];
    wire    [9:0] tag0  =  pc0[21:12];
    wire    [9:0] tag4  =  pc4[21:12];
    wire    [9:0] tag8  =  pc8[21:12];
    wire    [9:0] tag12 = pc12[21:12];
    //命中判断
    always @(*) begin
        hits[0] = valid[idx0 ]&&(tags[idx0 ]==tag0 );
        hits[1] = valid[idx4 ]&&(tags[idx4 ]==tag4 );
        hits[2] = valid[idx8 ]&&(tags[idx8 ]==tag8 );
        hits[3] = valid[idx12]&&(tags[idx12]==tag12);
    end
    //结果输出
    always @(*) begin
        TargetAddrs[ 31: 0] = branchAddr[idx0 ];
        TargetAddrs[ 63:32] = branchAddr[idx4 ];
        TargetAddrs[ 95:64] = branchAddr[idx8 ];
        TargetAddrs[127:96] = branchAddr[idx12];
        br_types[1:0] = br_type_list[idx0 ];
        br_types[3:2] = br_type_list[idx4 ];
        br_types[5:4] = br_type_list[idx8 ];
        br_types[7:6] = br_type_list[idx12];
    end
endmodule
module RAS #(
    parameter DEPTH = 16
    )(
    input  wire             clk,
    input  wire             rst,
    input  wire             push,
    input  wire             pop,
    input  wire     [31:0]  ras_push_pc,
    output wire     [31:0]  ras_pop_pc
    );
    reg [31:0] stack [0:DEPTH-1];
    reg  [$clog2(DEPTH):0] sp;  // 栈指针
    wire    full;
    wire    empty;
    wire    we_stack;
    wire    add_sp,sub_sp;
    
    assign full     = (sp==DEPTH);
    assign empty    = (sp==0);
    assign we_stack = push&&!full;
    assign add_sp   = push&&!full;
    assign sub_sp   = pop&&!empty;
    always @(posedge clk ) begin
        if (we_stack) stack[sp] <= ras_push_pc;
    end

    always @(posedge clk ) begin
        if (rst) begin
            sp <= 0;
        end else if (add_sp) begin
            sp <= sp + 1;
        end else if (sub_sp) begin
            sp <= sp - 1;
        end
    end
    assign ras_pop_pc = (pop && !empty)?stack[sp-1]:32'b0;
endmodule