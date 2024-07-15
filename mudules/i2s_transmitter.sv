/**
*  @file   i2s_master.sv
*  @brief  I2S master for sending 24bit audio data to audio codec
*
*  Sending audio data from voice control on both stereo channels.
*  Data is sampled on rising edge of LRCLK.
*
*  All calculations are hardcoded, so you need to change
*  localparams and especially TRA_CLK_DIVISION, if it is required to change:
*   - System Clock (40 MHz);
*   - Audio Frame (64 bit);
*   - Sample Rate (44.1 kHz).
*  More details below in params sections.
*
*  Used standard I2S convention of 1bclk delay.
*  
*  @author Vladyslav Sorokin
*/

module i2s_transmitter #(
    parameter logic [7:0] TRA_CLK_DIVISION = 8'd14,
    parameter logic [7:0] TRA_AUDIO_WORD_LEN = 8'd24,
    parameter logic [7:0] TRA_AUDIO_FRAME_LEN = 8'd64
) (
    input                             clk_i,
    input                             rst_ni,
    input                             enable_i,
    input        [TRA_AUDIO_WORD_LEN-1:0] audio_data_i,
    output logic [TRA_AUDIO_WORD_LEN-1:0] wave_o,
    output logic                      audio_data_o,
    input logic                      audio_lrclk_o,
    input logic                      audio_bclk_o
);
  // Derived parameters
  localparam logic [7:0] BCLK_CNTR_HALF_CC = TRA_CLK_DIVISION / 2 - 1;
  localparam logic [7:0] BCLK_CNTR_FULL_CC = BCLK_CNTR_HALF_CC * 2 + 1;
  localparam logic [7:0] AUDIO_FRAME_CNTR_HALF = TRA_AUDIO_FRAME_LEN / 2 - 1;

  initial begin
    assert (AUDIO_FRAME_CNTR_HALF + 1 >= TRA_AUDIO_WORD_LEN)
    else $error("Assertion failed: AUDIO_FRAME_CNTR_HALF + 1 must be >= TRA_AUDIO_WORD_LEN");
  end
  ////////////////////////////
  // Main FSM
  ////////////////////////////
  logic [AUDIO_FRAME_CNTR_HALF:0] audio_data_local;  // local data storage, updated along with LRCLK
  logic [7:0] frame_cntr;  // counter for audio frame
  logic [7:0] elapsed_cycles;  // counter for serial clock
  logic saved_data_flag;  // data was saved for the whole audio frame

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      elapsed_cycles <= BCLK_CNTR_FULL_CC;
      //audio_bclk_o <= 1'b0;

      saved_data_flag <= 1'b0;
      audio_data_local <= 32'b0;
      audio_data_o <= 1'b0;
      wave_o <= 24'b0;

      frame_cntr <= AUDIO_FRAME_CNTR_HALF;
      //audio_lrclk_o <= 1'b1;
    end else begin
      if (enable_i == 1) begin
        elapsed_cycles <= elapsed_cycles - 1;
        audio_data_o   <= audio_data_local[frame_cntr];

        // BCLK half period
        if (elapsed_cycles <= 0) begin
          //audio_bclk_o   <= ~audio_bclk_o;
          elapsed_cycles <= BCLK_CNTR_HALF_CC;

          // Update data and audio frame on posedge BCLK
          if (audio_bclk_o == 1) begin
            frame_cntr <= frame_cntr - 1;
            if (frame_cntr == 0) begin
              // Sending same data on both DACs, updating at the start of left DAC
              // LRCLK 0: left; LRCLK 1: right
              if (audio_lrclk_o == 1) begin
                wave_o <= audio_data_i;
                audio_data_local <= {
                  1'b0, audio_data_i, {(AUDIO_FRAME_CNTR_HALF - TRA_AUDIO_WORD_LEN) {1'b0}}
                };
                saved_data_flag <= 1'b1;
              end else begin
                // prepearing flag on right
                saved_data_flag <= 1'b0;
              end

             // audio_lrclk_o <= ~audio_lrclk_o;
              frame_cntr <= AUDIO_FRAME_CNTR_HALF;
            end
          end
        end
      end
    end
  end

endmodule
