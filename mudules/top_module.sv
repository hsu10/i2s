clock_generator clk_gen (
    .clk_i(system_clk),
    .rst_ni(reset_n),
    .enable_i(enable),
    .bclk_o(bclk),
    .lrclk_o(lrclk)
);

i2s_transmitter tx (
    .clk_i(system_clk),
    .rst_ni(reset_n),
    .enable_i(enable),
    .bclk_i(bclk),
    .lrclk_i(lrclk),
    .audio_data_i(tx_data),
    .audio_data_o(tx_serial_data),
    .wave_o(tx_wave)
);

i2s_receiver rx (
    .clk_i(system_clk),
    .rst_ni(reset_n),
    .enable_i(enable),
    .bclk_i(bclk),
    .lrclk_i(lrclk),
    .audio_data_i(rx_serial_data),
    .received_data_o(rx_data),
    .data_valid_o(rx_data_valid)
);