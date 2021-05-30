#!/bin/bash
# CPSparrow.sh, Adrian Balint, 2014
#
# solve CNF formula $1 by simplifying first with coprocessor, then run the SAT solver Sparrow, and finally, reconstruct the model
#

#
# usage
#
if [ "x$1" = "x" -o "x$2" = "x"  -o "x$3" = "x" ]; then
  echo "USAGE: CPSparrow.sh <input CNF> <seed> <tempdir>"
  exit 1
fi

#
# variables for the script
#

file=$1 #instance
shift
seed=$1 #seed
shift
cutoff_time=$1
#shift
#tmpDir=$1 #tempdir

# binary of the used SAT solver
satsolver=CCAnr+cnc						# name of the binary (if not in this directory, give relative path as well)

# default parameters for preprocessor
cp3params="-enabled_cp3 -cp3_stats -up -subsimp -bve -no-bve_gates -no-bve_strength -bve_red_lits=1 -cp3_bve_heap=1 -bve_heap_updates=1 -bve_totalG -bve_cgrow_t=1000 -bve_cgrow=10"

ROOTDIR="$(dirname "${BASH_SOURCE[0]}" )"
tmpDir="tmp"

# some temporary files 
undo=${ROOTDIR}/$tmpDir/cp_undo_$$				# path to temporary file that stores cp3 undo information
tmpCNF=${ROOTDIR}/$tmpDir/cp_tmpCNF_$$		# path to temporary file that stores cp3 simplified formula
model=${ROOTDIR}/$tmpDir/cp_model_$$			# path to temporary file that model of the preprocessor (stdout)
realModel=${ROOTDIR}/$tmpDir/model_$$			# path to temporary file that model of the SAT solver (stdout)
echo "c undo: $undo tmpCNF: $tmpCNF model: $model realModel: $realModel"

ppStart=0
ppEnd=0
solveStart=0
solveEnd=0

#
# run coprocessor with parameters added to this script
# and output to stdout of the preprocessor is redirected to stderr
#
ppStart=`date +%s`
${ROOTDIR}/coprocessor $file $realModel -enabled_cp3 -undo=$undo -dimacs=$tmpCNF $cp3params 1>&2
exitCode=$?
ppEnd=`date +%s`
echo "c preprocessed $(( $ppEnd - $ppStart)) seconds" 1>&2
echo "c preprocessed $(( $ppEnd - $ppStart)) seconds with exit code $exitCode"

# solved by preprocessing
if [ "$exitCode" -eq "10" -o "$exitCode" -eq "20" ]
then 
	echo "c solved by preprocessor"
else
	echo "c not solved by preprocessor -- do search"
	if [ "$exitCode" -eq "0" ]
	then
		solveStart=`date +%s`
		${ROOTDIR}/$satsolver -inst $tmpCNF -seed $seed -cutoff_time ${cutoff_time} -cnctimes '20' -ls_no_improv_steps '100000' -swt_p '0.3' -swt_q '0.7' -swt_threshold '50' > $model
		exitCode=$?
		solveEnd=`date +%s`
		echo "c solved $(( $solveEnd - $solveStart )) seconds" 1>&2
	
		#
		# undo the model
		# coprocessor can also handle "s UNSATISFIABLE"
		#
		echo "c post-process with coprocessor"
		${ROOTDIR}/coprocessor -post -undo=$undo -model=$model > $realModel
	
		#
		# verify final output if SAT?
		#
		if [ "$exitCode" -eq "10" ]
		then
			echo "c verify model ..."
			# ./verify SAT $realModel $file
		fi
	else
		#
		# preprocessor returned some unwanted exit code
		#
		echo "c preprocessor has been unable to solve the instance"
		echo "c starting the SAT solver directly on the original CNF"
		#
		# run sat solver on initial instance
		# and output to stdout of the sat solver is redirected to stderr
		#
		solveStart=`date +%s`
		${ROOTDIR}/$satsolver -inst $file -seed $seed -cutoff_time ${cutoff_time} -cnctimes '20' -ls_no_improv_steps '100000' -swt_p '0.3' -swt_q '0.7' -swt_threshold '50' > $realModel 
		exitCode=$?
		solveEnd=`date +%s`
		echo "c solved $(( $solveEnd - $solveStart )) seconds" 1>&2
	fi
fi

#
# print times
#

echo "c pp-time: $(( $ppEnd - $ppStart)) solve-time: $(( $solveEnd - $solveStart ))"

#
# print solution
#
cat $realModel

#
# remove tmp files
#
rm -f $undo $undo.map $tmpCNF $model $realModel

#
# return with correct exit code
#
exit $exitCode
