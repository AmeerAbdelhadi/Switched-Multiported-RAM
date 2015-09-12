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
//              mpram_reg.v: generic register-based multiported-RAM.              //
//   Reading addresses are registered and old data will be read in case of RAW.   //
//   Implemented in FF's if the number of reading or writing ports exceeds one.   //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module mpram_reg
 #(  parameter MEMD = 16, // memory depth
     parameter DATW = 32, // data width
     parameter nRP  = 3 , // number of reading ports
     parameter nWP  = 2 , // number of writing ports
     parameter RDWB = 0 , // provide new data when Read-During-Write?
     parameter ZERO = 0 , // binary / Initial RAM with zeros (has priority over INITFILE)
     parameter FILE = ""  // initialization hex file (don't pass extension), optional
  )( input                            clk  , // clock
     input      [nWP-1:0            ] WEnb , // write enable for each writing port
     input      [`log2(MEMD)*nWP-1:0] WAddr, // write addresses - packed from nWP write ports
     input      [DATW       *nWP-1:0] WData, // write data      - packed from nRP read ports
     input      [`log2(MEMD)*nRP-1:0] RAddr, // read  addresses - packed from nRP  read  ports
     output reg [DATW       *nRP-1:0] RData  // read  data      - packed from nRP read ports
  );

  localparam ADRW = `log2(MEMD); // address width
  integer i;

  // initialize RAM, with zeros if ZERO or file if IFLE.
  (* ramstyle = "logic" *) reg [DATW-1:0] mem [0:MEMD-1]; // memory array; implemented with logic cells (registers)
  initial
    if (ZERO)
      for (i=0; i<MEMD; i=i+1) mem[i] = {DATW{1'b0}};
    else
      if (FILE != "") $readmemh({FILE,".hex"}, mem);

  always @(posedge clk) begin
      // write to nWP ports; nonblocking statement to read old data
      for (i=1; i<=nWP; i=i+1)
        if (WEnb[i-1]) 
          if (RDWB) mem[WAddr[i*ADRW-1 -: ADRW]]  = WData[i*DATW-1 -: DATW]; //     blocking statement (= ) to read new data
          else      mem[WAddr[i*ADRW-1 -: ADRW]] <= WData[i*DATW-1 -: DATW]; // non-blocking statement (<=) to read old data 
      // Read from nRP ports; nonblocking statement to read old data
      for (i=1; i<=nRP; i=i+1)
        if (RDWB) RData[i*DATW-1 -: DATW]  = mem[RAddr[i*ADRW-1 -: ADRW]]; //    blocking statement (= ) to read new data
        else      RData[i*DATW-1 -: DATW] <= mem[RAddr[i*ADRW-1 -: ADRW]]; //non-blocking statement (<=) to read old data
    end
endmodule
