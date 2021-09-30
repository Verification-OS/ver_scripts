#!/bin/bash 

TOOL="jg"
#DUT="zeroriscy"
REG_LEVEL=0

ALL_DUTS=("ridecore" "zeroriscy" "riscy" "cva6" "ara")
declare -a DUTS
declare -a OPTIONS
ALL=1

while getopts ":het:d:l:" option; do 
    case "${option}" in 
	h) echo "Usage: run [-h] [-t <tool>] [-d <dut>] [-l <level>] [-e]"
	   echo "    <tool>   options: vcf, jg"
	   echo "    <dut>    options: ridecore, zeroriscy, riscy, cva6, ara"
	   echo "    <level>  regression level: 0,1,2,3,all (default is 0)"
	   echo "    -e       for reading encrypted FV RTL files"
	   exit 0;;
	t) TOOL=${OPTARG};; 
	d) ALL=0
	   DUTS+=(${OPTARG})
	   ;; 
	e) ENCRYPTED=1;;
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
    # less than or equalt to an hour no-bug tests
    BUG="none"

    if [ "$DUT" == "ridecore" ]; then

	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 30m -c 2way -s

    elif [[ "$DUT" == "cva6" || "$DUT" == "ara" ]]; then

	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m
	./run.sh -t $TOOL -d $DUT -p dup -p cmt  -b $BUG -r -l 10m  -c trim_indiv -m "8'b01000101"
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 15m  -c no_rv32m                        -o inc_rva
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 20m  -c no_rv32m   -o inc_if            -o inc_rva
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 15m  -c no_rv32m             -o inc_rvc -o inc_rva
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 20m  -c no_rv32m   -o inc_if -o inc_rvc -o inc_rva

    else
    
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 15m
	./run.sh -t $TOOL -d $DUT -p dup -p cf  -b $BUG -r -l 20m -s
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 15m                -o inc_if
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 15m                          -o inc_rvc
	./run.sh -t $TOOL -d $DUT -p dup -p cf  -b $BUG -r -l 20m                -o inc_if -o inc_rvc

	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 15m  -c nodiv
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 15m  -c nodiv      -o inc_if -o inc_rvc
	
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 20m
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 20m                -o inc_if
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 20m                          -o inc_rvc
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 20m                -o inc_if -o inc_rvc

	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 20m                          -o inc_rvc
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 20m                -o inc_if -o inc_rvc

	# zeroriscy with rv32e
	if [ "$DUT" == "zeroriscy" ]; then
	    ./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 30m  -c rv32e           
	    ./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 30m  -c rv32e -o inc_if 
	    ./run.sh -t $TOOL -d $DUT         -p cf  -b $BUG -r -l 30m  -c rv32e -o inc_if 
	    ./run.sh -t $TOOL -d $DUT         -p cmt  -b $BUG -r -l 30m  -c rv32e -o inc_if 
	fi

	# riscy with imem128 and RVF
	if [ "$DUT" == "riscy" ]; then
	    ./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 30m  -c trim_indiv           -o imem128
	    ./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 30m  -c trim_indiv -o inc_if -o imem128
	    ./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 30m  -c trim_indiv -o inc_rvf
	    ./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 30m  -c trim_indiv -o inc_if -o imem128 -o inc_rvc 
	    ./run.sh -t $TOOL -d $DUT         -p cf  -b $BUG -r -l 30m                -o inc_if -o imem128
	    ./run.sh -t $TOOL -d $DUT         -p cmt  -b $BUG -r -l 30m                -o inc_if -o imem128
	fi

    fi
    
    #===================
    if [ "$DUT" == "ridecore" ]; then

	BUG=0
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 45m -c 2way

	BUG=1
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 15m 
	
	BUG=4
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m 
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c 2way 

	BUG=5
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 15m 
	
	BUG=7
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 35m 
	
	BUG=10
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c 2way

	BUG=16
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 60m -c 2way

	BUG=17
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c 2way

	BUG=18
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c 2way

	BUG=19
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 10m -c 2way

	BUG=22
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 40m -c 2way

    fi

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
    if [ "$DUT" == "riscy" ]; then

	OPTIONS=("" "-o imem128")

	for ((i = 0; i < ${#OPTIONS[@]}; i++))
	do
	    OPTION=${OPTIONS[$i]}

	    BUG=0
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup           -b $BUG -r -l 30m -c trim_indiv
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup  -p cf -b $BUG -r -l 30m -c trim_indiv -o inc_if
	    
	    BUG=1
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup           -b $BUG -r -l 35m
	    
	    BUG=2
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup           -b $BUG -r -l 240m -c trim_indiv -o inc_if
	    
	    BUG=4
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup           -b $BUG -r -l 240m -c trim_indiv
	    
	    BUG=5
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup           -b $BUG -r -l 40m
	    
	    if ["$TOOL" = "vcf"]; then
		# this bug creates combinational loop that JG doesn't like
		BUG=6
		./run.sh -t $TOOL -d $DUT $OPTION -p dup           -b $BUG -r -l 180m -c trim_indiv
	    fi
	    
	    #add when ECALL is included
	    #BUG=7
	    #./run.sh -t $TOOL -d $DUT $OPTION -p cmt          -b $BUG -r -l 10m -c trim_indiv
	    #./run.sh -t $TOOL -d $DUT $OPTION -p all            -b $BUG -r -l 20m -c trim_indiv -o inc_if
	    
	    # BUG 9 is detected by CF but needs DUP enabled
	    BUG=9
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup  -p cf -b $BUG -r -l 10m 
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup  -p cf -b $BUG -r -l 10m               -o inc_if
	    
	    BUG=10
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup           -b $BUG -r -l 10m

	    BUG=13
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup           -b $BUG -r -l 12h -o inc_rvf -c ti3

	    BUG=14
	    ./run.sh -t $TOOL -d $DUT $OPTION -p dup           -b $BUG -r -l 20m -o inc_rvf -c ti4

	done
	
    fi

    #===================
    if [[ "$DUT" == "cva6" || "$DUT" == "ara" ]]; then

	BUG=0
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 60m
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 120m -o inc_if

	BUG=1
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 7h -o inc_rvf -c ti4

	BUG=2
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 90m -o inc_rvf -o inc_csr

	BUG=13
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 4h -o inc_rvf -c ti3
    fi
       
    #===================
    # more than an hour no-bug tests
    
    BUG="none"

    if [ "$DUT" == "ridecore" ]; then

	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 60m
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 60m -c 2way
	./run.sh -t $TOOL -d $DUT -p cmt          -b $BUG -r -l 60m

    elif [[ "$DUT" == "cva6" || "$DUT" == "ara" ]]; then

	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 60m
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 60m  -o inc_if
	./run.sh -t $TOOL -d $DUT -p dup -p cmt  -b $BUG -r -l 60m  -o inc_if
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 100m           -o inc_rvc -o inc_rvf -o inc_rva -o inc_csr
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 100m -o inc_if -o inc_rvc -o inc_rvf -o inc_rva -o inc_csr
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 120m           -o inc_rvc -o inc_rvf -o inc_rva -o inc_csr -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 120m -o inc_if -o inc_rvc -o inc_rvf -o inc_rva -o inc_csr -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 60m            -o inc_rva -c trim_indiv -m "8'b01000101"

    else

	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 60m  -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 60m  -c trim_indiv -o inc_if
	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 60m  -c trim_indiv -o inc_if -o inc_rvc

	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 90m  -c trim_indiv
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 90m  -c trim_indiv -o inc_if
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 90m                          -o inc_rvc
	./run.sh -t $TOOL -d $DUT -p dup           -b $BUG -r -l 90m                -o inc_if -o inc_rvc

	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 90m
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 90m                -o inc_if
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 90m                          -o inc_rvc
	./run.sh -t $TOOL -d $DUT -p cf          -b $BUG -r -l 90m                -o inc_if -o inc_rvc

	./run.sh -t $TOOL -d $DUT -p dup  -p cf -b $BUG -r -l 100m               -o inc_if

	./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 100m -c trim_indiv          
	./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 100m -c trim_indiv -o inc_if
	./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 100m               -o inc_if
	./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 100m                         -o inc_rvc
	./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 100m               -o inc_if -o inc_rvc

	# zeroriscy with rv32e
	if [ "$DUT" == "zeroriscy" ]; then
	    ./run.sh -t $TOOL -d $DUT -p dup -p cf  -b $BUG -r -l 60m  -c rv32e -o inc_if 
	    ./run.sh -t $TOOL -d $DUT -p dup -p cf  -b $BUG -r -l 60m  -c rv32e -o inc_if -o inc_rvc 
	    ./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 120m -c rv32e -o inc_if 
	fi

	# riscy with imem128 and RVF
	if [ "$DUT" == "riscy" ]; then
	    ./run.sh -t $TOOL -d $DUT -p dup -p cf  -b $BUG -r -l 60m  -c trim_indiv -o inc_if -o imem128
	    ./run.sh -t $TOOL -d $DUT -p dup -p cf  -b $BUG -r -l 60m                -o inc_if -o inc_rvf
	    ./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 120m -c trim_indiv -o inc_if -o imem128
	    ./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 120m -c trim_indiv -o inc_if -o imem128 -o inc_rvc 
	    ./run.sh -t $TOOL -d $DUT -p all            -b $BUG -r -l 120m -c trim_indiv -o inc_if -o inc_rvf -o inc_rvc 
	fi

    fi    

    #===================

    echo "$DUT regression results:" | tee reg_results_${DUT}.txt
    grep detected reg_${TOOL}_${DUT}_*/results.txt | tee -a reg_results_${DUT}.txt
    grep "Time limit expired" reg_jg_${DUT}_*/bug*/jgproject/jg.log | tee -a reg_results_${DUT}.txt

    echo "Covers" | tee -a reg_results_${DUT}.txt
    if [ "$TOOL" == "vcf" ]; then
	grep "# Cover" reg_vcf_${DUT}_*/bug_99999/fv_report.txt | tee -a reg_results_${DUT}.txt
	grep "covered" reg_vcf_${DUT}_*/bug_99999/fv_report.txt | tee -a reg_results_${DUT}.txt
    else
	grep "covers" reg_jg_${DUT}_*/bug*/jgproject/jg.log | tee -a reg_results_${DUT}.txt
	grep "\- covered" reg_jg_${DUT}_*/bug*/jgproject/jg.log | tee -a reg_results_${DUT}.txt
    fi

    echo "****   Unexpected results: ****" | tee -a reg_results_${DUT}.txt
    grep detected reg_${TOOL}_${DUT}_*/results.txt | grep 99999 | grep -v NOT | tee -a reg_results_${DUT}.txt
    grep "NOT detected" reg_${TOOL}_${DUT}_*/results.txt | grep -v 99999 | tee -a reg_results_${DUT}.txt
    grep "FV_cover_" reg_jg_${DUT}_*/bug_99999/fv_report.txt | grep -v covered | tee -a reg_results_${DUT}.txt
    
    echo "Errors:" | tee -a reg_results_${DUT}.txt
    if [ "$TOOL" == "vcf" ]; then
	grep ERROR reg_vcf_${DUT}_*/bug*/vcf.log | tee -a reg_results_${DUT}.txt
    else
	grep ERROR reg_jg_${DUT}_*/bug*/jgproject/jg.log | tee -a reg_results_${DUT}.txt
	grep "Creating net" reg_jg_${DUT}_*/bug*/jgproject/jg.log | tee -a reg_results_${DUT}.txt
    fi

done

