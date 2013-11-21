#!/bin/sh

data=("T_e.txt")

data_dir="../data"
result_dir="../results"
context_dir="../context"
model_dir="../models"
trans_dir="../datatrans"
index_sc="./index.pl"
context_sc="./context.pl"
tokenize_sc="./tokenize.pl"
align_sc="./align.pl"
myalign_sc="./myalign.pl"
postprocess_sc="./postprocess.pl"

input_fl="$trans_dir/layersnumeric.txt"
index_fl="$result_dir/wordindex"
context_fl="$context_dir/context"
contextr_fl="$result_dir/context"
token_fl="$result_dir/tokens"
align_fl="$result_dir/aligned"
myalign_fl="$result_dir/myaligned"
cluster_fl="$result_dir/clusters.txt"
info_fl="$result_dir/info"
pretty_fl="$result_dir/postalign"

output_type="application/json"

debug_flag=0
test_flag=0
verbose_flag=0

granularity="chapter"
align_tp=plain

do_index=
do_context=
do_tokenize=
do_align=
do_myalign=
do_gridalign=
do_postprocess=

declare -a task_args

while
	flag=$1
	[ "$flag" != "" ] 
do
	shift
	if
		[ "$flag" == "json" ]
	then
		align_tp="json"
	elif
		[ "$flag" == "plain" ]
	then
		align_tp="plain"
	elif
		[ "$flag" == "svg" ]
	then
		align_tp="svg"
	elif
		[ "$flag" == "-d" ]
	then
		debug_flag=1
	elif
		[ "$flag" == "-v" ]
	then
		verbose_flag=1
	elif
		[ "$flag" == "-t" ]
	then
		test_flag=1
	elif
		[ "$flag" == "-T" ]
	then
		test_flag=2
	elif
		[ "$flag" == "-gv" ]
	then
		granularity="verse"
	elif
		[ "$flag" == "+i" ]
	then
		do_index=true
	elif
		[ "$flag" == "+c" ]
	then
		do_context=true
	elif
		[ "$flag" == "+t" ]
	then
		do_tokenize=true
	elif
		[ "$flag" == "+a" ]
	then
		do_align=true
	elif
		[ "$flag" == "+m" ]
	then
		do_myalign=true
	elif
		[ "$flag" == "+g" ]
	then
		do_gridalign=true
	elif
		[ "$flag" == "+p" ]
	then
		do_postprocess=true
	else
		task_args+=" $flag"
	fi
done

if
	[ "$debug_flag" == 1 ]
then
	cmd_string="perl -d "
else
	cmd_string=""
fi

if [ $do_index ]; then
	echo "=== indexing words and passages"
	$cmd_string$index_sc $index_fl
fi

if [ $do_context ]; then
	echo "=== identifying words on the basis of context"
	$cmd_string$context_sc "$test_flag" "$verbose_flag" $context_fl $contextr_fl ${task_args[*]}
fi

if [ $do_tokenize ]; then
	echo "=== generating tokens"
	$cmd_string$tokenize_sc "$test_flag" $contextr_fl $token_fl $granularity ${task_args[*]}
fi

if [ $do_align ]; then
	echo "=== generating alignments with collatex"
	$cmd_string$align_sc "$test_flag" $token_fl $align_fl $granularity $align_tp ${task_args[*]}
fi

if [ $do_myalign ]; then
	echo "=== generating alignments with my algorithm"
	$cmd_string$myalign_sc $input_fl $myalign_fl $cluster_fl $info_fl $model_dir ${task_args[*]}
fi

if [ $do_postprocess ]; then
	echo "=== postprocessing alignment"
	$cmd_string$postprocess_sc "$test_flag" "$verbose_flag" $align_fl $index_fl $pretty_fl $granularity ${task_args[*]}
fi

exit

