#!/bin/bash 

# defaults
TOOL="vcf"
DUT="zeroriscy"
ISA="riscv"
CONFIG=""
BUG="none"
TEST_DIR=""
TIME_LIMIT="168h"
GUI=0
DRY_RUN=0
PROP_SETUP_FILE=""
declare -a OPTIONS
declare -a EXTRA_DEFINES
SIS=0
REGRESS=0
DUP_SYNC=1
# memory region enables is a bit mask, i.e., one bit per memory region
MEM_REGION_ENABLES=1
FV_COV=0
INIT_CONFIG=""

declare -a PROPERTIES
declare -a PROP_DEFINES
declare -a PROP_TCL

while getopts ":hngt:d:c:b:l:p:so:rm:vi:" option; do 
    case "${option}" in 
	h) echo "Usage: run [-h] [-t <tool>] [-d <dut>] -p <property> [-c <config>] [-o <options>] [-m <mem_region_enables>] [-b <bug#>] [-s] [-v] [-l <timeout>] [-g] [-n] [-e] [-r] [-i <init_config>]"
	   echo "    <tool>     options: vcf, jg (default is vcf and can be changed at the top of this script)"
	   echo "    <dut>      e.g.: zeroriscy (default can be changed at the top of this script)"
	   echo "    <property> options: dup, cf, cmt, all, si (can be repeated to add multiple properties; all means dup+cf+cmt; si should be done alone)"
	   echo "    <config>   includes a <dut>_<config>_config.vh file in the verilog file list; default is defined per DUT in this script"
	   echo "    <options>  more preset options that set certain defines (can be repeated to add multiple options)"
	   echo "    <mem_region_enables> a number (could be binary using Verilog syntax in \"\") that is a bit mask, i.e., one bit per memory region (default is 1)"
	   echo "    <bug#>     none (for no bug which is the default), or"
	   echo "               #    (a number for activing FV_<dut>_BUG_# define), or"
	   echo "               all  (for regressing through all bugs for <dut>)"
	   echo "    -s for register file with symbolic initial state with VC Formal (default for 'si' property, otherwise default is init all to 0s)"
	   echo "    -v for automatically checking the 'FV_Cover' properties"
	   echo "    <timeout>  Xm/h; m for minutes or h for hours; default is ${TIME_LIMIT}"
	   echo "    -g for running with GUI (Verdi for VC Formal); good for debugging not regressions"
	   echo "    -r sets the regression variable in the TCL file even if bug# is not 'all'; prefixes the run directory with reg_"
	   echo "    -i <init_config> reads the init_<init_config>.fsdb file for initializing the DUT from that snapshot"
	   echo "    -n for dry run (just checks settings)"
	   exit 0;;
	t) TOOL=${OPTARG};; 
	d) DUT=${OPTARG};; 
	p) PROPERTY=${OPTARG}
	   PROPERTIES+=(${OPTARG})
	   ;; 
	c) CONFIG=${OPTARG};; 
	o) OPTIONS+=(${OPTARG});;
	m) MEM_REGION_ENABLES=${OPTARG};;
	b) BUG=${OPTARG};;
	s) SIS=1;;
	v) FV_COV=1;;
	n) DRY_RUN=1;; 
	g) GUI=1;;
	r) REGRESS=1;;
	i) INIT_CONFIG=${OPTARG};;
	l) TIME_LIMIT=${OPTARG};;
	
	\?) echo "Invalid option: -$OPTARG" 1>&2
	   exit 1;;
	:) echo "Invalid option: $OPTARG requires an argument" 1>&2
	   exit 1;;
    esac 
done 

EXTRA_DEFINES=("FV_ENCRYPTED")

# ==========
# check properties

if ((${#PROPERTIES[@]} == 0))
then
    echo "ERROR: No property was selected with; use -p <property> (can be repeated for multiple properties)."
    exit 1
fi

for PROP in ${PROPERTIES[@]}; do
    case $PROP in
	dup) PROP_DEFINES+=("FV_ENABLE_DUP")
	      PROP_TCL+=("set dup 1" "set exq 1")
	      ;;
	cf) PROP_DEFINES+=("FV_ENABLE_CF")
	       PROP_TCL+=("set cf 1" "set exq 1")
	       ;;
	cmt) PROP_DEFINES+=("FV_ENABLE_CMT")
	       PROP_TCL+=("set cmt 1")
	       ;;
	all) PROP_DEFINES+=("FV_ENABLE_DUP" "FV_ENABLE_CF" "FV_ENABLE_CMT")
	     PROP_TCL+=("set dup 1" "set cf 1" "set cmt 1" "set exq 1")
	     ;;
	si) PROP_DEFINES+=("FV_ENABLE_SI")
	    PROP_TCL+=("set sifv 1" "set cf 1" "set exq 1")
	    PROP_SETUP_FILE="si_"
	    ;;
    
	*) echo "ERROR: Unrecognized or not-yet-implemented property $PROP"
	   exit 1;;
    esac
done

# ==========
# check tool
case $TOOL in
    vcf) SETUP_FILE="fv_${PROP_SETUP_FILE}setup.tcl"
	 TOOL_CMD="vcf -mode64 -f ../vcf/${SETUP_FILE}"
	 if (($GUI == 1))
	 then
	     TOOL_CMD="${TOOL_CMD} -verdi"
	 else
	     TOOL_CMD="${TOOL_CMD} -batch"
	 fi
	 REPORT_DET_PHRASE="falsified"
	 ;;

    jg) SETUP_FILE="fv_${PROP_SETUP_FILE}setup.tcl"
	TOOL_CMD="jg  -allow_unsupported_OS -fpv ../jg/${SETUP_FILE}"
	if (($GUI == 0))
	then
	    TOOL_CMD="${TOOL_CMD} -batch"
	fi
	REPORT_DET_PHRASE="cex"
	;;

    *) echo "ERROR: Unrecognized tool $TOOL"
       exit 1;;
esac

# ==========
# check DUT
case $DUT in
    zeroriscy) DUT_RTL_DIR="../duts/zeroriscy/rtl/"
	       DUT_BUG_PREFIX="FV_ZERORISCY_BUG_"
	       ISA="riscv"
	       if [ "$PROPERTY" == "si" ]; then
		   DUT_MAX_BUGS=11
	       else
		   DUT_MAX_BUGS=6
	       fi
	       if [ "$CONFIG" == "" ]; then
		   CONFIG="full"
	       fi
	       ;;
    *) echo "ERROR: Unrecognized DUT $DUT"
       exit 1;;
esac

# ==========
# check config file
CONFIG_FILE="configs/${DUT}_${CONFIG}_config.vh"
if [ ! -f ${CONFIG_FILE} ]; then
    echo "ERROR: File ${CONFIG_FILE} not found!"
    exit 1
fi
   
if [ "$INIT_CONFIG" != "" ]; then
    # ==========
    # check init file
    INIT_FILE="init_files/${DUT}/init_${INIT_CONFIG}.fsdb"
    if [ ! -f ${INIT_FILE} ]; then
	echo "ERROR: Init file ${INIT_FILE} not found!"
	exit 1
    fi
fi

# ==========
# options

# default options variables that require setting to be default
DISABLE_DCACHE=1
DISABLE_MMU=1

for OPT in ${OPTIONS[@]}; do
    case $OPT in
	inc_if)  EXTRA_DEFINES+=("FV_INCLUDE_IF_STAGE");;
	jal_rd)  EXTRA_DEFINES+=("FV_JAL_RD_OR");;
	imem128) EXTRA_DEFINES+=("FV_IMEM_WIDTH_128");;
	inc_rvc) EXTRA_DEFINES+=("FV_INCLUDE_RVC");;
	inc_rva) EXTRA_DEFINES+=("FV_INCLUDE_RVA")
		 PROP_TCL+=("set inc_rva 1")
		 ;;
	inc_rvf) EXTRA_DEFINES+=("FV_INCLUDE_RVF")
		 PROP_TCL+=("set inc_rvf 1")
		 ;;
	inc_csr) EXTRA_DEFINES+=("FV_INCLUDE_RVZICSR");;
	en_dcache) DISABLE_DCACHE=0;;
	en_mmu) DISABLE_MMU=0;;
	*) echo "ERROR: Unrecognized or not-yet-implemented option $OPTIONS"
	   exit 1;;
    esac
done

if [ "$INIT_CONFIG" != "" ]; then
    EXTRA_DEFINES+=("FV_INIT_FROM_FILE")
else
    if (($DISABLE_DCACHE == 1))
    then
       EXTRA_DEFINES+=("FV_DUT_DCACHE_DISABLED")
    fi
	
    if (($DISABLE_MMU == 1))
    then
       EXTRA_DEFINES+=("FV_DUT_MMU_DISABLED")
    fi
fi

EXTRA_DEFINES+=("FV_DUT_MEM_REGION_ENABLES ${MEM_REGION_ENABLES}")

if [ "$PROPERTY" != "si" ]; then
    EXTRA_DEFINES+=("FV_DUT_SHORTEN_MUL_DIV")
fi

if (($SIS == 1))
then
    EXTRA_DEFINES+=("FV_SYMBOLIC_INITIAL_STATE")
fi

if (($FV_COV == 1))
then
    PROP_TCL+=("set run_fv_cov 1")
fi

DATE=$(date +%F_%H-%M-%S)

if [ "$TEST_DIR" == "" ]; then
    TEST_DIR="${TOOL}_${DUT}_${PROP_SETUP_FILE}${CONFIG}_${DATE}"
fi

if (($REGRESS == 1))
then
    TEST_DIR="reg_${TEST_DIR}"
fi

SAVED_PWD=`pwd`
mkdir $TEST_DIR

mkdir $TEST_DIR/$TOOL
cp $TOOL/$DUT/* $TEST_DIR/$TOOL
cp $TOOL/common/*.tcl $TEST_DIR/$TOOL

mkdir $TEST_DIR/fv_rtl

FV_SRC="../fv/rtl"
FV_SRC_2="${FV_SRC}/${TOOL}/${ISA}"

# ===============
# copy FV files
    # copy encrypted files
    cp ${FV_SRC_2}/*.svp ${FV_SRC_2}/*.svhp  $TEST_DIR/fv_rtl
    # copy non-encrypted files
    cp ${FV_SRC}/fv.sv ${FV_SRC}/FV_prop.sv ${FV_SRC}/FV_BINDS_mem_mappings.sv ${FV_SRC}/FV_binds.sv ${FV_SRC}/FV_cov.sv ${FV_SRC}/isa/$ISA/FV_PROP_si.sv ${FV_SRC}/isa/$ISA/FV_COV_instructions.sv $TEST_DIR/fv_rtl
    cp ${FV_SRC}/fv.vh ${FV_SRC}/isa/$ISA/FV_trim_indiv_instr*.svh $TEST_DIR/fv_rtl
    # copy DUT-specific files
    cp ${FV_SRC}/dut/$DUT/*.svh $TEST_DIR/fv_rtl
    echo "set enc \"\"" > $TEST_DIR/$TOOL/fv_enc_setup.tcl
    if [ "$INIT_CONFIG" == "" ]; then
	echo "set init_from_file 0" >> $TEST_DIR/$TOOL/fv_enc_setup.tcl
    else
	echo "set init_from_file 1" >> $TEST_DIR/$TOOL/fv_enc_setup.tcl
	echo "set init_file \"init_${INIT_CONFIG}.fsdb\"" >> $TEST_DIR/$TOOL/fv_enc_setup.tcl
    fi
    cp $TOOL/common/fv.vlist $TEST_DIR/$TOOL
# ===============

if [ "$INIT_CONFIG" != "" ]; then
    cp $INIT_FILE $TEST_DIR/$TOOL/
fi

mkdir $TEST_DIR/dut_rtl
cp -r ${DUT_RTL_DIR}* $TEST_DIR/dut_rtl

cd $TEST_DIR

# ==========
# initialize results.txt with setup config

echo "Date and time:" $DATE | tee results.txt
echo "Running test(s) under directory: "$TEST_DIR | tee -a results.txt
echo "Tool:"$TOOL \
     ", DUT:"$DUT \
     ", Properties:"${PROPERTIES[@]} \
     ", Config:"$CONFIG \
     ", Options:"${OPTIONS[@]} \
     ", Bug#:"$BUG \
     ", Time limit:"$TIME_LIMIT | tee -a results.txt

if [ "$BUG" = "all" ]; then
    FIRST_BUG=0
    LAST_BUG=$DUT_MAX_BUGS
    REGRESS=1
elif [ "$BUG" = "none" ]; then
    FIRST_BUG=99999 # special value
    LAST_BUG=99999
else
    FIRST_BUG=$BUG
    LAST_BUG=$BUG
fi

# ==========
# writing fv_reg_setup
echo "set regress ${REGRESS}"        > $TOOL/fv_reg_setup.tcl
echo "set reg_time_out $TIME_LIMIT" >> $TOOL/fv_reg_setup.tcl

for ((i = 0; i < ${#PROP_TCL[@]}; i++))
do
    echo "${PROP_TCL[$i]}" >> $TOOL/fv_reg_setup.tcl
done
echo "set dup_sync ${DUP_SYNC}"  >> $TOOL/fv_reg_setup.tcl

# ==========
# bug loop

for ((b=${FIRST_BUG}; b<=${LAST_BUG}; b++)); do
    mkdir "bug_${b}"
    cd "bug_${b}"
    cp ../../novas.rc .
    cp ../../$CONFIG_FILE config.vh
    for ((i = 0; i < ${#PROP_DEFINES[@]}; i++))
    do
	echo "\`define ${PROP_DEFINES[$i]}" >> config.vh
    done
    for ((i = 0; i < ${#EXTRA_DEFINES[@]}; i++))
    do
	echo "\`define ${EXTRA_DEFINES[$i]}" >> config.vh
    done
    if (($b == 99999))
    then
	# no bug enable
	echo ""
    else
	echo "\`define ${DUT_BUG_PREFIX}${b}" >> config.vh
    fi
    PWD=`pwd`
    echo "In directory: $PWD"
    echo $TOOL_CMD > cmd.log
    if (($DRY_RUN == 1))
    then
	echo "SKIP run for bug ${b}: ${TOOL_CMD}"
    else
	echo "Running for bug ${b}: ${TOOL_CMD}"
	$TOOL_CMD
	grep $REPORT_DET_PHRASE fv_report.txt > falsified_properties.txt
	if [ ! -s falsified_properties.txt ]; then
	    echo "Bug ${b} was NOT detected!" | tee -a ../results.txt
	else
	    echo "Bug ${b} was detected!" | tee -a ../results.txt
	fi
    fi
    cd ..
done

cd $SAVED_PWD
