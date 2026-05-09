// 该skill（SPEC2TB_skills）用于：依据用户提供的RTM、DV_SPEC、LRS、HLD、Regmap、DUT_TOP和VIP文件，生成完整的UVM testbench。

// skill依赖项：Python；Claude code官方文档处理skill（document-skills）

// skill执行步骤：
1.在Claude code工作目录下的input_config.json中指定所需文件的位置
2.进入claude code
3.进入plan mode
4.通过/SPEC2TB_skills命令启动skill

// 注意事项：
// 1.提供VIP路径，AI会尝试将VIP集成到TB中，不提供，AI会生成相应agent，但AI生成的agent功能很不完善
// 2.skill在生成TB，并编译通过后，会调试smoke test，如果AI长时间不能调试通过，需打断AI调试，进行人工调试，AI的调试思路可能南辕北辙
