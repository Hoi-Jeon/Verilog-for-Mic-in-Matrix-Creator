module fir_pipe_fsm #(
	parameter CHANNELS       			= "mandatory",	// 8
	parameter CHANNELS_WIDTH 			= "mandatory",	// 3
	parameter FIR_TAP       			= "mandatory",	// 128
	parameter TAP_COUNT_WIDTH 			= $clog2(FIR_TAP)	// 7
) (
	input								clk,
	input								resetn,
	input								end_write_data,
	output reg [TAP_COUNT_WIDTH-1:0]	tap_count,		// coeff_addr
	output reg [ CHANNELS_WIDTH-1:0]	channel_count,
	output reg							load_data_memory,
	output reg							reset_tap,
	output								write_data
);

reg [2:0] state;
reg count_en, reset_channel;

assign write_data = count_en;

localparam [1:0] S_IDLE = 3'd0;
localparam [1:0] S_PIPE = 3'd1;
localparam [1:0] S_NEXT = 3'd2;

always @(state) begin
	case(state)
		S_IDLE : begin
			count_en         = 0;
			reset_tap        = 1;
			reset_channel    = 1;
			load_data_memory = 0;
		end
		S_PIPE : begin
			count_en         = 0;
			reset_tap        = 0;
			reset_channel    = 0;
			load_data_memory = 1;
		end
		S_NEXT : begin
			count_en         = 1;
			reset_tap        = 1;
			reset_channel    = 0;
			load_data_memory = 0;
		end
		default : begin
			count_en         = 0;
			reset_tap        = 1;
			reset_channel    = 1;
			load_data_memory = 0;
		end
	endcase
end

always @(posedge clk or posedge resetn) begin
	if(resetn | reset_tap) begin
		tap_count <= 0;
	end else begin
		tap_count <= tap_count + 1;
	end
end

always @(posedge clk or posedge resetn) begin
	if(resetn | reset_channel) begin
		channel_count <= 0;
	end else begin
		if(count_en)
		channel_count <= channel_count + 1;
	end
end

always @(posedge clk or posedge resetn) begin
	if(resetn)
		state <= S_IDLE;
	else begin
		case(state)
		S_IDLE : begin
			if(end_write_data)
                state <= S_PIPE;
			else
                state <= S_IDLE;
			end

		S_PIPE :
			if(tap_count == FIR_TAP-1) // PipeLine stages
			state <= S_NEXT;
			else
			state <= S_PIPE;

		S_NEXT :
			if(channel_count == CHANNELS-1)
			state <= S_IDLE;
			else
			state <= S_PIPE;

		default :
			state <= S_IDLE;

		endcase 
	end // if else
end // always

endmodule
