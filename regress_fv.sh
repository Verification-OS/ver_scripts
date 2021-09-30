#!/bin/bash 

TOOL="jg"
#DUT="zeroriscy"
REG_LEVEL=0

ALL_DUTS=("zeroriscy")
declare -a DUTS
declare -a OPTIONS
ALL=1

while getopts ":het:d:l:" option; do 
    case "${option}" in 
	h) echo "Usage: run [-h] [-t <tool>] [-d <dut>] [-l <level>] [-e]"
	   echo "    <tool>   options: vcf, jg"
	   echo "    <dut>    DUT name(s); can repeat for multiple DUT runs in series (default is all)"
	   echo "    <level>  regression level: 0,1,2,3,all (default is 0; other levels to be defined by customer)"
	   echo "    -e       for reading encrypted FV RTL files"
	   exit 0;;
	t) TOOL=${OPTARG};; 
	d) ALL=0
	   DUTS+=(${OPTARG})
	   ;; 
	l) REG_LEVEL=${OPTARG};;
	
	\?) echo "Invalid option: -$OPTARG" 1>&2
	   exit 1;;
	:) echo "Invalid option: $OPTARG requires an argument" 1>&2
	   exit 1;;
    esac 
done 

if (($ALL==1))
then
    DUTS=$ALL_DUTS
fi

#===================
#===================

for ((i = 0; i < ${#DUTS[@]}; i++))
do
    DUT=${DUTS[$i]}
    
    #===================
    BUG="none"

    ./run_fv.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 15m
    ./run_fv.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 20m -s
    ./run_fv.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 15m                -o inc_if
    ./run_fv.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 90m  -c trim_indiv
    ./run_fv.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 90m  -c trim_indiv -o inc_if

    ./run_fv.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 90m
    ./run_fv.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 90m                -o inc_if

    ./run_fv.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 15m  -c nodiv
    ./run_fv.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 15m  -c nodiv      -o inc_if
    
    ./run_fv.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 20m
    ./run_fv.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 20m                -o inc_if

    ./run_fv.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 60m  -c trim_indiv
    ./run_fv.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 60m  -c trim_indiv -o inc_if
    ./run_fv.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 100m               -o inc_if

    ./run_fv.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 100m -c trim_indiv          
    ./run_fv.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 100m -c trim_indiv -o inc_if
    ./run_fv.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 100m               -o inc_if
    
    #===================
    # run some bug examples to make sure they get detected and we are not getting all false positives
    #===================
    if [ "$DUT" == "zeroriscy" ]; then

	BUG=0
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c trim_indiv -o inc_if
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c rv32e
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 10m
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 10m               -o inc_if
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 10m -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 10m -c trim_indiv -o inc_if

	BUG=1
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 10m
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 10m               -o inc_if
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 10m -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 10m -c trim_indiv -o inc_if
	
	BUG=2
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 10m -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 10m -c trim_indiv -o inc_if
	
	BUG=3
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c trim_indiv -o inc_if
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 10m -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 10m -c trim_indiv -o inc_if
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 10m -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 10m -c trim_indiv -o inc_if
	
	BUG=4
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 10m
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 10m -c trim_indiv -o inc_if
	
	BUG=5
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 10m               -o inc_if

	BUG=6
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 60m               -o inc_if
	./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 90m -c trim_indiv -o inc_if
	
	BUG=11
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 10m -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 180m -c trim_indiv -o inc_if

    fi

    #===================
    # summarize results

    echo "$DUT regression results:" | tee reg_results_${DUT}.txt
    grep detected reg_${TOOL}_${DUT}_*/results.txt | tee -a reg_results_${DUT}.txt

    echo "****   Unexpected results: ****" | tee -a reg_results_${DUT}.txt
    grep detected reg_${TOOL}_${DUT}_*/results.txt | grep 99999 | grep -v NOT | tee -a reg_results_${DUT}.txt
    grep "NOT detected" reg_${TOOL}_${DUT}_*/results.txt | grep -v 99999 | tee -a reg_results_${DUT}.txt
    grep "FV_cover_" reg_jg_${DUT}_*/bug_99999/fv_report.txt | grep -v covered | tee -a reg_results_${DUT}.txt
    
    echo "Errors:" | tee -a reg_results_${DUT}.txt
    if [ "$TOOL" == "vcf" ]; then
	grep ERROR reg_vcf_${DUT}_*/bug*/vcf.log | tee -a reg_results_${DUT}.txt
    else
	grep ERROR reg_jg_${DUT}_*/bug*/jgproject/jg.log | tee -a reg_results_${DUT}.txt
    fi

done

