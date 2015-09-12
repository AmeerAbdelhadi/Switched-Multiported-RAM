////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2014, University of British Columbia (UBC); All rights reserved. //
//                                                                                //
// Redistribution  and  use  in  source   and  binary  forms,   with  or  without //
// modification,  are permitted  provided that  the following conditions are met: //
//   * Redistributions   of  source   code  must  retain   the   above  copyright //
//     notice,  this   list   of   conditions   and   the  following  disclaimer. //
//   * Redistributions  in  binary  form  must  reproduce  the  above   copyright //
//     notice, this  list  of  conditions  and the  following  disclaimer in  the //
//     documentation and/or  other  materials  provided  with  the  distribution. //
//   * Neither the name of the University of British Columbia (UBC) nor the names //
//     of   its   contributors  may  be  used  to  endorse  or   promote products //
//     derived from  this  software without  specific  prior  written permission. //
//                                                                                //
// THIS  SOFTWARE IS  PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" //
// AND  ANY EXPRESS  OR IMPLIED WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE //
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE //
// DISCLAIMED.  IN NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE //
// FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL //
// DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS OR //
// SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER //
// CAUSED AND ON ANY THEORY OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY, //
// OR TORT  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE //
// OF  THIS SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE. //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                smpram_tb.v: switched multiported-RAM testbench                 //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////


`include "utils.vh"

module smpram_tb;

  // design parameters
  localparam MEMD = `MEMD; // memory depth
  localparam DATW = `DATW; // data width
  localparam nRPF = `nRPF; // number of fixed (simple) read  ports
  localparam nWPF = `nWPF; // number of fixed (simple) write ports
  localparam nRPS = `nRPS; // number of switched       read  ports
  localparam nWPS = `nWPS; // number of switched       write ports
  localparam CYCC = `CYCC; // simulation cycles count
  localparam BYPS = `BYPS; // set data-dependency and allowance
                           // bypassing type: NON, WAW, RAW, RDW
                           // WAW: Allow Write-After-Write
                           // RAW: new data for Read-after-Write
                           // RDW: new data for Read-During-Write
  localparam VERB = `VERB; // verbose logging (1:yes; 0:no)

  // total ports number
  localparam nWPT = nWPF+nWPS;
  localparam nRPT = nRPF+nRPS;

  // bypassing indicators
  localparam WDWB  = 0                           ; // allow Write-During-Write (WDW)
  localparam WAWB  =  BYPS!="NON"                ; // allow Write-After-Write (WAW)
  localparam RAWB  = (BYPS=="RAW")||(BYPS=="RDW"); // new data for Read-After-Write (RAW)
  localparam RDWB  =  BYPS=="RDW"                ; // new data for Read-During-Write (RDW)

  // local parameters
  localparam ADRW    = `log2(MEMD); // address size
  localparam CYCT    = 10         ; // cycle      time
  localparam RSTT    = 5.2*CYCT   ; // reset      time
  localparam TERFAIL = 0          ; // terminate if fail?
  localparam TIMEOUT = 2*CYCT*CYCC; // simulation time

  reg                  clk = 1'b0                 ; // global clock
  reg                  rst = 1'b1                 ; // global reset
  reg                  rdWr                       ; // switch read/write (write is active low)
  reg  [     nWPT-1:0] WEnb                       ; // write enable for each writing port
  reg  [ADRW*nWPT-1:0] WAddr_pck                  ; // write addresses - packed from nWPT write ports
  reg  [ADRW     -1:0] WAddr_upk        [nWPT-1:0]; // write addresses - unpacked 2D array 
  reg  [ADRW*nRPT-1:0] RAddr_pck                  ; // read  addresses - packed from nRPT  read  ports
  reg  [ADRW     -1:0] RAddr_upk        [nRPT-1:0]; // read  addresses - unpacked 2D array 
  reg  [DATW*nWPT-1:0] WData_pck                  ; // write data - packed from nWPT read ports
  reg  [DATW     -1:0] WData_upk        [nWPT-1:0]; // write data - unpacked 2D array 
  wire [DATW*nRPT-1:0] RData_pck_reg              ; // read  data - packed from nRPT read ports
  reg  [DATW     -1:0] RData_upk_reg    [nRPT-1:0]; // read  data - unpacked 2D array 
  wire [DATW*nRPT-1:0] RData_pck_xor              ; // read  data - packed from nRPT read ports
  reg  [DATW     -1:0] RData_upk_xor    [nRPT-1:0]; // read  data - unpacked 2D array
  wire [DATW*nRPT-1:0] RData_pck_lvtreg           ; // read  data - packed from nRPT read ports
  reg  [DATW     -1:0] RData_upk_lvtreg [nRPT-1:0]; // read  data - unpacked 2D array 
  wire [DATW*nRPT-1:0] RData_pck_lvtbin           ; // read  data - packed from nRPT read ports
  reg  [DATW     -1:0] RData_upk_lvtbin [nRPT-1:0]; // read  data - unpacked 2D array 
  wire [DATW*nRPT-1:0] RData_pck_lvt1ht           ; // read  data - packed from nRPT read ports
  reg  [DATW     -1:0] RData_upk_lvt1ht [nRPT-1:0]; // read  data - unpacked 2D array 

  integer i,j; // general indeces

  // generates random ram hex/mif initializing files
  task genInitFiles;
    input [31  :0] DEPTH  ; // memory depth
    input [31  :0] WIDTH  ; // memoty width
    input [255 :0] INITVAL; // initial vlaue (if not random)
    input          RAND   ; // random value?
    input [1:8*20] FILEN  ; // memory initializing file name
    reg   [255 :0] ramdata;
    integer addr,hex_fd,mif_fd;
    begin
      // open hex/mif file descriptors
      hex_fd = $fopen({FILEN,".hex"},"w");
      mif_fd = $fopen({FILEN,".mif"},"w");
      // write mif header
      $fwrite(mif_fd,"WIDTH         = %0d;\n",WIDTH);
      $fwrite(mif_fd,"DEPTH         = %0d;\n",DEPTH);
      $fwrite(mif_fd,"ADDRESS_RADIX = HEX;\n"      );
      $fwrite(mif_fd,"DATA_RADIX    = HEX;\n\n"    );
      $fwrite(mif_fd,"CONTENT BEGIN\n"             );
      // write random memory lines
      for(addr=0;addr<DEPTH;addr=addr+1) begin
        if (RAND) begin
          `GETRAND(ramdata,WIDTH); 
        end else ramdata = INITVAL;
        $fwrite(hex_fd,"%0h\n",ramdata);
        $fwrite(mif_fd,"  %0h :  %0h;\n",addr,ramdata);
      end
      // write mif tail
      $fwrite(mif_fd,"END;\n");
      // close hex/mif file descriptors
      $fclose(hex_fd);
      $fclose(mif_fd);
    end
  endtask

  integer rep_fd, ferr;
  initial begin
    // write header
    rep_fd = $fopen("sim.res","r"); // try to open report file for read
    $ferror(rep_fd,ferr);       // detect error
    $fclose(rep_fd);
    rep_fd = $fopen("sim.res","a+"); // open report file for append
    if (ferr) begin     // if file is new (can't open for read); write header
      $fwrite(rep_fd,"Multiported     RAM     Architectural     Parameters   Simulation Results for Different Designs \n");
      $fwrite(rep_fd,"====================================================   =========================================\n");
      $fwrite(rep_fd,"Memory   Data    Write   Read    Bypass   Simulation   XOR-based   Reg-LVT   SRAM-LVT   SRAM-LVT\n");
      $fwrite(rep_fd,"Depth    Width   Ports   Ports   Type     Cycles                              Binary     Onehot \n");
      $fwrite(rep_fd,"================================================================================================\n");
    end
    $write("Simulating multi-ported RAM:\n");
    $write("Fixed    write ports: %0d\n"  ,nWPF  );
    $write("Fixed    read  ports: %0d\n"  ,nRPF  );
    $write("switched write ports: %0d\n"  ,nWPS  );
    $write("switched read  ports: %0d\n"  ,nRPS  );
    $write("Data width          : %0d\n"  ,DATW  );
    $write("RAM depth           : %0d\n"  ,MEMD  );
    $write("Address width       : %0d\n\n",ADRW  );
    // generate random ram hex/mif initializing file
    genInitFiles(MEMD,DATW   ,0,1,"init_ram");
    // finish simulation
    #(TIMEOUT) begin 
      $write("*** Simulation terminated due to timeout\n");
      $finish;
    end
  end

  // generate clock and reset
  always  #(CYCT/2) clk = ~clk; // toggle clock
  initial #(RSTT  ) rst = 1'b0; // lower reset

  // pack/unpack data and addresses
  `ARRINIT;
  always @* begin
    // packing/unpacking arrays into 1D/2D/3D structures; see utils.vh for definitions
    `ARR2D1D(nRPT,ADRW,RAddr_upk       ,RAddr_pck       );
    `ARR2D1D(nWPT,ADRW,WAddr_upk       ,WAddr_pck       );
    `ARR1D2D(nWPT,DATW,WData_pck       ,WData_upk       );
    `ARR1D2D(nRPT,DATW,RData_pck_reg   ,RData_upk_reg   );
    `ARR1D2D(nRPT,DATW,RData_pck_xor   ,RData_upk_xor   );
    `ARR1D2D(nRPT,DATW,RData_pck_lvtreg,RData_upk_lvtreg);
    `ARR1D2D(nRPT,DATW,RData_pck_lvtbin,RData_upk_lvtbin);
    `ARR1D2D(nRPT,DATW,RData_pck_lvt1ht,RData_upk_lvt1ht);
end

  // register write addresses
  reg  [ADRW-1:0] WAddr_r_upk [nWPT-1:0]; // previous (registerd) write addresses - unpacked 2D array 
  always @(posedge clk)
    //WAddr_r_pck <= WAddr_pck;
    for (i=0;i<nWPT;i=i+1) WAddr_r_upk[i] <= WAddr_upk[i];

  // register read addresses
  reg  [ADRW-1:0] RAddr_r_upk [nRPT-1:0]; // previous (registerd) write addresses - unpacked 2D array 
  always @(posedge clk)
    //WAddr_r_pck <= WAddr_pck;
    for (i=0;i<nRPF;i=i+1) RAddr_r_upk[i] <= RAddr_upk[i];

  // generate random write data and random write/read addresses; on falling edge
  reg wdw_addr; // indicates same write addresses on same cycle (Write-During-Write)
  reg waw_addr; // indicates same write addresses on next cycle (Write-After-Write)
  reg rdw_addr; // indicates same read/write addresses on same cycle (Read-During-Write)
  reg raw_addr; // indicates same read address on next cycle (Read-After-Write)
  always @(negedge clk) begin
    // generate random write addresses; different that current and previous write addresses
    for (i=0;i<nWPT;i=i+1) begin
      wdw_addr = 1; waw_addr = 1;
      while (wdw_addr || waw_addr) begin
        `GETRAND(WAddr_upk[i],ADRW);
        wdw_addr = 0; waw_addr = 0;
        if (!WDWB) for (j=0;j<i   ;j=j+1) wdw_addr = wdw_addr || (WAddr_upk[i] == WAddr_upk[j]  );
        if (!WAWB) for (j=0;j<nWPT;j=j+1) waw_addr = waw_addr || (WAddr_upk[i] == WAddr_r_upk[j]);
      end
    end
    // generate random read addresses; different that current and previous write addresses
    for (i=0;i<nRPT;i=i+1) begin
      rdw_addr = 1; raw_addr = 1;
      while (rdw_addr || raw_addr) begin
        `GETRAND(RAddr_upk[i],ADRW);
        rdw_addr = 0; raw_addr = 0;
        if (!RDWB) for (j=0;j<nWPT;j=j+1) rdw_addr = rdw_addr || (RAddr_upk[i] == WAddr_upk[j]  );
        if (!RAWB) for (j=0;j<nWPT;j=j+1) raw_addr = raw_addr || (RAddr_upk[i] == WAddr_r_upk[j]);
      end
    end
    // generate random write data and write enables
    `GETRAND(WData_pck,DATW*nWPT);
    `GETRAND(rdWr      ,1        );
    `GETRAND(WEnb     ,nWPT     );
    if (rdWr) WEnb={nWPF{1'b1}}&WEnb; // if read mode, disable unused write ports
    if (rst ) WEnb={nWPT{1'b0}}     ; // if reset, disable all writes


  end

  integer cycc=1; // cycles count
  integer cycp=0; // cycles percentage
  integer errc=0; // errors count
  integer fail  ;
  integer pass_xor_cur    ; // xor multiported-ram passed in current cycle
  integer pass_lvt_reg_cur; // lvt_reg multiported-ram passed in current cycle
  integer pass_lvt_bin_cur; // lvt_bin multiported-ram passed in current cycle
  integer pass_lvt_1ht_cur; // lvt_1ht multiported-ram passed in current cycle
  integer pass_xor     = 1; // xor multiported-ram passed
  integer pass_lvt_reg = 1; // lvt_reg multiported-ram passed
  integer pass_lvt_bin = 1; // lvt_bin multiported-ram passed
  integer pass_lvt_1ht = 1; // lvt_qht multiported-ram passed

  always @(negedge clk)
    if (!rst) begin
      #(CYCT/10) // a little after falling edge
      if (VERB) begin // write input data
        $write("%-7d:\t",cycc);
        $write("ReadMode:%1d ",rdWr);
        $write("BeforeRise: ");
        $write("WEnb="         ); `ARRPRN(nWPT,WEnb     ); $write("; " );
        $write("WAddr="        ); `ARRPRN(nWPT,WAddr_upk); $write("; " );
        $write("WData="        ); `ARRPRN(nWPT,WData_upk); $write("; " );
        $write("RAddr="        ); `ARRPRN(nRPT,RAddr_upk); $write(" - ");
      end
      #(CYCT/2) // a little after rising edge
      // compare results: in read mode, campare all ports, in normal mode, compare only first nRPF ports
      pass_xor_cur     = rdWr ? (RData_pck_reg===RData_pck_xor   ) : (RData_pck_reg[nRPF*DATW-1:0]===RData_pck_xor[nRPF*DATW-1:0]   );
      pass_lvt_reg_cur = rdWr ? (RData_pck_reg===RData_pck_lvtreg) : (RData_pck_reg[nRPF*DATW-1:0]===RData_pck_lvtreg[nRPF*DATW-1:0]);
      pass_lvt_bin_cur = rdWr ? (RData_pck_reg===RData_pck_lvtbin) : (RData_pck_reg[nRPF*DATW-1:0]===RData_pck_lvtbin[nRPF*DATW-1:0]);
      pass_lvt_1ht_cur = rdWr ? (RData_pck_reg===RData_pck_lvt1ht) : (RData_pck_reg[nRPF*DATW-1:0]===RData_pck_lvt1ht[nRPF*DATW-1:0]);
      pass_xor     = pass_xor     && pass_xor_cur    ;
      pass_lvt_reg = pass_lvt_reg && pass_lvt_reg_cur;
      pass_lvt_bin = pass_lvt_bin && pass_lvt_bin_cur;
      pass_lvt_1ht = pass_lvt_1ht && pass_lvt_1ht_cur;
      fail = !(pass_xor && pass_lvt_reg && pass_lvt_bin && pass_lvt_1ht);
      if (VERB) begin // write outputs
        $write("AfterRise: ");
        $write("RData_reg="    ); `ARRPRN(nRPT,RData_upk_reg   ); $write("; ");
        $write("RData_xor="    ); `ARRPRN(nRPT,RData_upk_xor   ); $write(":%s",pass_xor_cur     ? "pass" : "fail"); $write("; " );
        $write("RData_lvt_reg="); `ARRPRN(nRPT,RData_upk_lvtreg); $write(":%s",pass_lvt_reg_cur ? "pass" : "fail"); $write("; " );
        $write("RData_lvt_bin="); `ARRPRN(nRPT,RData_upk_lvtbin); $write(":%s",pass_lvt_bin_cur ? "pass" : "fail"); $write("; " );
        $write("RData_lvt_1ht="); `ARRPRN(nRPT,RData_upk_lvt1ht); $write(":%s",pass_lvt_1ht_cur ? "pass" : "fail"); $write(";\n");
      end else begin
        if ((100*cycc/CYCC)!=cycp) begin cycp=100*cycc/CYCC; $write("%-3d%%  passed\t(%-7d / %-7d) cycles\n",cycp,cycc,CYCC); end
      end
      if (fail && TERFAIL) begin
        $write("*** Simulation terminated due to a mismatch\n");
        $finish;
      end
      if (cycc==CYCC) begin
        $write("*** Simulation terminated after %0d cycles. Simulation results:\n",CYCC);
        $write("XOR-based          = %s",pass_xor     ? "pass;\n" : "fail;\n");
        $write("Register-based LVT = %s",pass_lvt_reg ? "pass;\n" : "fail;\n");
        $write("Binary I-LVT       = %s",pass_lvt_bin ? "pass;\n" : "fail;\n");
        $write("Onehot I-LVT       = %s",pass_lvt_1ht ? "pass;\n" : "fail;\n");
        // Append report file
        $fwrite(rep_fd,"%-7d  %-5d   %2d-%-2d   %2d-%-2d   %-6s   %-10d   %-9s   %-7s   %-8s   %-08s\n",MEMD,DATW,nWPF,nWPS,nRPF,nRPS,BYPS,CYCC,pass_xor?"pass":"fail",pass_lvt_reg?"pass":"fail",pass_lvt_bin?"pass":"fail",pass_lvt_1ht?"pass":"fail");
        $fclose(rep_fd);
        $finish;
      end
      cycc=cycc+1;
    end

  // instantiate multiported register-based ram as reference for all other implementations
  smpram           #( .MEMD  (MEMD            ),  // memory depth
                      .DATW  (DATW            ),  // data width
                      .nRPF  (nRPF            ),  // number of fixed (simple) read  ports
                      .nWPF  (nWPF            ),  // number of fixed (simple) write ports
                      .nRPS  (nRPS            ),  // number of switched       read  ports
                      .nWPS  (nWPS            ),  // number of switched       write ports
                      .ARCH  ("REG"           ),  // multi-port RAM implementation type
                      .BYPS  (BYPS            ),  // Bypassing type: NON, WAW, RAW, RDW
                      .FILE  ("init_ram"      ))  // initializtion file, optional
  smpram_reg_ref    ( .clk   (clk             ),  // clock
                      .rdWr  (rdWr            ),  // switch read/write (write is active low)
                      .WEnb  (WEnb            ),  // write enable    - packed from nWPF fixed and nWPS switched write ports - in : [            (nWPF+nWPS)-1:0]
                      .WAddr (WAddr_pck       ),  // write addresses - packed from nWPF fixed and nWPS switched write ports - in : [`log2(MEMD)*(nWPF+nWPS)-1:0]
                      .WData (WData_pck       ),  // write data      - packed from nWPF fixed and nWPS switched write ports - in : [DATW       *(nWPF+nWPS)-1:0]
                      .RAddr (RAddr_pck       ),  // read  addresses - packed from nRPF fixed and nRPS switched read  ports - in : [`log2(MEMD)*(nRPF+nRPS)-1:0]
                      .RData (RData_pck_reg   )); // read  data      - packed from nRPF fixed and nRPS switched read  ports - out: [DATW       *(nRPF+nRPS)-1:0]
  // instantiate XOR-based multiported-RAM
  smpram           #( .MEMD  (MEMD            ),  // memory depth
                      .DATW  (DATW            ),  // data width
                      .nRPF  (nRPF            ),  // number of fixed (simple) read  ports
                      .nWPF  (nWPF            ),  // number of fixed (simple) write ports
                      .nRPS  (nRPS            ),  // number of switched       read  ports
                      .nWPS  (nWPS            ),  // number of switched       write ports
                      .ARCH  ("XOR"           ),  // multi-port RAM implementation type
                      .BYPS  (BYPS            ),  // Bypassing type: NON, WAW, RAW, RDW
                      .FILE  ("init_ram"      ))  // initializtion file, optional
  smpram_xor_dut    ( .clk   (clk             ),  // clock
                      .rdWr  (rdWr            ),  // switch read/write (write is active low)
                      .WEnb  (WEnb            ),  // write enable    - packed from nWPF fixed and nWPS switched write ports - in : [            (nWPF+nWPS)-1:0]
                      .WAddr (WAddr_pck       ),  // write addresses - packed from nWPF fixed and nWPS switched write ports - in : [`log2(MEMD)*(nWPF+nWPS)-1:0]
                      .WData (WData_pck       ),  // write data      - packed from nWPF fixed and nWPS switched write ports - in : [DATW       *(nWPF+nWPS)-1:0]
                      .RAddr (RAddr_pck       ),  // read  addresses - packed from nRPF fixed and nRPS switched read  ports - in : [`log2(MEMD)*(nRPF+nRPS)-1:0]
                      .RData (RData_pck_xor   )); // read  data      - packed from nRPF fixed and nRPS switched read  ports - out: [DATW       *(nRPF+nRPS)-1:0]
  // instantiate a multiported-RAM with binary-coded register-based LVT
  smpram           #( .MEMD  (MEMD            ),  // memory depth
                      .DATW  (DATW            ),  // data width
                      .nRPF  (nRPF            ),  // number of fixed (simple) read  ports
                      .nWPF  (nWPF            ),  // number of fixed (simple) write ports
                      .nRPS  (nRPS            ),  // number of switched       read  ports
                      .nWPS  (nWPS            ),  // number of switched       write ports
                      .ARCH  ("LVTREG"        ),  // multi-port RAM implementation type
                      .BYPS  (BYPS            ),  // Bypassing type: NON, WAW, RAW, RDW
                      .FILE  ("init_ram"      ))  // initializtion file, optional
  smpram_lvtreg_dut ( .clk   (clk             ),  // clock
                      .rdWr  (rdWr            ),  // switch read/write (write is active low)
                      .WEnb  (WEnb            ),  // write enable    - packed from nWPF fixed and nWPS switched write ports - in : [            (nWPF+nWPS)-1:0]
                      .WAddr (WAddr_pck       ),  // write addresses - packed from nWPF fixed and nWPS switched write ports - in : [`log2(MEMD)*(nWPF+nWPS)-1:0]
                      .WData (WData_pck       ),  // write data      - packed from nWPF fixed and nWPS switched write ports - in : [DATW       *(nWPF+nWPS)-1:0]
                      .RAddr (RAddr_pck       ),  // read  addresses - packed from nRPF fixed and nRPS switched read  ports - in : [`log2(MEMD)*(nRPF+nRPS)-1:0]
                      .RData (RData_pck_lvtreg)); // read  data      - packed from nRPF fixed and nRPS switched read  ports - out: [DATW       *(nRPF+nRPS)-1:0]
  // instantiate a multiported-RAM with binary-coded SRAM LVT
  smpram           #( .MEMD  (MEMD            ),  // memory depth
                      .DATW  (DATW            ),  // data width
                      .nRPF  (nRPF            ),  // number of fixed (simple) read  ports
                      .nWPF  (nWPF            ),  // number of fixed (simple) write ports
                      .nRPS  (nRPS            ),  // number of switched       read  ports
                      .nWPS  (nWPS            ),  // number of switched       write ports
                      .ARCH  ("LVTBIN"        ),  // multi-port RAM implementation type
                      .BYPS  (BYPS            ),  // Bypassing type: NON, WAW, RAW, RDW
                      .FILE  ("init_ram"      ))  // initializtion file, optional
  smpram_lvtbin_dut ( .clk   (clk             ),  // clock
                      .rdWr  (rdWr            ),  // switch read/write (write is active low)
                      .WEnb  (WEnb            ),  // write enable    - packed from nWPF fixed and nWPS switched write ports - in : [            (nWPF+nWPS)-1:0]
                      .WAddr (WAddr_pck       ),  // write addresses - packed from nWPF fixed and nWPS switched write ports - in : [`log2(MEMD)*(nWPF+nWPS)-1:0]
                      .WData (WData_pck       ),  // write data      - packed from nWPF fixed and nWPS switched write ports - in : [DATW       *(nWPF+nWPS)-1:0]
                      .RAddr (RAddr_pck       ),  // read  addresses - packed from nRPF fixed and nRPS switched read  ports - in : [`log2(MEMD)*(nRPF+nRPS)-1:0]
                      .RData (RData_pck_lvtbin)); // read  data      - packed from nRPF fixed and nRPS switched read  ports - out: [DATW       *(nRPF+nRPS)-1:0]
  // instantiate a multiported-RAM with onehot-coded SRAM LVT
  smpram           #( .MEMD  (MEMD            ),  // memory depth
                      .DATW  (DATW            ),  // data width
                      .nRPF  (nRPF            ),  // number of fixed (simple) read  ports
                      .nWPF  (nWPF            ),  // number of fixed (simple) write ports
                      .nRPS  (nRPS            ),  // number of switched       read  ports
                      .nWPS  (nWPS            ),  // number of switched       write ports
                      .ARCH  ("LVT1HT"        ),  // multi-port RAM implementation type
                      .BYPS  (BYPS            ),  // Bypassing type: NON, WAW, RAW, RDW
                      .FILE  ("init_ram"      ))  // initializtion file, optional
  smpram_lvt1ht_dut ( .clk   (clk             ),  // clock
                      .rdWr  (rdWr            ),  // switch read/write (write is active low)
                      .WEnb  (WEnb            ),  // write enable    - packed from nWPF fixed and nWPS switched write ports - in : [            (nWPF+nWPS)-1:0]
                      .WAddr (WAddr_pck       ),  // write addresses - packed from nWPF fixed and nWPS switched write ports - in : [`log2(MEMD)*(nWPF+nWPS)-1:0]
                      .WData (WData_pck       ),  // write data      - packed from nWPF fixed and nWPS switched write ports - in : [DATW       *(nWPF+nWPS)-1:0]
                      .RAddr (RAddr_pck       ),  // read  addresses - packed from nRPF fixed and nRPS switched read  ports - in : [`log2(MEMD)*(nRPF+nRPS)-1:0]
                      .RData (RData_pck_lvt1ht)); // read  data      - packed from nRPF fixed and nRPS switched read  ports - out: [DATW       *(nRPF+nRPS)-1:0]

endmodule
