module pdm_data #(
	parameter CHANNELS = "mandatory",
	parameter NLINEFILE = "mandatory"	
   )(
    input [15-1:0] indx,
    output reg [CHANNELS-1:0] pdm_data
    );

	reg [CHANNELS-1:0] in_data [0:NLINEFILE-1];

	always @ (indx)
	  pdm_data = in_data [indx];

	initial
		// TODO: input the file path for 8 channel PDM data
		$readmemb("/home/kimhj/Xilinx_ISE_Test/Mic_Array/wb_mic_array/input_mic8.dat", in_data);
		
endmodule
