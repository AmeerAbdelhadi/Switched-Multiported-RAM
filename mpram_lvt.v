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
// mpram_lvt.v: LVT-based Multiported-RAM for register-base and SRAM-based        //
//              one-hot/binary-coded I-LVT                                        //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module mpram_lvt
 #(  parameter MEMD = 16, // memory depth
     parameter DATW = 32, // data width
     parameter nRPF = 2 , // number of fixed    read  ports
     parameter nWPF = 2 , // number of fixed    write ports
     parameter nRPS = 2 , // number of switched read  ports
     parameter nWPS = 2 , // number of switched write ports
     parameter LVTA = "", // LVT architecture type: LVTREG, LVTBIN, LVT1HT
     parameter WAWB = 1 , // allow Write-After-Write (need to bypass feedback ram)
     parameter RAWB = 1 , // new data for Read-after-Write (need to bypass output ram)
     parameter RDWB = 0 , // new data for Read-During-Write
     parameter FILE = ""  // initialization file, optional
  )( input                                    clk  ,  // clock
     input                                    rdWr ,  // switch read/write (write is active low)
     input      [            (nWPF+nWPS)-1:0] WEnb ,  // write enablea   - packed from nWPF fixed & nWPS switched write ports
     input      [`log2(MEMD)*(nWPF+nWPS)-1:0] WAddr,  // write addresses - packed from nWPF fixed & nWPS switched write ports
     input      [DATW       *(nWPF+nWPS)-1:0] WData,  // write data      - packed from nWPF fixed & nWPS switched write ports
     input      [`log2(MEMD)*(nRPF+nRPS)-1:0] RAddr,  // read  addresses - packed from nRPF fixed & nRPS switched read  ports
     output reg [DATW       *(nRPF+nRPS)-1:0] RData); // read  data      - packed from nRPF fixed & nRPS switched read  ports

  // local parameters
  localparam nWPT = nWPF+nWPS                 ; // total number of write ports
  localparam nRPT = nRPF+nRPS                 ; // total number of read  ports
  localparam ADRW = `log2(MEMD)               ; // address width
  localparam LVTW = `log2(nWPT)               ; // LVT     width
  localparam SELW = (LVTA=="LVT1HT")?nWPT:LVTW; // data bank selector width 

  // unpacked/pack addresses/data
  reg  [ADRW     -1:0] WAddr2D  [nWPT-1:0]          ; // write addresses      / 2D
  reg  [DATW     -1:0] WData2D  [nWPT-1:0]          ; // write data           / 2D 
  wire [DATW*nRPT-1:0] RData2Di [nWPT-1:0]          ; // read data / internal / 2D
  reg  [DATW     -1:0] RData3Di [nWPT-1:0][nRPT-1:0]; // read data / internal / 3D
  wire [DATW     -1:0] RData2D  [nRPT-1:0]          ; // read data / output   / 2D
  wire [SELW*nRPT-1:0] RBank                        ; // read bank selector   / 1D
  reg  [SELW     -1:0] RBank2D  [nRPT-1:0]          ; // read bank selector   / 2D

  `ARRINIT;
  always @* begin
    // packing/unpacking arrays into 1D/2D/3D structures; see utils.vh for definitions
    `ARR1D2D(nWPT,     ADRW,WAddr   ,WAddr2D );
    `ARR1D2D(nWPT,     DATW,WData   ,WData2D );
    `ARR2D3D(nWPT,nRPT,DATW,RData2Di,RData3Di);
    `ARR2D1D(nRPT,     DATW,RData2D ,RData   );
    `ARR1D2D(nRPT,     SELW,RBank   ,RBank2D );
  end

  // generate and instantiate LVT with specific implementation
  generate
    if (LVTA=="LVTREG") begin
      // instantiate LVT / REG type
      lvt_reg  #( .MEMD  (MEMD    ),  // memory depth
                  .nRP   (nRPT    ),  // number of reading ports
                  .nWP   (nWPT    ),  // number of writing ports
                  .RDWB  (RDWB    ),  // new data for Read-During-Write
                  .ZERO  (FILE!=""),  // binary / Initial RAM with zeros (has priority over FILE)
                  .FILE  (""      ))  // initialization file, optional
      lvt_reg_i ( .clk   (clk     ),  // clock                                              - in
                  .WEnb  (WEnb    ),  // write enable for each writing port                 - in : [     nWPT-1:0]
                  .WAddr (WAddr   ),  // write addresses    - packed from nWPT write ports  - in : [ADRW*nWPT-1:0]
                  .RAddr (RAddr   ),  // read  addresses    - packed from nRPT  read  ports - in : [ADRW*nRPT-1:0]
                  .RBank (RBank   )); // read bank selector - packed from nRPT read ports   - out: [LVTW*nRPT-1:0]
    end
    else if (LVTA=="LVTBIN") begin
      // instantiate LVT / BIN type
      lvt_bin  #( .MEMD  (MEMD    ),  // memory depth
                  .nRP   (nRPT    ),  // number of reading ports
                  .nWP   (nWPT    ),  // number of writing ports
                  .WAWB  (WAWB    ),  // allow Write-After-Write (need to bypass feedback ram)
                  .RAWB  (RAWB    ),  // new data for Read-after-Write (need to bypass output ram)
                  .RDWB  (RDWB    ),  // new data for Read-During-Write
                  .ZERO  (FILE!=""),  // binary / Initial RAM with zeros (has priority over FILE)
                  .FILE  (""      ))  // initialization file, optional
      lvt_bin_i ( .clk   (clk     ),  // clock                                              - in
                  .WEnb  (WEnb    ),  // write enable for each writing port                 - in : [     nWPT-1:0]
                  .WAddr (WAddr   ),  // write addresses    - packed from nWPT write ports  - in : [ADRW*nWPT-1:0]
                  .RAddr (RAddr   ),  // read  addresses    - packed from nRPT  read  ports - in : [ADRW*nRPT-1:0]
                  .RBank (RBank   )); // read bank selector - packed from nRPT read ports   - out: [LVTW*nRPT-1:0]
    end
    else begin
      // instantiate LVT / 1HT TYPE
      lvt_1ht  #( .MEMD  (MEMD    ),  // memory depth
                  .nRP   (nRPT    ),  // number of reading ports
                  .nWP   (nWPT    ),  // number of writing ports
                  .WAWB  (WAWB    ),  // allow Write-After-Write (need to bypass feedback ram)
                  .RAWB  (RAWB    ),  // new data for Read-after-Write (need to bypass output ram)
                  .RDWB  (RDWB    ),  // new data for Read-During-Write
                  .ZERO  (FILE!=""),  // binary / Initial RAM with zeros (has priority over FILE)
                  .FILE  (""      ))  // initialization file, optional
      lvt_1ht_i ( .clk   (clk     ),  // clock                                              - in
                  .WEnb  (WEnb    ),  // write enable for each writing port                 - in : [     nWPT-1:0]
                  .WAddr (WAddr   ),  // write addresses    - packed from nWPT write ports  - in : [ADRW*nWPT-1:0]
                  .RAddr (RAddr   ),  // read  addresses    - packed from nRPT  read  ports - in : [ADRW*nRPT-1:0]
                  .RBank (RBank   )); // 1hot bank selector - packed from nRPT read ports   - out: [nWPT*nRPT-1:0]
    end

  endgenerate

  // generate and instantiate mulriread RAM blocks
  genvar wpi,rpi;
  generate
    for (wpi=0 ; wpi<nWPT ; wpi=wpi+1) begin: RPORTwpi
      if (wpi<nWPF)
        // noraml multi-read ram instantiation
        mrram      #( .MEMD  (MEMD         ),  // memory depth
                      .DATW  (DATW         ),  // data width
                      .nRP   (nRPT         ),  // number of reading ports
                      .BYPS  (RDWB         ),  // bypass? 0:none; 1:single-stage; 2:two-stages
                      .ZERO  (0            ),  // binary / Initial RAM with zeros (has priority over FILE)
                      .FILE  (wpi?"":FILE  ))  // initialization file, optional
        mrram_i     ( .clk   (clk          ),  // clock                                         - in
                      .WEnb  (WEnb[wpi]    ),  // write enable  (1 port)                        - in
                      .WAddr (WAddr2D[wpi] ),  // write address (1 port)                        - in : [ADRW     -1:0]
                      .WData (WData2D[wpi] ),  // write data (1 port)                           - in : [DATW     -1:0]
                      .RAddr (RAddr        ),  // read  addresses - packed from nRPT read ports - in : [ADRW*nRPT-1:0]
                      .RData (RData2Di[wpi])); // read  data      - packed from nRPT read ports - out: [DATW*nRPT-1:0]
      else
        // switched multi-read ram instantiation
        mrram_swt  #( .MEMD  (MEMD         ),  // memory depth
                      .DATW  (DATW         ),  // data width
                      .nRPF  (nRPF         ),  // number of fixed    read ports
                      .nRPS  (nRPS         ),  // number of switched read ports
                      .BYPS  (RDWB         ),  // bypass? 0:none; 1:single-stage; 2:two-stages
                      .ZERO  (0            ),  // binary / Initial RAM with zeros (has priority over FILE)
                      .FILE  (wpi?"":FILE  ))  // initialization file, optional
        mrram_swt_i ( .clk   (clk          ),  // clock                                                               - in
                      .rdWr  (rdWr         ),  // switch read/write (write is active low)                             - in
                      .WEnb  (WEnb[wpi]    ),  // write enable  (1 port)                                              - in
                      .WAddr (WAddr2D[wpi] ),  // write address (1 port)                                              - in : [ADRW            -1:0]
                      .WData (WData2D[wpi] ),  // write data    (1 port)                                              - in : [DATW            -1:0]
                      .RAddr (RAddr        ),  // read  addresses - packed from nRPF fixed & nRPS switched read ports - in : [ADRW*(nRPF+nRPS)-1:0]
                      .RData (RData2Di[wpi])); // read  data      - packed from nRPF fixed & nRPS switched read ports - out: [DATW*(nRPF+nRPS)-1:0]
    end

    // infer tri-state buffers and connect busses for LVT1HT and muxes for LVTREG/LVTBIN
    for (rpi=0 ; rpi<nRPT ; rpi=rpi+1) begin: PORTrpi
      if (LVTA=="LVT1HT") begin
        // tri-state buffers and busses connection
        for (wpi=0 ; wpi<nWPT ; wpi=wpi+1) begin: PORTwpi
          assign RData2D[rpi] = RBank2D[rpi][wpi] ? RData3Di[wpi][rpi] : {DATW{1'bz}};
        end
      end
      else begin
        // combinatorial logic for output muxes
        assign RData2D[rpi] = RData3Di[RBank2D[rpi]][rpi];
      end
    end

  endgenerate

endmodule
