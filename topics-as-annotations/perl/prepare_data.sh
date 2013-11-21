#!/bin/sh

data_dir="../data"
result_dir="../results"

datahuygenschr="$data_dir/huyg003"

datagensql_sc="./make_ckcc_sql.pl"
datagensql_sq="ckcc_create.sql"
annotgensql_sc="./make_annot_sql.pl"
annotgensql_sq="cannot_create.sql"
topicgensql_sq="topic_create.sql"

dataresult_sql="$result_dir/huygenschr.sql"
id_map="$result_dir/huygenschrids.txt"
annotresult_sql="$result_dir/topics.sql"

echo "=== generate sql import of letters ... "
if
	 [ -e $dataresult_sql ] && [ $dataresult_sql -nt $datagensql_sc ] && [ $dataresult_sql -nt $datagensql_sq ] &&
	 [ -e $id_map ] && [ $id_map -nt $datagensql_sc ]
then
	echo "using previous $dataresult_sql and $id_map"
else
	echo "creating new $dataresult_sql and $id_map"
	$datagensql_sc $datagensql_sq $datahuygenschr $dataresult_sql $id_map
fi

echo "=== generate sql import of topics ... "

if
	 [ -e $annotresult_sql ] && [ $annotresult_sql -nt $annotgensql_sc ] && [ $annotresult_sql -nt $annotgensql_sq ] && [ $annotresult_sql -nt $topicgensql_sq ] && [ $annotresult_sql -nt $id_map ]
then
	echo "using previous $annotresult_sql"
else
	echo "creating new $annotresult_sql"
	$annotgensql_sc $annotgensql_sq $topicgensql_sq $data_dir $id_map $annotresult_sql
fi

