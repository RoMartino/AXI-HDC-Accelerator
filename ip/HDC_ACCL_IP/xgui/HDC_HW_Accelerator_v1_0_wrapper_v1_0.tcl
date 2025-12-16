# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "COUNTER_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S00_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S00_AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PERFORMANCE_COUNTER" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SIMD" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SPM_NUM" -parent ${Page_0}


}

proc update_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to update ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to validate ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.COUNTER_BITS { PARAM_VALUE.COUNTER_BITS } {
	# Procedure called to update COUNTER_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.COUNTER_BITS { PARAM_VALUE.COUNTER_BITS } {
	# Procedure called to validate COUNTER_BITS
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S00_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S00_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to update C_S00_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S00_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.PERFORMANCE_COUNTER { PARAM_VALUE.PERFORMANCE_COUNTER } {
	# Procedure called to update PERFORMANCE_COUNTER when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PERFORMANCE_COUNTER { PARAM_VALUE.PERFORMANCE_COUNTER } {
	# Procedure called to validate PERFORMANCE_COUNTER
	return true
}

proc update_PARAM_VALUE.SIMD { PARAM_VALUE.SIMD } {
	# Procedure called to update SIMD when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SIMD { PARAM_VALUE.SIMD } {
	# Procedure called to validate SIMD
	return true
}

proc update_PARAM_VALUE.SPM_NUM { PARAM_VALUE.SPM_NUM } {
	# Procedure called to update SPM_NUM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SPM_NUM { PARAM_VALUE.SPM_NUM } {
	# Procedure called to validate SPM_NUM
	return true
}


proc update_MODELPARAM_VALUE.SPM_NUM { MODELPARAM_VALUE.SPM_NUM PARAM_VALUE.SPM_NUM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SPM_NUM}] ${MODELPARAM_VALUE.SPM_NUM}
}

proc update_MODELPARAM_VALUE.ADDR_WIDTH { MODELPARAM_VALUE.ADDR_WIDTH PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ADDR_WIDTH}] ${MODELPARAM_VALUE.ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.SIMD { MODELPARAM_VALUE.SIMD PARAM_VALUE.SIMD } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SIMD}] ${MODELPARAM_VALUE.SIMD}
}

proc update_MODELPARAM_VALUE.COUNTER_BITS { MODELPARAM_VALUE.COUNTER_BITS PARAM_VALUE.COUNTER_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.COUNTER_BITS}] ${MODELPARAM_VALUE.COUNTER_BITS}
}

proc update_MODELPARAM_VALUE.PERFORMANCE_COUNTER { MODELPARAM_VALUE.PERFORMANCE_COUNTER PARAM_VALUE.PERFORMANCE_COUNTER } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PERFORMANCE_COUNTER}] ${MODELPARAM_VALUE.PERFORMANCE_COUNTER}
}

proc update_MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH}
}

