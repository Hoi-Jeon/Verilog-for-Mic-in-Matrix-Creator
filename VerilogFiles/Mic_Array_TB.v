// Verilog Test Bench for mic_array
`timescale  1 ns / 1 ps

module mic_array_TB;

parameter ADDR_WIDTH = 15;
parameter DATA_WIDTH = 16;

parameter SYS_FREQ_HZ = 150_000_000;
parameter OUT_FREQ_HZ = 16_000;
parameter PDM_FREQ_HZ = 3_000_000;

parameter [DATA_WIDTH-1:0] PDM_RATIO = $floor(SYS_FREQ_HZ/PDM_FREQ_HZ)-1; // 49
parameter [DATA_WIDTH-1:0] PDM_READING_TIME = $floor(7*PDM_RATIO/12); // 28
parameter [DATA_WIDTH-1:0] DECIMATION_RATIO = $floor((SYS_FREQ_HZ ) / (OUT_FREQ_HZ * (PDM_RATIO+1)))-1; // 186

parameter FIR_TAP = 128;
parameter FIR_TAP_WIDTH = 16;
parameter FIR_TAP_ADDR = $clog2(FIR_TAP); // 7

parameter CIC_DATA_WIDTH = 23;
parameter STAGES = 3;
parameter ADDR_WIDTH_BUFFER = 13; // address (or index) for mic. array buffer
parameter CHANNELS = 8;
parameter CHANNELS_WIDTH = $clog2(CHANNELS); // 3

// max. line number of PDM data external file
parameter NLINEFILE = 150000;
// Read time period: 2 was multiplied, since the one clock consists of two values, i.e. "one" and "zero"
parameter [DATA_WIDTH-1:0] PDM_FILE_READ_CLOCK = $floor(PDM_RATIO+1)*2; 

/*------------------------Inputs------------------------*/
reg	clk;
reg	resetn;
reg	out_clk;
reg [DATA_WIDTH-1:0] sample_rate = DECIMATION_RATIO; // 186
reg [DATA_WIDTH-1:0] data_gain;
wire [CHANNELS-1:0]	pdm_data;
wire [FIR_TAP_WIDTH-1:0] coeff_data; // FIR Coeff

/*------------------------Outputs------------------------*/
wire pdm_clk;
wire buffer_selector;
wire [DATA_WIDTH-1:0] data_out;
wire [FIR_TAP_ADDR-1:0] coeff_addr; // FIR Coeff. Index

// Instantiate the Unit, fir_data - read fir filter coefficients
fir_data #(
	.FIR_TAP		(FIR_TAP),
	.FIR_TAP_WIDTH	(FIR_TAP_WIDTH),
	.FIR_TAP_ADDR	(FIR_TAP_ADDR)
) fir_data0 (
	.clk			(clk),
	.resetn			(resetn),
	.coeff_addr		(coeff_addr),
	.coeff_data		(coeff_data)
);	 

// Index for PDM microphone signals
reg [ADDR_WIDTH:0] indx_PDM;

// Instantiate the Unit, pdm_data
pdm_data #(
	.CHANNELS	(CHANNELS), // 8
	.NLINEFILE	(NLINEFILE) // 15000
) pdm_data0 (
	.indx		(indx_PDM), // input [15-1:0] 
	.pdm_data	(pdm_data) // output reg [CHANNELS-1:0] 
);

// strobe signals
wire integrator_enable;
wire comb_enable;
wire write_memory;
wire pdm_read_enable  ;

// "data_cic" has [23-1:0] 
wire signed [CIC_DATA_WIDTH-1:0] data_cic;
// "channel" has [3-1:0]
wire [CHANNELS_WIDTH-1:0] channel;

// Instantiate the Unit, cic_sync
cic_sync #(
	.SYS_FREQ_HZ		(SYS_FREQ_HZ),
	.CHANNELS			(CHANNELS),
	.DATA_WIDTH			(DATA_WIDTH),
	.PDM_FREQ_HZ		(PDM_FREQ_HZ),
	.PDM_READING_TIME	(PDM_READING_TIME),
	.PDM_RATIO       	(PDM_RATIO)
) cic_sync0 (
	.clk				(clk),		// input
	.resetn				(resetn),	// input
	.pdm_clk			(pdm_clk),	// output reg
	.channel			(channel),	// input

	//CIC_Configuration_Registers
	.integrator_enable	(integrator_enable),// output reg
	.sample_rate      	(sample_rate),		// input >> DECIMATION_RATIO = 186
	.read_enable      	(pdm_read_enable),	// output reg
	.comb_enable      	(comb_enable)		// output 
);	

// Instantiate the Unit, cic
// Important to understand the structure of "data_cic"
cic #(
	.STAGES				(STAGES),			// 3
	.WIDTH				(CIC_DATA_WIDTH),	// 23
	.CHANNELS			(CHANNELS)			// 8
) cic0 (		
	.clk				(clk),				// input
	.resetn				(resetn),			// input
	.pdm_data			(pdm_data),			// input [CHANNELS-1:0] [8-1:0]
	.integrator_enable	(integrator_enable),// input wire
	.comb_enable		(comb_enable),		// input wire
	.data_out			(data_cic),			// output signed [WIDTH-1:0] [23-1:0]
	.channel			(channel),			// output [2:0]
	.pdm_read_enable	(pdm_read_enable),	// input wire
	.write_memory		(write_memory)		// output wire
);

// necessary variables for mic_fir module instantiation
wire[DATA_WIDTH-1:0] data_out_p;
wire write_data;
reg  [DATA_WIDTH-1:0] boundered_data;

// [<start_bit> +: <width>] // part-select increments from start-bit
// [<start_bit> -: <width>] // part-select decrements from start-bit

/* Example for two's complement
011: +3
010: +2
001: +1
000: 0
111: -1
110: -2
101: -3
100: -4
*/

// positive overflow detection: CIC_DATA_WIDTH=23
reg pof; // pof will be "1", in case a positive overflow will be detected after multiplying "data_gain"
always @(data_cic) begin
	case(data_gain) // data gain seems to the exponent of two, as of 22.10.2020
		0 : pof = 1'b0;
		1 : pof = data_cic[CIC_DATA_WIDTH-2];
		2 : pof = |data_cic[(CIC_DATA_WIDTH-2)-:2];
		3 : pof = |data_cic[(CIC_DATA_WIDTH-2)-:3];
		4 : pof = |data_cic[(CIC_DATA_WIDTH-2)-:4];
		5 : pof = |data_cic[(CIC_DATA_WIDTH-2)-:5];
		6 : pof = |data_cic[(CIC_DATA_WIDTH-2)-:6];
		7 : pof = |data_cic[(CIC_DATA_WIDTH-2)-:7];
		8 : pof = |data_cic[(CIC_DATA_WIDTH-2)-:8];
		9 : pof = |data_cic[(CIC_DATA_WIDTH-2)-:9];
		10: pof = |data_cic[(CIC_DATA_WIDTH-2)-:10];
		default : pof = 1'b1;
	endcase
end

//negative overflow detection: CIC_DATA_WIDTH=23
reg nof; // nof will be "1", in case a negative overflow will be detected after multiplying "data_gain"
always @(data_cic) begin
	case(data_gain)
		0 : nof = 1'b0;
		1 : nof = ~data_cic[CIC_DATA_WIDTH-2];
		2 : nof = ~(&data_cic[(CIC_DATA_WIDTH-2)-:2]);
		3 : nof = ~(&data_cic[(CIC_DATA_WIDTH-2)-:3]);
		4 : nof = ~(&data_cic[(CIC_DATA_WIDTH-2)-:4]);
		5 : nof = ~(&data_cic[(CIC_DATA_WIDTH-2)-:5]);
		6 : nof = ~(&data_cic[(CIC_DATA_WIDTH-2)-:6]);
		7 : nof = ~(&data_cic[(CIC_DATA_WIDTH-2)-:7]);
		8 : nof = ~(&data_cic[(CIC_DATA_WIDTH-2)-:8]);
		9 : nof = ~(&data_cic[(CIC_DATA_WIDTH-2)-:9]);
		10: nof = ~(&data_cic[(CIC_DATA_WIDTH-2)-:10]);
		default : nof = 1'b1;
	endcase
end

always @(data_cic) begin
	case({ (data_cic[CIC_DATA_WIDTH-1] & nof) ,  //  (nof =1) & (negative data_cic) >> negative overflow
					(~data_cic[CIC_DATA_WIDTH-1] & pof) }) // (pof =1) & (positive data_cic) >> negative overflow
		// positive overflow: Take the positive max. value
		2'b01   : boundered_data = {1'b0,{(DATA_WIDTH-1){1'b1}}}; // "0" + (23-1) times of "1"
		
		// negative overflow: Take the negative max. value (using two's complement)
		2'b10   : boundered_data = {1'b1,{(DATA_WIDTH-1){1'b0}}}; // "1" + (23-1) times of "0"
		
		// default
		//	boundered_data = reg  [23-1:0]
		//	- CIC_DATA_WIDTH = 23
		//	- DATA_WIDTH = 16
		//	"data gain" is considered here by shifting "data_gain" digit to left
		default : boundered_data ={	data_cic[CIC_DATA_WIDTH-1], 
									data_cic[(CIC_DATA_WIDTH-2-data_gain)-:DATA_WIDTH-1]}; 
	endcase
end

// Instantiate the Unit, mic_fir
mic_fir #(
	.DATA_WIDTH		(DATA_WIDTH), // 16
	.CHANNELS		(CHANNELS), // 8
	.CHANNELS_WIDTH	(CHANNELS_WIDTH), // 3
	.FIR_TAP_WIDTH	(FIR_TAP_WIDTH), // 16
	.FIR_TAP		(FIR_TAP), // 128
	.FIR_TAP_ADDR	(FIR_TAP_ADDR) // 7
) mic_fir0 (	
	.clk			(clk), // input 
	.resetn			(resetn), // input 
	.data_load		(write_memory), // input 
	.channel		(channel), // input 
	.data_in		(boundered_data), // input signed
	.data_out		(data_out_p), // output signed
	.write_data_mem	(write_data), // output
	//FIR Coeff	
	.coeff_addr		(coeff_addr), // output
	.coeff_data		(coeff_data) // input signed
); 


// "data_out_p" is the 16 bit signed data
always @(posedge write_data) begin		
	if (&fcount)
		$fwrite(fd, " %d \n", $signed(data_out_p)); 
	else 
		$fwrite(fd, " %d ", $signed(data_out_p)); // "data_out_p" is the 16 bit signed data		
	
	fcount = fcount + 1'b1;
end

// Define variables for file writing
integer fd;
reg[2:0] fcount;

// Initialize Inputs
initial begin	
	fd = $fopen("/home/kimhj/Xilinx_ISE_Test/Mic_Array/wb_mic_array/output_mic8.dat", "w");
	fcount = 0;
	
	clk = 0;
	resetn = 1;
	indx_PDM = 'b0; // Index for PDM data
	out_clk = 1;
	
	// "data_gain" should be carefully selected in Test Bench
	// Its definition seems to be "2**(data_gain)", to avoid any clipping
	// For the time being, let's use "data_gain=0"
	data_gain = 0; 

	// Reset to zero
	#1 
	resetn = 0;

	// End of Test Bench
	#15_000_000
	$fclose(fd); // close the file pointer
	$finish;
end

// Clock signal
always
	#1 
	begin
		clk = !clk;
	end

// Increase the index for PDM signal
always
#PDM_FILE_READ_CLOCK
begin
	indx_PDM = indx_PDM + 1'd1;
end	
  
endmodule
