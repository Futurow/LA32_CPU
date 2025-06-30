module ICache(
    input  wire        clk,
    input  wire        rst,
    input  wire [ 31:0]fetch_start_addr_in,
    input  wire [  3:0]fetch_pos_valid_in,
    output wire [127:0]inst_group,
    output wire [  3:0]inst_group_valid,
    //指令存储器访问信号
    output wire [31:0] inst_sram_addr,
    input  wire [31:0] inst_sram_rdata,
    //握手信号
    input  wire        pre_valid,
    input  wire        next_ready,
    output wire        out_valid,
    output wire        out_ready
);
    //握手信号
    reg     valid;
    wire    ready_go;//实现定义未完成
    assign  out_ready= !valid||(ready_go&&next_ready);
    assign  out_valid= valid&&ready_go;
    always @(posedge clk ) begin
        if(rst)begin
            valid <=1'b0;
        end else if (out_ready) begin
            valid <= pre_valid;
        end
    end
    reg [31:0] fetch_start_addr;
    reg [3:0]  fetch_pos_valid;
    always @(posedge clk ) begin
        if (out_ready&&pre_valid) begin
            fetch_start_addr <= fetch_start_addr_in;
            fetch_pos_valid  <= fetch_pos_valid_in;
        end
    end

    //缓存参数定义
    parameter TAG_WIDTH   = 10;
    parameter BLOCK_SIZE  = 128;     // 16B = 128bit
    parameter NUM_WAYS    = 4;
    parameter NUM_SETS    = 256;
    // 地址解析
    wire [7:0]  index = fetch_start_addr[11: 4];               // 每路256行
    wire [9:0]  tag   = fetch_start_addr[21:12];               // 10-bit tag
    // Cache 存储结构
    reg [TAG_WIDTH-1 :0] tag_array   [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg [BLOCK_SIZE-1:0] data_array  [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg                  valid_array [0:NUM_SETS-1][0:NUM_WAYS-1];
    // 替换计数器（用于伪随机替换）
    reg [1:0] replce_counter;
    always @(posedge clk ) begin
        if (rst) begin
            replce_counter <= 2'b00;
        end else begin
            replce_counter <= replce_counter + 1;
        end
    end
    // 初始化
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                valid_array[i][0] <= 1'b0;
                valid_array[i][1] <= 1'b0;
                valid_array[i][2] <= 1'b0;
                valid_array[i][3] <= 1'b0;
            end
        end
    end
    reg     [3:0]   hit_bits;
    wire            is_hit;
    //命中判断
    assign is_hit = hit_bits[0]|hit_bits[1]|hit_bits[2]|hit_bits[3];
    always @(*) begin
        hit_bits[0] = valid_array[index][0]&&(tag_array[index][0]==tag);
        hit_bits[1] = valid_array[index][1]&&(tag_array[index][1]==tag);
        hit_bits[2] = valid_array[index][2]&&(tag_array[index][2]==tag);
        hit_bits[3] = valid_array[index][3]&&(tag_array[index][3]==tag);
    end

    //从存储区读取一个cacheline
    reg     [1:0]   inst_counter;
    reg     [31:0]  inst_block_0,inst_block_1,inst_block_2,inst_block_3;   
    always @(posedge clk) begin
        if (rst) begin
            inst_counter <= 2'b00;
        end else if (out_ready)begin
            inst_counter <= 2'b00;
        end else begin
            inst_counter <= inst_counter + 1;
        end
    end
    assign inst_sram_addr = {fetch_start_addr[31:2],inst_counter};
    always @(posedge clk ) begin
        if (inst_counter==2'b00) begin
            inst_block_0<=inst_sram_rdata;
        end
        if (inst_counter==2'b01) begin
            inst_block_1<=inst_sram_rdata;
        end
        if (inst_counter==2'b10) begin
            inst_block_2<=inst_sram_rdata;
        end
        //第四条指令读出后直接使用
        inst_block_3 = inst_sram_rdata;
    end
    //替换路选择
    reg [1:0]   replace_way;
    always @(*) begin
        //先替换空位置
        if (!valid_array[index][0]) begin
            replace_way = 2'b00;
        end else if (!valid_array[index][1]) begin
            replace_way = 2'b01;
        end else if (!valid_array[index][2]) begin
            replace_way = 2'b10;
        end else if (!valid_array[index][3]) begin
            replace_way = 2'b11;
        end else  begin//后替换有效块
            replace_way = replce_counter;
        end
    end
    //替换
    wire [127:0] fetch_inst_group = {inst_block_0,inst_block_1,inst_block_2,inst_block_3};
    always @(posedge clk ) begin
        if (!is_hit&&inst_counter==2'b11) begin
            valid_array[index][replace_way]<=1'b1;
            tag_array  [index][replace_way]<=tag;
            data_array [index][replace_way]<=fetch_inst_group;
        end
    end
    //发送指令
    reg [127:0] from_data_array;
    always @(*) begin
        if (hit_bits[0]) begin
            from_data_array = data_array [index][0];
        end else if (hit_bits[1]) begin
            from_data_array = data_array [index][1];
        end else if (hit_bits[2]) begin
            from_data_array = data_array [index][2];
        end else begin
            from_data_array = data_array [index][3];
        end 
    end
    assign inst_group = is_hit?from_data_array:fetch_inst_group;
    assign inst_group_valid = {fetch_pos_valid[0],
                               fetch_pos_valid[1],
                               fetch_pos_valid[2],
                               fetch_pos_valid[3]};
    assign ready_go = is_hit|((!is_hit)&&(inst_counter==2'b11));
endmodule