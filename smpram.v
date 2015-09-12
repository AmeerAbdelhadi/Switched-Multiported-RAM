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
// smpram.v: Switched multiported-RAM: register-based, XOR-based, register-based  //
//           LVT, SRAM-based binary-coded and one-hot-coded I-LVT                 //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

// include config file for synthesis mode
`ifndef SIM
`include "config.vh"
`endif

module smpram

 #(  parameter MEMD = `MEMD, // memory depth
     parameter DATW = `DATW, // data width
     parameter nRPF = `nRPF, // number of fixed (simple) read  ports
     parameter nWPF = `nWPF, // number of fixed (simple) write ports
     parameter nRPS = `nRPS, // number of switched       read  ports
     parameter nWPS = `nWPS, // number of switched       write ports
     parameter ARCH = `ARCH, // architecture: REG, XOR, LVTREG, LVTBIN, LVT1HT, AUTO
     parameter BYPS = `BYPS, // Bypassing type: NON, WAW, RAW, RDW
                             // WAW: Allow Write-After-Write (need to bypass feedback ram)
                             // RAW: new data for Read-after-Write (need to bypass output ram)
                             // RDW: new data for Read-During-Write
     parameter FILE = ""     // initialization file, optional
  )( input                                     clk  ,  // clock
     input                                     rdWr ,  // switch read/write (write is active low)
     input       [            (nWPF+nWPS)-1:0] WEnb ,  // write enables   - packed from nWPF fixed & nWPS switched write ports
     input       [`log2(MEMD)*(nWPF+nWPS)-1:0] WAddr,  // write addresses - packed from nWPF fixed & nWPS switched write ports
     input       [DATW       *(nWPF+nWPS)-1:0] WData,  // write data      - packed from nWPF fixed & nWPS switched write ports
     input       [`log2(MEMD)*(nRPF+nRPS)-1:0] RAddr,  // read  addresses - packed from nRPF fixed & nRPS switched read  ports
     output wire [DATW       *(nRPF+nRPS)-1:0] RData); // read  data      - packed from nRPF fixed & nRPS switched read  ports

  // local parameters
  localparam nWPT  = nWPF+nWPS  ; // total number of write ports
  localparam nRPT  = nRPF+nRPS  ; // total number of read  ports
  localparam ADDRW = `log2(MEMD); // address width

  // Auto calculation of best method when ARCH="AUTO" is selected.
  localparam l2nW     = `log2(nWPT)       ;
  localparam nBitsXOR = DATW*(nWPT-1)     ;
  localparam nBitsBIN = l2nW*(nWPT+nRPT-1);
  localparam nBits1HT = (nWPT-1)*(nRPT+1) ;

  localparam AUTOARCH = (MEMD<=1024                                       ) ? "REG"    :
                      ( (MEMD<=2048                                       ) ? "LVTREG" :
                      ( ((nWPS==0)&(nBitsXOR<nBits1HT)&(nBitsXOR<nBitsBIN)) ? "XOR"    :
                      ( (nBits1HT<=nBitsBIN                               ) ? "LVT1HT" : "LVTBIN" )));

  // if ARCH is not one of known types (REG, XOR, LVTREG, LVTBIN, LVT1HT) choose auto (best) ARCH
  localparam iARCH    = ((ARCH!="REG")&&(ARCH!="XOR")&&(ARCH!="LVTREG")&&(ARCH!="LVTBIN")&&(ARCH!="LVT1HT")) ? AUTOARCH : ARCH;

  // Bypassing indicators
  localparam WAWB =  BYPS!="NON"               ; // allow Write-After-Write (need to bypass feedback ram)
  localparam RAWB = (BYPS=="RAW")||(BYPS=="RDW"); // new data for Read-after-Write (need to bypass output ram)
  localparam RDWB =  BYPS=="RDW"               ; // new data for Read-During-Write


  // generate and instantiate RAM with specific implementation
  generate
    if (nWPT==1) begin
      // instantiate multiread RAM
      mrram            #( .MEMD   (MEMD      ),  // memory depth
                          .DATW  (DATW       ),  // data width
                          .nRP   (nRPT       ),  // number of reading ports
                          .BYPS  (RDWB?2:RAWB),  // bypass? 0:none; 1:single-stage; 2:two-stages
                          .FILE  (FILE       ))  // initialization file, optional
      mrram_ins         ( .clk   (clk        ),  // clock                                        - in
                          .WEnb  (WEnb       ),  // write enable  (1 port)                       - in
                          .WAddr (WAddr      ),  // write address (1 port)                       - in : [`log2(MEMD)    -1:0]
                          .WData (WData      ),  // write data    (1 port)                       - in : [DATW           -1:0]
                          .RAddr (RAddr      ),  // read  addresses - packed from nRP read ports - in : [`log2(MEMD)*nRP-1:0]
                          .RData (RData      )); // read  data      - packed from nRP read ports - out: [DATW       *nRP-1:0]
    end
    else if (iARCH=="REG"   ) begin
      // instantiate multiported register-based RAM
      mpram_reg  #( .MEMD  (MEMD ),  // memory depth
                    .DATW  (DATW ),  // data width
                    .nRP   (nRPT ),  // number of reading ports
                    .nWP   (nWPT ),  // number of writing ports
                    .RDWB  (RDWB ),  // provide new data when Read-During-Write?
                    .FILE  (FILE ))  // initializtion file, optional
      mpram_reg_i ( .clk   (clk  ),  // clock
                    .WEnb  (WEnb ),  // write enables   - packed from nWP write ports - in : [            nWP-1:0            ]
                    .WAddr (WAddr),  // write addresses - packed from nWP write ports - in : [`log2(MEMD)*nWP-1:0]
                    .WData (WData),  // write data      - packed from nWP write ports - in : [DATW       *nWP-1:0]
                    .RAddr (RAddr),  // read  addresses - packed from nRP read  ports - in : [`log2(MEMD)*nRP-1:0]
                    .RData (RData)); // read  data      - packed from nRP read  ports - out: [DATW       *nRP-1:0]
    end
    else if (iARCH=="XOR"   ) begin
      // instantiate XOR-based multiported RAM
      mpram_xor  #( .MEMD  (MEMD ),  // memory depth
                    .DATW  (DATW ),  // data width
                    .nRP   (nRPT ),  // number of reading ports
                    .nWP   (nWPT ),  // number of writing ports
                    .WAWB  (WAWB ), // allow Write-After-Write (need to bypass feedback ram)
                    .RAWB  (RAWB ), // new data for Read-after-Write (need to bypass output ram)
                    .RDWB  (RDWB ), // new data for Read-During-Write
                    .FILE  (FILE ))  // initializtion file, optional
      mpram_xor_i ( .clk   (clk  ),  // clock
                    .WEnb  (WEnb ),  // write enables   - packed from nWp write       - in : [           nWPT-1:0]
                    .WAddr (WAddr),  // write addresses - packed from nWP write ports - in : [`log2(MEMD)*nWP-1:0]
                    .WData (WData),  // write data      - packed from nWP write ports - in : [DATW       *nWP-1:0]
                    .RAddr (RAddr),  // read  addresses - packed from nRP read  ports - in : [`log2(MEMD)*nRP-1:0]
                    .RData (RData)); // read  data      - packed from nRP read  ports - out: [DATW       *nRP-1:0]
    end
    else begin
      // instantiate an LVT-based multiported RAM
      mpram_lvt  #( .MEMD  (MEMD ),  // memory depth
                    .DATW  (DATW ),  // data width
                    .nRPF  (nRPF ),  // number of fixed    read  ports
                    .nWPF  (nWPF ),  // number of fixed    write ports
                    .nRPS  (nRPS ),  // number of switched read  ports
                    .nWPS  (nWPS ),  // number of switched write ports
                    .LVTA  (iARCH),  // LVT architecture type: LVTREG, LVTBIN, LVT1HT
                    .WAWB  (WAWB ),  // allow Write-After-Write (need to bypass feedback ram)
                    .RAWB  (RAWB ),  // new data for Read-after-Write (need to bypass output ram)
                    .RDWB  (RDWB ),  // new data for Read-During-Write
                    .FILE  (FILE ))  // initializtion file, optional
      mpram_lvt_i ( .clk   (clk  ),  // clock
                    .rdWr  (rdWr ),  // switch read/write (write is active low)
                    .WEnb  (WEnb ),  // write enables   - packed from nWPF fixed & nWPS switched write ports - in : [(nWPF+nWPS)-1:0            ]
                    .WAddr (WAddr),  // write addresses - packed from nWPF fixed & nWPS switched write ports - in : [`log2(MEMD)*(nWPF+nWPS)-1:0]
                    .WData (WData),  // write data      - packed from nWPF fixed & nWPS switched write ports - in : [DATW       *(nWPF+nWPS)-1:0]
                    .RAddr (RAddr),  // read  addresses - packed from nRPF fixed & nRPS switched write ports - in : [`log2(MEMD)*(nRPF+nRPS)-1:0]
                    .RData (RData)); // read  data      - packed from nRPF fixed & nRPS switched write ports - out: [DATW       *(nRPF+nRPS)-1:0]
    end
  endgenerate

endmodule

