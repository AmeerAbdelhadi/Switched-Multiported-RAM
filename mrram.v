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
// mrram.v: Multiread-RAM based on bank replication using generic dual-ported RAM //
//          with optional single-stage or two-stage bypass/ for normal mode ports //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module mrram
 #(  parameter MEMD = 16, // memory depth
     parameter DATW = 32, // data width
     parameter nRP  = 3 , // number of reading ports
     parameter BYPS = 1 , // bypass? 0:none; 1: single-stage; 2:two-stages
     parameter ZERO = 0 , // binary / Initial RAM with zeros (has priority over FILE)
     parameter FILE = ""  // initialization mif file (don't pass extension), optional
  )( input                            clk  ,  // clock
     input                            WEnb ,  // write enable  (1 port)
     input      [`log2(MEMD)    -1:0] WAddr,  // write address (1 port)
     input      [DATW           -1:0] WData,  // write data    (1 port)
     input      [`log2(MEMD)*nRP-1:0] RAddr,  // read  addresses - packed from nRP read  ports
     output reg [DATW       *nRP-1:0] RData); // read  data      - packed from nRP read ports

  localparam ADRW = `log2(MEMD); // address width

  // unpacked read addresses/data
  reg  [ADRW-1:0] RAddr_upk [nRP-1:0]; // read addresses - unpacked 2D array 
  wire [DATW-1:0] RData_upk [nRP-1:0]; // read data      - unpacked 2D array 

  // unpack read addresses; pack read data
  `ARRINIT;
  always @* begin
    // packing/unpacking arrays into 1D/2D/3D structures; see utils.vh for definitions
    `ARR1D2D(nRP,ADRW,RAddr,RAddr_upk);
    `ARR2D1D(nRP,DATW,RData_upk,RData);
  end

  // generate and instantiate generic RAM blocks
  genvar rpi;
  generate
    for (rpi=0 ; rpi<nRP ; rpi=rpi+1) begin: RPORTrpi
      // generic dual-ported ram instantiation
      dpram_bbs #( .MEMD    (MEMD          ),  // memory depth
                   .DATW    (DATW          ),  // data width
                   .BYPS    (BYPS          ),  // bypass? 0: none; 1: single-stage; 2:two-stages
                   .ZERO    (ZERO          ),  // binary / Initial RAM with zeros (has priority over INITFILE)
                   .FILE    (FILE          ))  // initialization file, optional
      dpram_bbsi ( .clk     (clk           ),  // clock         - in
                   .WEnb_A  (1'b0          ),  // write enable  - in
                   .WEnb_B  (WEnb          ),  // write enable  - in
                   .Addr_A  (RAddr_upk[rpi]),  // write address - in : [`log2(MEMD)-1:0]
                   .Addr_B  (WAddr         ),  // write address - in : [`log2(MEMD)-1:0]
                   .WData_A ({DATW{1'b1}}  ),  // write data    - in : [DATW       -1:0] / constant
                   .WData_B (WData         ),  // write data    - in : [DATW       -1:0]
                   .RData_A (RData_upk[rpi]),  // read  data    - out: [DATW       -1:0]
                   .RData_B (              )); // read  data    - out: [DATW       -1:0]
    end
  endgenerate

endmodule
