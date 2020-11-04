# Verilog for Microphones in Matrix Creator
The [MATRIX Creator](https://matrix-io.github.io/matrix-documentation/matrix-creator/overview/) is a fully-featured development board, including sensors, wireless communications, and an FPGA. The purpose of this hobby project is to investigate its FPGA code for 8 [PDM microphones](https://matrix-io.github.io/matrix-documentation/matrix-creator/resources/microphone/).

![Matrix Creator ODAS example](Pictures/ODAS_Matrix_Creator.gif)
[ODAS](https://www.hackster.io/matrix-labs/direction-of-arrival-for-matrix-voice-creator-using-odas-b7a15b) is a library for direction of arrival, tracking in Matrix Creator 

## Structure of FPGA code for PDM microphones

![FPGA_File_Structure](Pictures/FPGA_File_Structure.png)


## Test bench of FPGA code for PDM microphones
The structure of test bench of FPGA code for PDM microphones is as shown below:
![TestBench_Structure](Pictures/FPGA_TestBench_Structure.png)

### Mic_Array_TB.v
TBD
- Sys. Freq: 150 Mhz
- Out Freq: 16 kHz
- PDM Freq: 3 Mhz
- PDM ratio: 49
- PDM Reading Time: 28
- Decimation ratio (sample rate): 186 (i.e. PDM Freq / Out Freq)


### fir_data.v
TBD

### pdm_data.v
TBD

### cic_sync.v
TBD

### cic.v
TBD

#### cic_op_fsm.v
TBD

#### cic_int.v
TBD
![Integrator Filter in CIC](Pictures/Integrator_Filter.png)

```
assign sum = data_out + data_in;

always @(posedge clk or posedge resetn) begin
  if (resetn)
    data_out <= 0;
  else begin
  case({read_en,wr_en})
    2'b10 : begin
      data_out <= accumulator[channel];
      end

    2'b01 : begin
      accumulator[channel] <= sum;
      data_out <= data_out; 
      end

    default :
    data_out <= data_out;
    endcase
  end
end
```


#### cic_comb.v
TBD
![Comb Filter in CIC](Pictures/Comb_Filter.png)

```
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


### fir.v
TBD
- Filter information
  - 128 FIR TAB
  - 3 stages CIC
  - General information

#### fir_pipe_fsm.v
TBD

#### mic_array_buffer.v
TBD



## Open points
- TBD

