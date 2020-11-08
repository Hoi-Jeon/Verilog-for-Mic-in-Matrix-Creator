module mic_fir #(
	parameter DATA_WIDTH     			= "mandatory",				// 16
	parameter CHANNELS       			= "mandatory",				// 8
	parameter CHANNELS_WIDTH 			= "mandatory",				// 3
	parameter FIR_TAP_WIDTH  			= "mandatory",				// 16
	parameter FIR_TAP        			= "mandatory",				// 128
	parameter FIR_TAP_ADDR   			= "mandatory",				// 7
	parameter FIR_MEM_DATA_ADDR 		= $clog2(FIR_TAP*CHANNELS)	// 10
) (
	input								clk,
	input								resetn,
	input								data_load,
	input [CHANNELS_WIDTH-1:0]			channel,
	input  signed [DATA_WIDTH-1:0]		data_in,					// 16
	output signed [DATA_WIDTH-1:0]		data_out,					// 16
	output								write_data_mem,
	// FIR Coeff
	output [FIR_TAP_ADDR-1:0] 			coeff_addr,					// 7
	input signed [FIR_TAP_WIDTH-1:0]	coeff_data					// 16
);

// "wr_data_addr" is [0,1023], i.e. 1024 data point = 128 FIR lines x 8 microphones
reg [FIR_MEM_DATA_ADDR-1:0] wr_data_addr;

// "wr_data_addr" increases, as "write_memory" is from the output of CIC filter
// "wr_data_addr" =  (7 bits for 128 FIR filter elements) + (3 bits for channels)
always @(posedge clk or posedge resetn) begin
	if (resetn)
		wr_data_addr <= 0;
	else begin
	if (data_load)
		wr_data_addr <= wr_data_addr + 1;
	end
end

// "wr_addr_deinterlaced" has [9:0], i.e. 2**10 = 1024 data point
wire [FIR_MEM_DATA_ADDR-1:0] wr_addr_deinterlaced;

// "wr_addr_deinterlaced" {[2:0], [9:3]}, since "CHANNELS_WIDTH" is 3
// "wr_addr_deinterlaced" =  (3 bits for channels) + (7 bits for 128 FIR filter elements) 
assign wr_addr_deinterlaced = { wr_data_addr[CHANNELS_WIDTH-1:0], wr_data_addr[FIR_MEM_DATA_ADDR-1:CHANNELS_WIDTH]};

// "data_memory_addr" has [9:0], i.e. 2**10 = 1024 wires
wire [FIR_MEM_DATA_ADDR-1:0] data_memory_addr;

// "pipe_channel" has [2:0], i.e. 2**3 = 8 wires
wire [CHANNELS_WIDTH-1:0] pipe_channel;	// 3
wire load_data_memory;

wire reset_tap;
reg reset_tap_p1, reset_tap_p2;

wire write_data;
reg write_data_p1, write_data_p2;

wire end_write_data;
assign end_write_data 	//  "end_write_data" becomes true, only with the last channel & true "data_load"
		= (&channel) 		// (reduction) input: channel = [2:0],
			& data_load; 	// (& operator) input: data_load

// Instantiate the Unit, fir_pipe_fsm
fir_pipe_fsm #(
	.CHANNELS 			(CHANNELS),			// 8
	.FIR_TAP			(FIR_TAP),			// 128
	.CHANNELS_WIDTH		(CHANNELS_WIDTH)	// 3
) fir_pipe0 (
	.clk				(clk),				// input
	.resetn				(resetn),			// input
	.end_write_data		(end_write_data),	// input

	.tap_count			(coeff_addr),		// output reg, count max. up to 128 [0, 127]
	.channel_count   	(pipe_channel),		// output reg, count max. up to 8 [0, 7]
	.load_data_memory	(load_data_memory),	// output reg, "true" during "tap_count" increases
	.reset_tap       	(reset_tap),		// output reg, "true" "tap_count" starts
	.write_data      	(write_data)		// output, "true" "channel_count" increases
);

// Pipe Line Register
// "data_reg_a" is [16-1:0]
wire signed [FIR_TAP_WIDTH-1:0] data_reg_a;
// "data_reg_b" is [16-1:0]
wire signed [DATA_WIDTH-1:0] data_reg_b;
// wire "coeff_data [16-1:0]" and "data_reg_a"
assign data_reg_a = coeff_data;

// "read_pointer"is [6:0] = [(10-3-1):0], here "3" is subtracted for channel and "1" is subtracted due to the zero index
wire [(FIR_MEM_DATA_ADDR-CHANNELS_WIDTH-1):0] read_pointer;

// "read_pointer_1st" & "read_pointer_2nd" are two variables for debugging
wire [6:0] read_pointer_1st;
assign read_pointer_1st = coeff_addr;

wire [6:0] read_pointer_2nd;
assign read_pointer_2nd = wr_data_addr[FIR_MEM_DATA_ADDR-1:CHANNELS_WIDTH];	
	
// "coeff_addr" and "wr_data_addr" should be added for "read_pointer" and it works like a "ring buffer"
// - coeff_addr [6:0] = tab_count
// - wr_data_addr[FIR_MEM_DATA_ADDR-1:CHANNELS_WIDTH] increases when new data are read
assign read_pointer = coeff_addr + wr_data_addr[FIR_MEM_DATA_ADDR-1:CHANNELS_WIDTH] - 1; // wr_data_addr [9:3] - 1 

// "pipe_channel" has [2:0], i.e. 2**3 = 8 wires
// "read_pointer" has [6:0], i.e. 2**7 = 128 wires
// "data_memory_addr" has [9:0], i.e. 2**10 = 1024 points = 128 * 8 points
assign data_memory_addr = {pipe_channel, read_pointer};

//Data Memory
mic_array_buffer #(
	.ADDR_WIDTH	(FIR_MEM_DATA_ADDR),	// 10
	.DATA_WIDTH	(DATA_WIDTH)		// 16
) mic_fir_data0 (
	// write port a
	.clk_a		(clk),
	.we_a 		(data_load),
	.adr_a		(wr_addr_deinterlaced),
	.dat_a		(data_in),

	// read port b
	.clk_b		(clk),
	.adr_b		(data_memory_addr),
	.en_b 		(load_data_memory), // output reg,	"true" during "tap_count" increases
	.dat_b		(data_reg_b)
);

// Pipe line stage 1
always @(posedge clk or posedge  resetn) begin
	if(resetn) begin
		reset_tap_p1  <= 0;
		write_data_p1 <= 0;
	end else begin
		reset_tap_p1  <= reset_tap;
		write_data_p1 <= write_data;
	end
end

// "factor_wire" is [16+16-1:0], because it should have max. 16 bit x 16 bit
wire signed [(FIR_TAP_WIDTH+DATA_WIDTH)-1:0] factor_wire;

// data_reg_a = coeff_data
// data_reg_b = output from "mic_fir_data0" with the index, "data_memory_addr" 
assign factor_wire = data_reg_a * data_reg_b;

// reg "data_reg_c" is [16-1:0]
reg signed [DATA_WIDTH-1:0] data_reg_c;

// Pipe line stage 2
always @(posedge clk or posedge  resetn) begin
	if(resetn) begin
		data_reg_c    <= 0;
		reset_tap_p2  <= 0;
		write_data_p2 <= 0;
	end else begin
		write_data_p2	<= write_data_p1;
		data_reg_c	<= { factor_wire[(FIR_TAP_WIDTH+DATA_WIDTH)-1], 										// [(16+16)-1]
						factor_wire[(FIR_TAP_WIDTH+DATA_WIDTH)-3:FIR_TAP_WIDTH-1] };		// [(16+16)-3 : 16-1]
						// Question: why factor_wire[30] should be removed?
						// Answer: 16 bit x 16 bit gives always "zero" at "MSB - 1" bit, so this bit is removed to improve the accuracy
		reset_tap_p2  <= reset_tap_p1;
	end
end

// reg "data_reg_d" is [16-1:0]
reg signed [DATA_WIDTH-1:0] data_reg_d;

// Pipe line stage 3
always @(posedge clk or posedge  resetn) begin
	if(resetn | reset_tap_p2) begin
		data_reg_d <= 0;
	end else begin
		// Question: Why "data_reg_d" and "data_reg_c" should be added?
		// Answer: this is the summation of FIR filter, i.e. convolution
		data_reg_d <= (data_reg_d + data_reg_c);
	end
end

assign data_out				= data_reg_d;
assign write_data_mem	= write_data_p2;

endmodule
