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
//                      dpram.v: Generic dual-ported RAM                          //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module dpram
 #(  parameter MEMD = 16, // memory depth
     parameter DATW = 32, // data width
     parameter ZERO = 0 , // binary / Initial RAM with zeros (has priority over FILE)
     parameter FILE = ""  // initialization hex file (don't pass extension), optional
  )( input                    clk    , // clock
     input                    WEnb_A , // write enable for port A
     input                    WEnb_B , // write enable for port B
     input  [`log2(MEMD)-1:0] Addr_A , // address      for port A
     input  [`log2(MEMD)-1:0] Addr_B , // address      for port B
     input  [DATW       -1:0] WData_A, // write data   for port A
     input  [DATW       -1:0] WData_B, // write data   for port B
     output reg [DATW   -1:0] RData_A, // read  data   for port A
     output reg [DATW   -1:0] RData_B  // read  data   for port B
  );

  // initialize RAM, with zeros if ZERO or file if FILE.
  integer i;
  reg [DATW-1:0] mem [0:MEMD-1]; // memory array
  initial
    if (ZERO)
      for (i=0; i<MEMD; i=i+1) mem[i] = {DATW{1'b0}};
    else
      if (FILE != "") $readmemh({FILE,".hex"}, mem);

  // PORT A
  always @(posedge clk) begin
    // write/read; nonblocking statement to read old data
    if (WEnb_A) begin
      mem[Addr_A] <= WData_A; // Change into blocking statement (=) to read new data
      RData_A     <= WData_A; // flow-through
    end else
      RData_A <= mem[Addr_A]; //Change into blocking statement (=) to read new data
  end

  // PORT B
  always @(posedge clk) begin
    // write/read; nonblocking statement to read old data
    if (WEnb_B) begin
      mem[Addr_B] <= WData_B; // Change into blocking statement (=) to read new data
      RData_B     <= WData_B; // flow-through
    end else
      RData_B <= mem[Addr_B]; //Change into blocking statement (=) to read new data
  end

endmodule
