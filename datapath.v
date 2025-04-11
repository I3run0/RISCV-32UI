module datapath (
    input clk,
    input rst,

    // input signals
    input pc_write,
    input adr_src,
    input ir_write,
    input [1:0] result_src,
    input [3:0] alu_control,
    input [1:0] alu_src_a, alu_src_b,
    input [2:0] imm_src,
    input reg_write,  

    // Memory ports
    output [31:0] mem_addr,
    output [31:0] mem_write_data,
    input [31:0] mem_read_data,

    // Control ports
    output [31:0] instr,
    output zero
);

    // Internal registers
    wire [31:0] result;
    wire [31:0] pc;
    wire [31:0] old_pc, instruc_reg, data_to_save;

    // Internal wires
    wire [31:0] alu_result, alu_out;
    wire [31:0] imm_extended;
    wire [31:0] read_data1, read_data2;
    wire [31:0] fread_data1, fread_data2;
    wire [31:0] alu_src_inst_a, alu_src_inst_b; 
    wire [4:0] rs1, rs2, rd;

    // Program counter
    flip_flop_enable pc_next_logic (
        .clk(clk),
        .rst(rst),
        .enable(pc_write),
        .src(result),
        .dest(pc)
    );

    // Memory address mux
    mux2 memory_multiplexr (
        .select(adr_src),
        .src0(pc),
        .src1(result),
        .dest(mem_addr)
    );

    // Fetch stage: old_pc and instruc_reg
    flip_flop_enable fetch_pc_ff (
        .clk(clk),
        .rst(rst),
        .enable(ir_write),
        .src(pc),
        .dest(old_pc)
    );

    flip_flop_enable fetch_ir_ff (
        .clk(clk),
        .rst(rst),
        .enable(ir_write),
        .src(mem_read_data),
        .dest(instruc_reg)
    );

    assign instr = instruc_reg;

    assign rs1 = instruc_reg[19:15];
    assign rs2 = instruc_reg[24:20];
    assign rd  = instruc_reg[11:7];

    // Register file
    register_file register_file_unit (
        .clk(clk),
        .rst(rst),
        .write_enable_3(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .write_data_3(result),
        .rd(rd),
        .rd1(read_data1),
        .rd2(read_data2)
    );

    // Immediate generator
    imm_extend imm_extend_unit (
        .instruction(instruc_reg),
        .imm_selection(imm_src),
        .imm_extended(imm_extended)
    );

    // Latch register file outputs
    flip_flop_enable regfile_rd1_ff (
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .src(read_data1),
        .dest(fread_data1)
    );

    flip_flop_enable regfile_rd2_ff (
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .src(read_data2),
        .dest(fread_data2)
    );

    assign mem_write_data = fread_data2;

    // ALU source muxes
    mux3 mux3_alu_src_a (
        .select(alu_src_a),
        .src0(pc),
        .src1(old_pc),
        .src2(fread_data1),
        .dest(alu_src_inst_a)
    );

    mux3 mux3_alu_src_b (
        .select(alu_src_b),
        .src0(fread_data2),
        .src1(imm_extended),
        .src2(32'd4),
        .dest(alu_src_inst_b)
    );

    // ALU unit
    alu alu_unit (
        .a(alu_src_inst_a),
        .b(alu_src_inst_b),
        .alu_control(alu_control),
        .result(alu_result),
        .zero(zero)
    );

    // Latch ALU and memory read results
    flip_flop_enable alu_output_ff (
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .src(alu_result),
        .dest(alu_out)
    );

    flip_flop_enable mem_save_ff (
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .src(mem_read_data),
        .dest(data_to_save)
    );

    // Result mux
    mux3 las_mux3 (
        .select(result_src),
        .src0(alu_out),
        .src1(data_to_save),
        .src2(alu_result),
        .dest(result)
    );

endmodule
