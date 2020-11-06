# Verilog for Microphones in Matrix Creator
The [MATRIX Creator](https://matrix-io.github.io/matrix-documentation/matrix-creator/overview/) is a fully-featured development board, including sensors, wireless communications, and an FPGA. The purpose of this hobby project is to investigate its FPGA code for 8 [PDM microphones](https://matrix-io.github.io/matrix-documentation/matrix-creator/resources/microphone/).  

![Matrix Creator ODAS example](Pictures/ODAS_Matrix_Creator.gif)
</br>*<An example of applying beam-forming with [ODAS](https://www.hackster.io/matrix-labs/direction-of-arrival-for-matrix-voice-creator-using-odas-b7a15b), which is a library for direction of arrival, tracking in Matrix Creator>*

## Structure of FPGA code for PDM microphones
Matrix creator uses the Wishbone Bus to communicate between RPi and several sensors. The [Wishbone Bus](https://en.wikipedia.org/wiki/Wishbone_(computer_bus)) is an open source hardware computer bus intended to let the parts of an integrated circuit communicate with each other. Among the whole Matrix Creator's Verilog modules, there are two modules, which are relevant to receiving the signals from 8 PDM microphones, i.e. ***wb_mic_array.v*** and ***bram.v***. The main part for reading microphone signals is ***wb_mic_array.v*** and ***bram.v*** is only providing the *"decimation ratio"* and *"microphone gain"* to ***wb_mic_array.v***.

![FPGA_File_Structure](Pictures/FPGA_File_Structure.png)
</br><*A structure of FPGA code for PDM microphones*>

## Test bench of FPGA code for PDM microphones

In order to create a test bench for reading and post-processing data **only** from 8 PDM microphones, some parts of the above full FPGA strucutre were selected and modified. Its Hierarchy in ***Xilinx ISE Design Suite*** is shown below:

![TestBench_Structure](Pictures/FPGA_TestBench_Structure.png)
</br><*A structure of Test Bench for PDM microphones*>

### mic_array_TB
*"Mic_Array_TB.v"* is the main module for this test bench. Here, several important frequencies are defined as follows:

- System clock frequency: 150 Mhz
- PDM frequency: 3 Mhz
- Output frequency: 16 Khz
- PDM ratio: 50 (i.e. System clock frequency / PDM frequency)
- Decimation ratio: 187 (i.e. PDM frequency / Output frequency)

The frequency for reading signals from PDM microphone is set by *PDM_FILE_READ_CLOCK*.
```verilog
// Read time period: 2 was multiplied, since the one clock consists of two values, i.e. "one" and "zero"
parameter [DATA_WIDTH-1:0] PDM_FILE_READ_CLOCK = $floor(PDM_RATIO+1)*2; 

always
#PDM_FILE_READ_CLOCK
begin
  indx_PDM = indx_PDM + 1'd1;
end
```

The ascii file for saving the ouput of test bench is opened/written/closed in this main module. Please be aware that one can start receiving the test bench outputs only after the first number of time steps reaches the size FIR filter coeffcient.
```verilog
integer fd;
fd = $fopen("location of output ascii file", "w");
$fclose(fd); 
```


### fir_data
*"fir_data.v"* is the module for reading the FIR filter coefficient from an external ascii file. In this test bench, 128 FIR filter coefficient should be used, so this external ascii file should have 128 row in a single column. The values should be written in **16 bit fixed-point in binary** and **two's complement for negative numbers**.

```verilog
// define an array for saving the read FIR filter coefficient
reg signed [FIR_TAP_WIDTH-1:0] fir_data [0:FIR_TAP-1]; // FIR_TAP_WIDTH = 16 and FIR_TAP = 128

initial begin
  $readmemb("location of ascii file including FIR filter coefficient", fir_data);
end
```

### pdm_data
*"pdm_data.v"* is the module for reading PDM microphone signals from an external ascii file. This external ascii file should have 8 binary digit in a single row and the maximum number of row should be under 150,000, which can be changed in [Mic_Array_TB.v](#mic_array_tb).

```verilog
# Define a 2D array for saving 150_000 x 8 data from an external ascii file
reg [CHANNELS-1:0] in_data [0:NLINEFILE-1];

# Output PDM data from the 2D array "in_data", whenever input "indx" changes
always @ (indx)
  pdm_data = in_data [indx];

initial
  $readmemb("location of ascii file including the input PDM file", in_data);
```

### cic_sync
*"cic_sync.v"* is the module for controlling the following outputs:
- **pdm_clk** is one bit *reg* having a positive edge, when a new PDM signal is available
- **read_enable** is one bit *reg* being *true*, when a new PDM signal is ready to be read
- **integrator_enable** is one bit *reg* being *true*, while 1~8 PDM signals are being read
- **comb_enable** is one bit *reg* being *true*, in every decimation during one period of **pdm_clk**

![cic_sync_1](Pictures/cic_sync_1.png)
</br><*Waveform in cic_sync.v*>

![cic_sync_2](Pictures/cic_sync_2.png)
</br><*1st zoomed-in Waveform in cic_sync.v*>


***state[2:0]*** above is defined as follows and its changes over clocks can be displayed below:

```verilog
localparam [2:0] S_IDLE = 3'd0;
localparam [2:0] S_READING_TIME	= 3'd1;
localparam [2:0] S_COMPUTE = 3'd2;
localparam [2:0] S_HOLD = 3'd3;
```

![cic_sync_3](Pictures/cic_sync_3.png)
</br><*2nd zoomed-in Waveform in cic_sync.v*>



### cic
*"cic.v"* is the module for performing [CIC filter](https://en.wikipedia.org/wiki/Cascaded_integrator%E2%80%93comb_filter).



```verilog

```

```verilog

```


#### cic_op_fsm
*"cic_op_fsm.v"* is the instantiated module under [cic.v](#cic), for controling the reading PDM microphone signals in each channel. ***state[2:0]*** in this module is defined as in the following Verilog codes and its changes over clocks can be displayed in the Waveform below:
```verilog
localparam [2:0] S_IDLE  = 3'd0;
localparam [2:0] S_READ  = 3'd1;
localparam [2:0] S_STORE = 3'd2;
```
![cic_op_fsm_1](Pictures/cic_op_fsm_1.png)
</br><*Waveform in cic_op_fsm.v*>


#### cic_int
*cic_int.v* is the instantiated module under [cic.v](#cic) and it acts as an integrator. Its working principle is described in the diagram and short Verilog codes. This module should be activated for each **read_en** in [cic_sync.v](#cic_sync).

![Integrator Filter in CIC](Pictures/Integrator_Filter.png)

```verilog
assign sum = data_out + data_in;

always @(posedge clk or posedge resetn) begin
  if (resetn)
    data_out <= 0;
  else begin
  case({read_en,wr_en})
    2'b10 : 
      begin
        data_out <= accumulator[channel];
      end

    2'b01 : 
      begin
        accumulator[channel] <= sum;
        data_out <= data_out; 
      end

    default :
      data_out <= data_out;
    endcase
  end
end
```





#### cic_comb
*cic_comb.v* is the instantiated module under [cic.v](#cic) and it acts as a comb filter. Its working principle is described in the diagram and short Verilog codes. This module should be activated for each **read_en** & **comb_enable** in [cic_sync.v](#cic_sync).


![Comb Filter in CIC](Pictures/Comb_Filter.png)

```verilog
assign diff = data_in - prev;

always @(posedge clk or posedge resetn) begin
    if (resetn) begin
    data_out <= 0;
    prev     <= 0;
  end
  else begin
    case({read_en,wr_en})
    2'b10 :
      begin
        data_out <= data_out_prev[channel];
        prev     <= data_in_prev[channel];
      end
    2'b01 :
      begin
        data_in_prev[channel]  <= data_in;
        data_out_prev[channel] <= diff;
      end
    default :
      data_out <= data_out;
    endcase
  end
end
```


### fir
*fir.v* is the module for **.

- Filter information
  - 128 FIR TAB
  - 3 stages CIC
  - General information

#### fir_pipe_fsm
*fir_pipe_fsm.v* is the module for **.

#### mic_array_buffer
*mic_array_buffer.v* is the module for **.


## Open points
- TBD

