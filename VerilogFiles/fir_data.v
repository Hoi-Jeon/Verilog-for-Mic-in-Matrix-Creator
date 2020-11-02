module fir_data #(
	parameter FIR_TAP = "mandatory",
	parameter FIR_TAP_WIDTH = "mandatory",
	parameter FIR_TAP_ADDR = "mandatory"
	)(
    input	clk,
	input	resetn,	
	input	[FIR_TAP_ADDR-1:0] coeff_addr,	
    output	reg signed [FIR_TAP_WIDTH-1:0] coeff_data
    );
	
	reg signed [FIR_TAP_WIDTH-1:0] fir_data [0:FIR_TAP-1];
	
	always @(posedge clk or posedge resetn) begin
		coeff_data <= fir_data[coeff_addr];
	end
	
	initial begin		
		// TODO: input the file path for a binary 128 FIR filter coefficients
		$readmemb("/home/kimhj/Xilinx_ISE_Test/Mic_Array/wb_mic_array/fir_bin.dat", fir_data);
	end

endmodule
