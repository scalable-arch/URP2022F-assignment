`include "TIME_SCALE.svh"
`include "SAL_DDR_PARAMS.svh"

module SAL_TB_TOP;

    logic                       clk;
    logic                       rst_n;

    // clock generation
    initial begin
        clk                         = 1'b0;
        forever
            #(`CLK_PERIOD/2) clk         = ~clk;
    end

    // reset generation
    initial begin
        // activate the reset (active low)
        rst_n                       = 1'b0;
        repeat (3) @(posedge clk);
        // release the reset after 10 cycles
        rst_n                       = 1'b1;
    end

    APB_IF                          apb_if      (.clk(clk), .rst_n(rst_n));
    AXI_A_IF                        axi_ar_if   (.clk(clk), .rst_n(rst_n));
    AXI_R_IF                        axi_r_if    (.clk(clk), .rst_n(rst_n));
    AXI_A_IF                        axi_aw_if   (.clk(clk), .rst_n(rst_n));
    AXI_W_IF                        axi_w_if    (.clk(clk), .rst_n(rst_n));
    AXI_B_IF                        axi_b_if    (.clk(clk), .rst_n(rst_n));

    DFI_CTRL_IF                     dfi_ctrl_if (.clk(clk), .rst_n(rst_n));
    DFI_WR_IF                       dfi_wr_if   (.clk(clk), .rst_n(rst_n));
    DFI_RD_IF                       dfi_rd_if   (.clk(clk), .rst_n(rst_n));

    wire                            ddr_ck;
    wire                            ddr_ck_n;
    wire                            ddr_cke;
    wire    [`DDR_CS_WIDTH-1:0]     ddr_cs_n;
    wire                            ddr_ras_n;
    wire                            ddr_cas_n;
    wire                            ddr_we_n;
    wire    [`DDR_BA_WIDTH-1:0]     ddr_ba;
    wire    [`DDR_ADDR_WIDTH-1:0]   ddr_addr;
    wire                            ddr_odt;

    wire    [63:0]                  ddr_dq;
    wire    [7:0]                   ddr_dqs;
    wire    [7:0]                   ddr_dqs_n;
    wire    [7:0]                   ddr_dm_rdqs;
    wire    [7:0]                   ddr_rdqs_n;

    SAL_DDR_CTRL                    u_dram_ctrl
    (
        .clk                        (clk),
        .rst_n                      (rst_n),

        // APB interface
        .apb_if                     (apb_if),

        // AXI interface
        .axi_ar_if                  (axi_ar_if),
        .axi_aw_if                  (axi_aw_if),
        .axi_w_if                   (axi_w_if),
        .axi_b_if                   (axi_b_if),
        .axi_r_if                   (axi_r_if),

        // DFI interface
        .dfi_ctrl_if                (dfi_ctrl_if),
        .dfi_wr_if                  (dfi_wr_if),
        .dfi_rd_if                  (dfi_rd_if)
    );

    DDRPHY                          u_ddrphy
    (
        .clk                        (clk),
        .rst_n                      (rst_n),

        .dfi_ctrl_if                (dfi_ctrl_if),
        .dfi_wr_if                  (dfi_wr_if),
        .dfi_rd_if                  (dfi_rd_if),

        // command and address
        .ck                         (ddr_ck),
        .ck_n                       (ddr_ck_n),
        .cke                        (ddr_cke),
        .cs_n                       (ddr_cs_n),
        .ras_n                      (ddr_ras_n),
        .cas_n                      (ddr_cas_n),
        .we_n                       (ddr_we_n),
        .ba                         (ddr_ba),
        .addr                       (ddr_addr),
        .odt                        (ddr_odt),

        // data
        .dq                         (ddr_dq),
        .dqs                        (ddr_dqs),
        .dqs_n                      (ddr_dqs_n),
        .dm_rdqs                    (ddr_dm_rdqs),
        .rdqs_n                     (ddr_rdqs_n)
    );

    ddr2_dimm                       u_rank0
    (
        // command and address
        .ck                         (ddr_ck),
        .ck_n                       (ddr_ck_n),
        .cke                        (ddr_cke),
        .cs_n                       (ddr_cs_n[0]),
        .ras_n                      (ddr_ras_n),
        .cas_n                      (ddr_cas_n),
        .we_n                       (ddr_we_n),
        .ba                         (ddr_ba),
        .addr                       (ddr_addr),
        .odt                        (ddr_odt),

        // data
        .dq                         (ddr_dq),
        .dqs                        (ddr_dqs),
        .dqs_n                      (ddr_dqs_n),
        .dm_rdqs                    (ddr_dm_rdqs),
        .rdqs_n                     (ddr_rdqs_n)
    );

    ddr2_dimm                       u_rank1
    (
        // command and address
        .ck                         (ddr_ck),
        .ck_n                       (ddr_ck_n),
        .cke                        (ddr_cke),
        .cs_n                       (ddr_cs_n[1]),
        .ras_n                      (ddr_ras_n),
        .cas_n                      (ddr_cas_n),
        .we_n                       (ddr_we_n),
        .ba                         (ddr_ba),
        .addr                       (ddr_addr),
        .odt                        (ddr_odt),

        // data
        .dq                         (ddr_dq),
        .dqs                        (ddr_dqs),
        .dqs_n                      (ddr_dqs_n),
        .dm_rdqs                    (ddr_dm_rdqs),
        .rdqs_n                     (ddr_rdqs_n)
    );

    task init();
        axi_aw_if.init();
        axi_w_if.init();
        axi_b_if.init();
        axi_ar_if.init();
        axi_r_if.init();

        // wait for a reset release
        @(posedge rst_n);

        // wait enough cycles for DRAM to finish their initialization
        repeat (250) @(posedge clk);
    endtask

    axi_id_t                        simple_id;
    assign  simple_id               = 'd0;

    task automatic write32B (
        input   axi_addr_t          addr,
        input   [255:0]             data
    );
        axi_id_t                    rid;
        axi_resp_t                  rresp;

        // drive to AW and W
        fork
            begin
                axi_aw_if.send(simple_id, addr, 'd1, `AXI_SIZE_128, `AXI_BURST_INCR);
            end
            begin
                axi_w_if.send(simple_id, data[127:0], 16'hFFFF, 1'b0);
                axi_w_if.send(simple_id, data[255:128], 16'hFFFF, 1'b1);
            end
        join

        // receive from B
        axi_b_if.recv(rid, rresp);

        // check responses
        if (rid!==simple_id) begin $display("ID mismatch (expected: %d, received: %d)", simple_id, rid); $finish; end
        if (rresp!==2'b00) begin $display("Non-OK response (received: %d)", rresp); $finish; end
    endtask

    task automatic read32B(
        input   axi_addr_t          addr,
        output  [255:0]             data
    );
        axi_id_t                    rid;
        axi_resp_t                  rresp;
        logic                       rlast;

        // drive to AR
        axi_ar_if.send(simple_id, addr, 'd1, `AXI_SIZE_128, `AXI_BURST_INCR);

        // receive from R
        axi_r_if.recv(rid, data, rresp, rlast);
        if (rlast!==1'b0) begin $display("RLAST mismatch (expected: %d, received: %d)", 0, rlast); $finish; end
        if (rid!==simple_id) begin $display("ID mismatch (expected: %d, received: %d)", simple_id, rid); $finish; end
        if (rresp!==2'b00) begin $display("Non-OK response (received: %d)", rresp); $finish; end

        axi_r_if.recv(rid, data, rresp, rlast);
        if (rlast!==1'b1) begin $display("RLAST mismatch (expected: %d, received: %d)", 1, rlast); $finish; end
        if (rid!==simple_id) begin $display("ID mismatch (expected: %d, received: %d)", simple_id, rid); $finish; end
        if (rresp!==2'b00) begin $display("Non-OK response (received: %d)", rresp); $finish; end
    endtask


    logic   [255:0]             data;
    initial begin
        init();

        write32B('d0,   {8{32'h01234567}});    // bank 0, row 0, col 0~3
        write32B('d8200,   {8{32'h01234567}}); // bank 1, row 0, col 0~3
        write32B('d16400,  {8{32'h99999999}}); // bank 2, row 0, col 0~3
        write32B('d24600,  {8{32'h88888888}}); // bank 3, row 0, col 0~3
        write32B('d32800,  {8{32'h77777777}}); // bank 0, row 1, col 4~7
        write32B('d41000,  {8{32'h11111111}}); // bank 1, row 1, col 4~7
        read32B('d0, data);                    // bank 0, row 0, col 0~3
        read32B('d8200, data);                 // bank 1, row 0, col 0~3

        repeat (100) @(posedge clk);

        write32B('d19000,   {8{32'h01234567}}); // bank 2, row 0, col 144~147
        write32B('d32,  {8{32'h01234567}});     // bank 0, row 0, col 4~7
        read32B('d0, data);                     // bank 0, row 0, col 0~3
        read32B('d32, data);                    // bank 0, row 0, col 4~7

        $finish;
    end

endmodule // sim_tb_top
