#!/bin/bash 

# defaults
ROOT="../fv_eng_files"
RELEASE=""
CUSTOMER=""
declare -a DUTS
declare -a TOOLS
declare -a ISAS
#ISA="riscv"

while getopts ":hr:c:d:t:" option; do 
    case "${option}" in 
	h) echo "Usage: release [-h] -r <release #> -c customer -d <dut> [-t <tool>] [-i <isa>]"
	   echo "    <release #>: is the release number; it can be any string; it is suffixed to 'release_'"
	   echo "    <customer> : is the customer company name"
	   echo "    <dut>      : is the DUT (device) name which is customized files for customer DUT or example DUT (can be multiple)"
	   echo "    <tool>     : is the EDA tool choice (vcf and/or jg; can be multiple)"
# ISA is set per DUTs requested
	   #	   echo "    <isa>  optional: riscv (default) and already set for known DUTs"
	   echo "    NOTE: old files are always deleted from the release_<#>/<customer> directory"
	   exit 0;;
	r) RELEASE=${OPTARG};; 
	c) CUSTOMER=${OPTARG};; 
	d) DUTS+=(${OPTARG});; 
	t) TOOLS+=(${OPTARG});; 
#	i) ISA=${OPTARG};; 
	
	\?) echo "Invalid option: -$OPTARG" 1>&2
	   exit 1;;
	:) echo "Invalid option: $OPTARG requires an argument" 1>&2
	   exit 1;;
    esac 
done 

# =========

if [ "$RELEASE" == "" ]; then
    echo "ERROR: need to specify <release #> (a string) with -r switch"
    exit 1
fi

if [ "$CUSTOMER" == "" ]; then
    echo "ERROR: need to specify <vendor/customer> (a string) with -c switch"
    exit 1
fi

if ((${#DUTS[@]} == 0))
then
    echo "ERROR: need to specify at least one DUT with -d switch"
    exit 1
fi

for DUT in ${DUTS[@]}; do
    case $DUT in
	ridecore | zeroriscy | riscy | cva6 | ara)
	    if [[ ! "${ISAS[@]} " =~ "riscv " ]]; then
	       ISAS+=("riscv")
	    fi
	    ;;
	*) echo "ERROR: Unrecognized DUT $DUT"
	   exit 1;;
    esac
done

if ((${#TOOLS[@]} == 0))
then
    echo "ERROR: need to specify at least one TOOL with -t switch"
    exit 1
fi

for TOOL in ${TOOLS[@]}; do
    case $TOOL in
	vcf | jg)
	;;
	*) echo "ERROR: Unrecognized TOOL $TOOL"
	   exit 1;;
    esac
done

#case $ISA in
#    riscv)
#	;;
#    *) echo "ERROR: Unrecognized ISA $ISA"
#       exit 1;;
#esac

# ==================
# create directories
if [ ! -d "${CUSTOMER}" ]; then
    mkdir $CUSTOMER
fi

DST_DIR="${CUSTOMER}/release_${RELEASE}"
if [ ! -d "${DST_DIR}" ]; then
    mkdir "${DST_DIR}"
fi
# clean up old files
rm -fr "${DST_DIR}/*"

mkdir ${DST_DIR}/fv
mkdir ${DST_DIR}/fv/rtl
for TOOL in ${TOOLS[@]}; do
    mkdir ${DST_DIR}/fv/rtl/${TOOL}
    for ISA in ${ISAS[@]}; do
	mkdir ${DST_DIR}/fv/rtl/${TOOL}/${ISA}
    done
done
mkdir ${DST_DIR}/fv/rtl/dut
for DUT in ${DUTS[@]}; do
    mkdir ${DST_DIR}/fv/rtl/dut/${DUT}
done
mkdir ${DST_DIR}/fv/rtl/isa
for ISA in ${ISAS[@]}; do
    mkdir ${DST_DIR}/fv/rtl/isa/${ISA}
done
mkdir ${DST_DIR}/fv/doc
mkdir ${DST_DIR}/duts/
for DUT in ${DUTS[@]}; do
    mkdir ${DST_DIR}/duts/${DUT}
    mkdir ${DST_DIR}/duts/${DUT}/rtl
done
mkdir ${DST_DIR}/tests
mkdir ${DST_DIR}/tests/configs
for TOOL in ${TOOLS[@]}; do
    mkdir ${DST_DIR}/tests/${TOOL}
    mkdir ${DST_DIR}/tests/${TOOL}/common
    for DUT in ${DUTS[@]}; do
	mkdir ${DST_DIR}/tests/${TOOL}/${DUT}
    done
done

# =========
# copy document files
cp ${ROOT}/fv/doc/* ${DST_DIR}/fv/doc/

# =========
SRC_RTL="${ROOT}/fv/rtl"
DST_RTL="${DST_DIR}/fv/rtl"

# =========
# encrypt the FV code
SAVED_PWD=`pwd`
cd ${SRC_RTL}/
for TOOL in ${TOOLS[@]}; do
    for DUT in ${DUTS[@]}; do
	# Note: change to -i ${ISA} when encrypt.sh supports it to avoid redundant iteration for the same ISA
	./encrypt.sh -t ${TOOL} -d ${DUT}
    done
done
cd $SAVED_PWD

# =========
# copy FV encrypted files
for TOOL in ${TOOLS[@]}; do
    for ISA in ${ISAS[@]}; do
	cp ${SRC_RTL}/encrypted/${TOOL}/${ISA}/*.svp              ${DST_RTL}/${TOOL}/${ISA}/
	cp ${SRC_RTL}/encrypted/${TOOL}/${ISA}/*.svhp             ${DST_RTL}/${TOOL}/${ISA}/
    done
done

# =========
# copy FV non-encrypted files
cp ${SRC_RTL}/fv.sv                            ${DST_RTL}/
cp ${SRC_RTL}/FV_prop.sv                       ${DST_RTL}/
cp ${SRC_RTL}/FV_BINDS_mem_mappings.sv         ${DST_RTL}/
cp ${SRC_RTL}/FV_binds.sv                      ${DST_RTL}/
cp ${SRC_RTL}/FV_cov.sv                        ${DST_RTL}/
cp ${SRC_RTL}/fv.vh                            ${DST_RTL}/
for ISA in ${ISAS[@]}; do
    cp ${SRC_RTL}/isa/$ISA/FV_PROP_si.sv            ${DST_RTL}/isa/$ISA/
    cp ${SRC_RTL}/isa/$ISA/FV_COV_instructions.sv   ${DST_RTL}/isa/$ISA/
    cp ${SRC_RTL}/isa/$ISA/FV_trim_indiv_instr*.svh ${DST_RTL}/isa/$ISA/
done

# =========
for DUT in ${DUTS[@]}; do
    # copy FV DUT-specific files
    cp ${SRC_RTL}/dut/${DUT}/*.svh                     ${DST_RTL}/dut/${DUT}/

    # copy example DUT source RTL
    cp -r ${ROOT}/duts/${DUT}/rtl/*                    ${DST_DIR}/duts/${DUT}/rtl/ 
done

# =========
# copy config and setup files
SRC_TST="${ROOT}/tests"
DST_TST="${DST_DIR}/tests"

for DUT in ${DUTS[@]}; do
    cp ${SRC_TST}/configs/${DUT}_*.vh                     ${DST_TST}/configs
done
# NOTE: fv_common_sc_setup3.tcl is for internal use only and not part of release
for TOOL in ${TOOLS[@]}; do
    cp ${SRC_TST}/${TOOL}/common/fv_common_setup*.tcl ${DST_TST}/${TOOL}/common/
    cp ${SRC_TST}/${TOOL}/common/fv_setup.tcl         ${DST_TST}/${TOOL}/common/
    cp ${SRC_TST}/${TOOL}/common/fv_enc.vlist         ${DST_TST}/${TOOL}/common/fv.vlist
    for DUT in ${DUTS[@]}; do
	cp ${SRC_TST}/${TOOL}/${DUT}/fv_*setup*.tcl       ${DST_TST}/${TOOL}/${DUT}/
	cp ${SRC_TST}/${TOOL}/${DUT}/fv_dut.vlist         ${DST_TST}/${TOOL}/${DUT}/
    done
done

# =========
# copy scripts
cp ${SRC_TST}/run_fv.sh                               ${DST_TST}/
cp ${SRC_TST}/regress_fv.sh                           ${DST_TST}/


# =========
# create tar file
cd ${DST_DIR}
tar -cf FV_${CUSTOMER}_release_${RELEASE}.tar *
cd ../..



