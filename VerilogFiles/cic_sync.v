module cic_sync #(
	parameter SYS_FREQ_HZ = "mandatory", 						// 150_000_000
	parameter PDM_FREQ_HZ = "mandatory", 						// 3_000_000
	parameter CHANNELS    = "mandatory",						// 8 
	parameter DATA_WIDTH = "mandatory",  						// 16
	parameter PDM_READING_TIME = "mandatory", 					// 28
	parameter PDM_RATIO = "mandatory",							// 49
	parameter COUNTER_WIDTH = $clog2(SYS_FREQ_HZ/PDM_FREQ_HZ),	// 6
	parameter CHANNELS_WIDTH = $clog2(CHANNELS)	// 3
 ) (
	input      						clk,
	input      						resetn,
	//CIC_Configuration_Register
	input [DATA_WIDTH-1:0]			sample_rate,	// DECIMATION_RATIO = 186
	input [$clog2(CHANNELS)-1:0] 	channel,		// [2:0]
	input 							cic_finish,
	
	output reg 						pdm_clk,
	output reg 						read_enable,
	output reg 						integrator_enable,
	output 							comb_enable
);

localparam [2:0] S_IDLE = 3'd0;
localparam [2:0] S_READING_TIME	= 3'd1;
localparam [2:0] S_COMPUTE = 3'd2;
localparam [2:0] S_HOLD = 3'd3;

reg  [COUNTER_WIDTH:0]	sys_count;				// [6:0] = [0, 127]
reg  [ DATA_WIDTH-1:0]	comb_count;
wire					pdm_conndition;
wire					comb_condition;
wire [COUNTER_WIDTH:0]	pdm_half_ratio = PDM_RATIO >> 1;

assign pdm_conndition = (sys_count == PDM_RATIO);
assign comb_condition = (comb_count == sample_rate);
assign comb_enable = comb_condition;

// a variable for state
reg [2:0] 												state;

always @(state) begin
	case(state)
		S_IDLE :
		{integrator_enable,read_enable} = {1'b0,1'b0};

		S_READING_TIME :
		{integrator_enable,read_enable}= {1'b0,1'b1};

		S_COMPUTE :
		{integrator_enable,read_enable} = {1'b1,1'b0};

		S_HOLD :
		{integrator_enable,read_enable} = {1'b1,1'b0};

		default :
		{integrator_enable,read_enable} = {1'b0,1'b0};
	endcase
end

always @(posedge clk or posedge resetn) begin
	if(resetn)
		state <= S_IDLE;
	else begin
		case(state)
			S_IDLE :
				if( sys_count == PDM_READING_TIME)
					state <= S_READING_TIME;
				else
					state <= S_IDLE;
			S_READING_TIME :
				state <= S_COMPUTE;
			S_COMPUTE :
				state <= S_HOLD;
			S_HOLD :
				if(channel == (CHANNELS-1))
					state <= S_IDLE;
				else
					state <= S_COMPUTE;
			default :
			state <= S_IDLE;			
		endcase
	end
end
  
// sys_count count & reset 
always @(posedge clk or posedge resetn) begin
	if (resetn)
		sys_count <= {COUNTER_WIDTH{1'b0}};
	else begin
		if (pdm_conndition) // pdm_conndition = (sys_count == PDM_RATIO);
			sys_count <= {COUNTER_WIDTH{1'b0}}; // COUNTER_WIDTH = 6
		else
			sys_count <= sys_count + 1'b1;
		end
end
  
// pdm_clk generate
always @(posedge clk or posedge resetn) begin
	if (resetn | pdm_conndition)
		pdm_clk <= 1'b1;
	else begin
		if (sys_count == pdm_half_ratio)
			pdm_clk <= 1'b0;
		else
			pdm_clk <= pdm_clk;
		end
end
  
// comb_count increases by +1 in each "pdm_condition" and it is reset at each "decimation_ratio"
always @(posedge clk or posedge resetn) begin
	if (resetn)
		comb_count <= {COUNTER_WIDTH{1'b0}}; // COUNTER_WIDTH = 6
	else
		if (pdm_conndition) begin // pdm_conndition = (sys_count == PDM_RATIO);
			if(comb_condition) // comb_condition = (comb_count == sample_rate); 
				comb_count <= 0;
			else
				comb_count <= comb_count + 1;
		end
end

endmodule
