#!/bin/sh

data=("T_e.txt")

data_dir="../data"
result_dir="../results"
token_sc="./tokenize.pl"
align_sc="./align.pl"
recon_sc="./reconcile.pl"

token_fl="$result_dir/tokenized.txt"
align_fl="$result_dir/aligned."
recon_fl="$result_dir/reconciled.txt"

taskflag=( 0 1 0 0 )
align_ext=( "html" "json" "xml" "graphml" )
output_type=( "text/html" "application/json" "application/xml" "application/graphml+xml" )

debug=0
force=0

while
	flag=$1
	[ "$flag" != "" ] 
do
	shift
	if
		[ "$flag" == "-d" ]
	then
		debug=1
	elif
		[ "$flag" == "-f" ]
	then
		force=1
	elif
		[ "$flag" == "+h" ]
	then
		taskflag[0]=1
	elif
		[ "$flag" == "+j" ]
	then
		taskflag[1]=1
	elif
		[ "$flag" == "+t" ]
	then
		taskflag[2]=1
	elif
		[ "$flag" == "+g" ]
	then
		taskflag[3]=1
	elif
		[ "$flag" == "-h" ]
	then
		taskflag[0]=0
	elif
		[ "$flag" == "-j" ]
	then
		taskflag[1]=0
	elif
		[ "$flag" == "-t" ]
	then
		taskflag[2]=0
	elif
		[ "$flag" == "-g" ]
	then
		taskflag[3]=0
	fi
done

if
	[ "$debug" == 1 ]
then
	cmd_string="perl -d "
else
	cmd_string=""
fi

echo "=== generating tokens"
if
	 [ $force == 0 ] && [ -e $token_fl ] && [ $token_fl -nt $token_sc ]
then
	echo "using previous $token_fl"
else
	echo "creating new $token_fl"
	$cmd_string$token_sc $token_fl ${data[@]/#/$data_dir/}
fi

echo "=== generating alignments with collatex"
for index in 0 1 2 3
do
	if
		[ "${taskflag[$index]}" == 1 ]
	then
		echo "output=${align_ext[$index]}"
		align="$align_fl${align_ext[$index]}"
		output="${output_type[$index]}"
		if
			 [ $force == 0 ] && [ -e $align ] && [ $align -nt $align_sc ] && [ $align -nt $token_fl ]
		then
			echo "using previous $align"
		else
			echo "creating new $align"
			$cmd_string$align_sc $token_fl $align $output
		fi
	fi
done

align="$align_fl${align_ext[1]}"
if
	 [ $force == 0 ] && [ -e $recon_fl ] && [ $recon_fl -nt $recon_sc ] && [ $recon_fl -nt $align ]
then
	echo "using previous $recon_fl"
else
	echo "creating new $recon_fl"
	$cmd_string$recon_sc $align $recon_fl
fi

exit

