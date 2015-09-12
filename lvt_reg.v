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
//         lvt_reg.v:  Register-based binary-coded LVT (Live-Value-Table)         //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module lvt_reg
 #(  parameter MEMD = 16, // memory depth
     parameter nRP  = 2 , // number of reading ports
     parameter nWP  = 2 , // number of writing ports
     parameter RDWB = 0 , // new data for Read-During-Write
     parameter ZERO = 0 , // binary / Initial RAM with zeros (has priority over FILE)
     parameter FILE = ""  // initialization file, optional
  )( input                        clk  ,  // clock
     input  [            nWP-1:0] WEnb ,  // write enable for each writing port
     input  [`log2(MEMD)*nWP-1:0] WAddr,  // write addresses    - packed from nWP write ports
     input  [`log2(MEMD)*nRP-1:0] RAddr,  // read  addresses    - packed from nRP read  ports
     output [`log2(nWP )*nRP-1:0] RBank); // read bank selector - packed from nRP read  ports

  localparam ADRW = `log2(MEMD); // address width
  localparam LVTW = `log2(nWP ); // required memory width

  // Generate Bank ID's to write into LVT
  reg  [LVTW*nWP-1:0] WData1D          ; 
  wire [LVTW    -1:0] WData2D [nWP-1:0];
  genvar gi;
  generate
    for (gi=0;gi<nWP;gi=gi+1) begin: GenerateID
      assign  WData2D[gi]=gi;
    end
  endgenerate

  // packing/unpacking arrays into 1D/2D/3D structures; see utils.vh for definitions
  // pack ID's into 1D array
  `ARRINIT;
  always @* `ARR2D1D(nWP,LVTW,WData2D,WData1D);

  mpram_reg    #( .MEMD  (MEMD   ),  // memory depth
                  .DATW  (LVTW   ),  // data width
                  .nRP   (nRP    ),  // number of reading ports
                  .nWP   (nWP    ),  // number of writing ports
                  .RDWB  (RDWB   ),  // provide new data when Read-During-Write?
                  .ZERO  (ZERO   ),  // binary / Initial RAM with zeros (has priority over FILE)
                  .FILE  (FILE   ))  // initialization file, optional
  mpram_reg_ins ( .clk   (clk    ),  // clock                                         - in
                  .WEnb  (WEnb   ),  // write enable for each writing port            - in : [     nWP-1:0]
                  .WAddr (WAddr  ),  // write addresses - packed from nWP write ports - in : [ADRW*nWP-1:0]
                  .WData (WData1D),  // write data      - packed from nRP read  ports - in : [LVTW*nWP-1:0]
                  .RAddr (RAddr  ),  // read  addresses - packed from nRP read  ports - in : [ADRW*nRP-1:0]
                  .RData (RBank  )); // read  data      - packed from nRP read  ports - out: [LVTW*nRP-1:0]

endmodule
