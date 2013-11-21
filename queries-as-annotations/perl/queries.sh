#!/bin/sh

data_dir="../data"
query_dir="../queries/philo"
instr_dir="$query_dir/bhs"
list_dir="$query_dir/results"
result_dir="../results"
sql_fl="$result_dir/oannot.sql"

query_sc="./qr.pl"
sql_init="./oannot_create.sql"
last_ids="$result_dir/oannot_ids.txt"

run_queries=false
create_sql=true

if
	$run_queries
then
	echo "=== running queries ... "

	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq01.mql > $list_dir/lq01.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq02.mql > $list_dir/lq02.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq03.mql > $list_dir/lq03.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq04.mql > $list_dir/lq04.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq05.mql > $list_dir/lq05.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq06.mql > $list_dir/lq06.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq07.mql > $list_dir/lq07.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq08.mql > $list_dir/lq08.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq09.mql > $list_dir/lq09.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq10.mql > $list_dir/lq10.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq11.mql > $list_dir/lq11.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq12.mql > $list_dir/lq12.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq13.mql > $list_dir/lq13.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq14.mql > $list_dir/lq14.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq15.mql > $list_dir/lq15.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq16.mql > $list_dir/lq16.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq17.mql > $list_dir/lq17.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq18.mql > $list_dir/lq18.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq19.mql > $list_dir/lq19.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq20.mql > $list_dir/lq20.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq21.mql > $list_dir/lq21.xml
	mql -b 3 -d $data_dir/bhs3 --xml $instr_dir/bh_lq22.mql > $list_dir/lq22.xml
fi

if
	$create_sql
then
	echo "=== creating oannot sql ... "

	cp $sql_init $sql_fl

	if
		[ -e $last_ids ]
	then
		rm $last_ids
	fi

	$query_sc $instr_dir/bh_lq01.mql $list_dir/lq01.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq02.mql $list_dir/lq02.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq03.mql $list_dir/lq03.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq04.mql $list_dir/lq04.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq05.mql $list_dir/lq05.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq06.mql $list_dir/lq06.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq07.mql $list_dir/lq07.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq08.mql $list_dir/lq08.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq09.mql $list_dir/lq09.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq10.mql $list_dir/lq10.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq11.mql $list_dir/lq11.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq12.mql $list_dir/lq12.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq13.mql $list_dir/lq13.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq14.mql $list_dir/lq14.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq15.mql $list_dir/lq15.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq16.mql $list_dir/lq16.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq17.mql $list_dir/lq17.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq18.mql $list_dir/lq18.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq19.mql $list_dir/lq19.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq20.mql $list_dir/lq20.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq21.mql $list_dir/lq21.xml $last_ids >> $sql_fl
	$query_sc $instr_dir/bh_lq22.mql $list_dir/lq22.xml $last_ids >> $sql_fl
fi
