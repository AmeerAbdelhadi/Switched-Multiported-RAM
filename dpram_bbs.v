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
//  dpram_bbs.v: Generic dual-ported RAM with optional 1-stage or 2-stage bypass  //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module dpram_bbs
 #(  parameter MEMD = 16, // memory depth
     parameter DATW = 32, // data width
     parameter BYPS = 1 , // bypass? 0:none; 1: single-stage; 2: two-stage
     parameter ZERO = 0 , // binary / Initial RAM with zeros (has priority over FILE)
     parameter FILE = ""  // initialization hex file (don't pass extension), optional
  )( input                    clk    , // clock
     input                    WEnb_A , // write enable for port A
     input                    WEnb_B , // write enable for port B
     input  [`log2(MEMD)-1:0] Addr_A , // write addresses - packed from nWP write ports
     input  [`log2(MEMD)-1:0] Addr_B , // write addresses - packed from nWP write ports
     input  [DATW       -1:0] WData_A, // write data      - packed from nRP read ports
     input  [DATW       -1:0] WData_B, // write data      - packed from nRP read ports
     output reg [DATW   -1:0] RData_A, // read  data      - packed from nRP read ports
     output reg [DATW   -1:0] RData_B  // read  data      - packed from nRP read ports
  );

  wire [DATW-1:0] RData_Ai;     // read ram data (internal) / port A
  wire [DATW-1:0] RData_Bi;     // read ram data (internal) - port B
  dpram #( .MEMD   (MEMD    ),  // memory depth
           .DATW   (DATW    ),  // data width
           .ZERO   (ZERO    ),  // binary / Initial RAM with zeros (has priority over INITFILE)
           .FILE   (FILE    ))  // initializtion file, optional
  dprami ( .clk    (clk     ),  // clock
           .WEnb_A (WEnb_A  ),  // write enable  / port A - in
           .WEnb_B (WEnb_B  ),  // write enable  / port B - in
           .Addr_A (Addr_A  ),  // write address / port A - in [`log2(MEMD)-1:0]
           .Addr_B (Addr_B  ),  // write address / port B - in [`log2(MEMD)-1:0]
           .WData_A(WData_A ),  // write data    / port A - in [DATW  -1:0]
           .WData_B(WData_B ),  // write data    / port B - in [DATW  -1:0]
           .RData_A(RData_Ai),  // read  data    / port A - in [DATW  -1:0]
           .RData_B(RData_Bi)); // read  data    / port B - in [DATW  -1:0]

  // registers; will be removed if unused
  reg WEnb_Ar;
  reg WEnb_Br;
  reg [`log2(MEMD)-1:0] Addr_Ar;
  reg [`log2(MEMD)-1:0] Addr_Br;
  reg [DATW-1:0] WData_Br;
  reg [DATW-1:0] WData_Ar;
  always @(posedge clk) begin
    WEnb_Ar  <= WEnb_A ;
    WEnb_Br  <= WEnb_B ;
    Addr_Ar  <= Addr_A;
    Addr_Br  <= Addr_B;
    WData_Ar <= WData_A; // bypass register
    WData_Br <= WData_B; // bypass register
  end
  
  // bypass: single-staeg, two-stage (logic will be removed if unused)
  wire bypsA1,bypsA2,bypsB1,bypsB2;
  assign bypsA1 = (BYPS >= 1) && WEnb_Br && !WEnb_Ar && (Addr_Br == Addr_Ar);
  assign bypsA2 = (BYPS == 2) && WEnb_B  && !WEnb_Ar && (Addr_B  == Addr_Ar);
  assign bypsB1 = (BYPS >= 1) && WEnb_Ar && !WEnb_Br && (Addr_Ar == Addr_Br);
  assign bypsB2 = (BYPS == 2) && WEnb_A  && !WEnb_Br && (Addr_A  == Addr_Br);

  // output mux (mux or mux inputs will be removed if unused)
  always @*
    if (bypsA2)      RData_A = WData_B ;
    else if (bypsA1) RData_A = WData_Br;
         else        RData_A = RData_Ai;

  always @*
    if (bypsB2)      RData_B = WData_A ;
    else if (bypsB1) RData_B = WData_Ar;
         else        RData_B = RData_Bi;

endmodule
