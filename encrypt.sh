#!/bin/bash 

# defaults
TOOL="vcf"
DUT="zeroriscy"
ISA="riscv"

while getopts ":ht:d:" option; do 
    case "${option}" in 
	h) echo "Usage: run [-h] [-t <tool>] [-d <dut>]"
	   echo "    <tool>     options: vcf (default)"
	   echo "    NOTE: removes old files from destination directory"
	   exit 0;;
	t) TOOL=${OPTARG};; 
	d) DUT=${OPTARG};; 
	
	\?) echo "Invalid option: -$OPTARG" 1>&2
	   exit 1;;
	:) echo "Invalid option: $OPTARG requires an argument" 1>&2
	   exit 1;;
    esac 
done 

case $DUT in
    ridecore | zeroriscy | riscy | cva6 | ara)
	ISA="riscv"
	;;
    *) echo "ERROR: Unrecognized DUT $DUT"
       exit 1;;
esac

##########
# create the FV_core_enc.sh for encryptions

PROT_RIGHTS='`pragma protect rights=(scheme="simple", default="deny", simulate=(viewers="none"),synthesis=(output_netlist=(method="none") output_annotation=(method="none")))'

echo "\`pragma protect begin" > FV_core_enc.sv
echo "\`protect" >> FV_core_enc.sv
#echo "\`pragma protect rights=(scheme=\"simple\", default=\"deny\")" >> FV_core_enc.sv
echo $PROT_RIGHTS >> FV_core_enc.sv
echo "\`pragma protect version = 2" >> FV_core_enc.sv
cat isa/$ISA/FV_common.sv >> FV_core_enc.sv
cat FV_CORE_constraints.sv >> FV_core_enc.sv
cat FV_CORE_EX_rf.sv >> FV_core_enc.sv
cat FV_CORE_EX_queue.sv >> FV_core_enc.sv
cat FV_CORE_EX_cf.sv >> FV_core_enc.sv
cat FV_CORE_ex.sv >> FV_core_enc.sv
cat isa/$ISA/FV_CORE_decomp_rvc.sv >> FV_core_enc.sv
cat isa/$ISA/FV_CORE_IF_dup.sv >> FV_core_enc.sv
cat isa/$ISA/FV_instructions_rvc.sv >> FV_core_enc.sv
cat isa/$ISA/FV_CORE_IF_instr_constraint_rvc.sv >> FV_core_enc.sv
cat isa/$ISA/FV_instructions.sv >> FV_core_enc.sv
cat isa/$ISA/FV_CORE_IF_instr_constraint.sv >> FV_core_enc.sv
cat FV_CORE_IF_gen.sv >> FV_core_enc.sv
cat FV_CORE_IF_queue.sv >> FV_core_enc.sv
cat FV_CORE_if.sv >> FV_core_enc.sv
cat FV_CORE_inits.sv >> FV_core_enc.sv
cat isa/$ISA/FV_CORE_si.sv >> FV_core_enc.sv
cat FV_core.sv >> FV_core_enc.sv
echo "\`endprotect" >> FV_core_enc.sv
echo "\`pragma protect end" >> FV_core_enc.sv

##########
# encrypt files

# temporarily make a copy in current dir so all encrypted files are in the same dir
cp isa/${ISA}/FV_isa.svh .

case $TOOL in
    vcf) vcs -full64 -sverilog -mangle -f fv_enc_files.txt  +lint=TFIPC-L  +protect
	 ;;
#    jg) xmprotect -LANGUAGE vlog -AUTOPROTECT -FCREATE -IFILEPROTECT -SIMULATION none -SYNTHESIS viewers:none -IP200X -FILE fv_enc_files.txt
    jg) xmprotect -LANGUAGE vlog -FCREATE -IP200X -FILE fv_enc_files.txt
	 ;;
    *) echo "ERROR: Unrecognized tool $TOOL"
       exit 1;;
esac

##########
# copy/move files

if [ ! -d "encrypted" ]; then
    mkdir encrypted
fi

if [ ! -d "encrypted/${TOOL}" ]; then
    mkdir "encrypted/${TOOL}"
fi

if [ ! -d "encrypted/${TOOL}/${ISA}" ]; then
    mkdir "encrypted/${TOOL}/${ISA}"
fi

# remove old encrypted files
rm -f "encrypted/${TOOL}/${ISA}/*"

# move the old encrypted files
mv *p "encrypted/${TOOL}/${ISA}/"
# remove the file that was copied here temporarily
rm FV_isa.svh

# copy the clear-text (un-encrypted) files
# Note: copy only for release
#cp FV_binds.sv FV_prop.sv FV_si.sv *.vh "encrypted/${TOOL}/"
