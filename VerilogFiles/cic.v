module cic #(
	parameter WIDTH="mandatory", 	// 23,
	parameter STAGES="mandatory", 	// 3,
	parameter CHANNELS="mandatory"	// 8
)(
	input							clk,
	input  							resetn,
	input  							[CHANNELS-1:0] pdm_data, /* MIC_Interface */
	input  							integrator_enable,
	input  							comb_enable,
	input  							pdm_read_enable,
	output [$clog2(CHANNELS)-1:0]	channel,
	output signed	[WIDTH-1:0]		data_out,
	output 							write_memory  
);

wire wr_en, read_en;
assign write_memory = wr_en & comb_enable; // where "comb_enable" is active for each "decimation ratio"

// OK, Validated @29.10.2020
cic_op_fsm #(
	.WIDTH   	(WIDTH),			// 23
	.CHANNELS	(CHANNELS)			// 8
) op_fsm0 (
	.clk    	(clk),				// input
	.resetn 	(resetn),			// input
	.enable 	(integrator_enable),// input
	.read_en	(read_en),			// output reg
	.wr_en  	(wr_en),			// output reg
	.channel	(channel)			// output reg [3-1:0]
);

// two's complementary
localparam signed [WIDTH-1:0]	HIGH_LEVEL = 1              ;
localparam signed [WIDTH-1:0]	LOW_LEVEL  = ~(HIGH_LEVEL)+1;

// "pdm_data_reg" is updated with the new one, when "pdm_read_enable" or "read_enable" is on
reg [CHANNELS-1:0] pdm_data_reg;
always @(posedge clk or posedge resetn) begin
	if (resetn)
		pdm_data_reg <= {CHANNELS{1'b0}};
	else begin
		if (pdm_read_enable)
			pdm_data_reg <= pdm_data;
		else
			pdm_data_reg <= pdm_data_reg;
	end
end

// PDM Data
reg signed [WIDTH-1:0] signed_data;
// change "0" and "1" into "LOW_LEVEL (-1)" and "HIGH_LEVEL (1)", respectively
always @(*) begin
	case(pdm_data_reg[channel]) // the whole of "pdm_data_reg[channel]" is considered
		1'b0 : signed_data = LOW_LEVEL;
		
		1'b1 : signed_data = HIGH_LEVEL;
	endcase
end
// data_int and data_comb save the PDM microphone data for each channel [0:7] in an alternating manner
wire signed [WIDTH-1:0] data_int [STAGES:0];
wire signed [WIDTH-1:0] data_comb[STAGES:0];
// initiate "data_int" with "signed_data"
assign data_int[0] = signed_data;

// Ongoing
genvar i;
generate
for (i=0; i<STAGES; i=i+1)
	begin: int_stage
		cic_int #(
		.WIDTH   	(WIDTH),		// 23
		.CHANNELS	(CHANNELS)		// 8
		) int0 (
		.clk     	(clk),			// input
		.resetn  	(resetn),		// input
		.wr_en   	(wr_en),		// input
		.read_en 	(read_en),		// input
		.channel 	(channel),		// input [2:0]
		.data_in 	(data_int[i]),	// input signed [22:0]
		.data_out	(data_int[i+1])	// output reg signed [22:0]
	);
	end
endgenerate
//CIC Data Out

// send the output of "integrator" to the input of "comb" 
assign data_comb[0] = data_int[STAGES];

genvar j;
generate
for (j=0; j<STAGES; j=j+1)
	begin: comb_stage
	cic_comb #(
		.WIDTH   	(WIDTH),				// 23
		.CHANNELS	(CHANNELS)				// 8
		) comb0 (
		.clk		(clk),					// input
		.resetn		(resetn),				// input
		.read_en	(read_en & comb_enable),// input, because "comb filter should be executed for each "Decimation ratio"
		.wr_en   	(write_memory),			// input
		.channel	(channel),				// input [2:0]
		.data_in	(data_comb[j]),			// input signed [22:0]
		.data_out	(data_comb[j+1])		// output reg signed [22:0]
	);
	end
endgenerate

//CIC Data Out
assign data_out = data_comb[STAGES];

endmodule
