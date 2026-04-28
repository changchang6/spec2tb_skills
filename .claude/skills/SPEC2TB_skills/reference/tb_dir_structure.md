 tbus/
 ├── tb/                           # tb.sv/interface
 │   ├── uvc/                      # tbus only的agent
 │   ├── env/                      # tbus env/env cfg/checker
 │   └── if/                       # interface定义、interface bind
 ├── seq/                          # uvm sequence
 ├── tc/                           # uvm test
 ├── reg/                          # 寄存器模型
 ├── filelist                      # tbus验证相关的filelist(xx_verif.f)
 └── script/                       # 本验证项的脚本(optional)