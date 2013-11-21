#!/bin/sh

data_dir="../data"
query_dir="../queries/export"
result_dir="../results"

datawivu="$data_dir/bhs3"
datawestm="$data_dir/westm.txt"

verses_qu="$query_dir/verses.mql"
verses_sc="./verses.pl"
verses_fl="$result_dir/verses.txt"
verses_fl_n="$result_dir/verses_nice.txt"

words_text_qu="$query_dir/words_text.mql"
words_text_sc="./words_text.pl"
words_text_fl="$result_dir/words_text.txt"
words_text_fl_n="$result_dir/words_text_nice.txt"

words_westm_sc="./words_westm.pl"
words_westm_fl="$result_dir/westm_nice.txt"

words_feature_qu="$query_dir/words_feature.mql"
words_feature_sc="./words_feature.pl"
words_feature_fl="$result_dir/words_feature.txt"
words_feature_fl_n="$result_dir/words_feature_nice.txt"

anchors_wivu_sc="./make-wivuanchors.pl"
anchors_westm_sc="./make-westmanchors.pl"
alignment_sc="./align.pl"
anchors_sc="./newanchors.pl"
anchors_wivu_l="$result_dir/wivu-anchors.lst"
anchors_westm_l="$result_dir/westm-anchors.lst"
alignment_l="$result_dir/alignment.lst"
alignment_la="$result_dir/alignmentanchors.lst"

results_sc="./combine.pl"
results_wivu_sq="./make-wivusql.pl"
results_wivu_sc="./normalise-wivu.pl"
results_westm_sq="./make-westmsql.pl"
results_westm_sc="./normalise-westm.pl"
results_sqf="./make-featuresql.pl"
source_sqc="./source_create.sql"
results_fl_a="$result_dir/anchors.txt"
results_wivu_fl_s="$result_dir/wivu.sql"
results_wivu_l="$result_dir/wivu.lst"
results_westm_fl_s="$result_dir/westm.sql"
results_westm_l="$result_dir/westm.lst"
results_wivu_fl_sf1="$result_dir/wivu-features.sql"
results_wivu_fl_sf2="$result_dir/wivu-features-cross.sql"
results_wivu_fl_si="$result_dir/wivu-features.lst"
results_wivu_fl_m="$result_dir/hbible_txt_monads.xml"
results_wivu_fl_nt="$result_dir/wivu-normal.txt"
results_westm_fl_nt="$result_dir/westm-normal.txt"

query_sc="./qrall.pl"
query_body="../queries/philo/bhs"
query_results="../queries/philo/results"
query_sqlc="./oannot_create.sql"
query_sql="../results/oannot.sql"

# mquery verse structure from wivu

echo "=== mql query for verses ... "
if
	 [ -e $verses_fl ] && [ $verses_fl -nt $verses_qu ]
then
	echo "using previous $verses_fl"
else
	echo "creating new $verses_fl"
	mql -b 3 -d $datawivu $verses_qu > $verses_fl
fi

# mquery words from wivu

echo "=== mql query for words (text) ... "
if
	[ -e $words_text_fl ] && [ $words_text_fl -nt $words_text_qu ]
then
	echo "using previous $words_text_fl"
else
	echo "creating new $words_text_fl"
	mql -b 3 -d $datawivu $words_text_qu > $words_text_fl
fi

# ordering verses from wivu 

echo "=== formatting verses list ..."
if
	[ -e $verses_fl_n ] && [ $verses_fl_n -nt $verses_fl ] && [ $verses_fl_n -nt $verses_sc ]
then
	echo "using previous $verses_fl_n"
else
	echo "creating new $verses_fl_n"
	$verses_sc $verses_fl $verses_fl_n
fi

# ordering words from wivu
echo "=== formatting word list (text) ..."
if
	[ -e $words_text_fl_n ] && [ $words_text_fl_n -nt $words_text_fl ] && [ $words_text_fl_n -nt $words_text_sc ]
then
	echo "using previous $words_text_fl_n"
else
	echo "creating new $words_text_fl_n"
	$words_text_sc $words_text_fl $words_text_fl_n
fi

# making wivu xml text

echo "=== combining words (text) and verses into xml-with-monads file"
if
	[ -e $results_wivu_fl_m ] && [ $results_wivu_fl_m -nt $words_text_fl_n ] && [ $results_wivu_fl_m -nt $verses_fl_n ] && [ $results_wivu_fl_m -nt $results_sc ]
then
	echo "using previous $results_wivu_fl_m"
else
	echo "creating new $results_wivu_fl_m"
	$results_sc $verses_fl_n $words_text_fl_n $results_wivu_fl_m
fi

# generating wivu normalised text

echo "=== generating wivu normalized text"
if
	[ -e $results_wivu_fl_nt ] && [ $results_wivu_fl_nt -nt $results_wivu_fl_m ] && [ $results_wivu_fl_nt -nt $results_wivu_sc ]
then
	echo "using previous $results_wivu_fl_nt"
else
	echo "creating new $results_wivu_fl_nt"
	$results_wivu_sc $results_wivu_fl_m $results_wivu_fl_nt
fi

# ordering words from westminster

echo "=== transforming westminster txt file"
if
	[ -e $words_westm_fl ] && [ $words_westm_fl -nt $datawestm ] && [ $words_westm_fl -nt $words_westm_sc ]
then
	echo "using previous $words_westm_fl"
else
	echo "creating new $words_westm_fl"
	$words_westm_sc $datawestm $words_westm_fl
fi

# generating westm normalised text

echo "=== generating westminster normalized text"
if
	[ -e $results_westm_fl_nt ] && [ $results_westm_fl_nt -nt $words_westm_fl ] && [ $results_westm_fl_nt -nt $results_westm_sc ]
then
	echo "using previous $results_westm_fl_nt"
else
	echo "creating new $results_westm_fl_nt"
	$results_westm_sc $words_westm_fl $results_westm_fl_nt
fi

# generating aligned text

echo "=== generating aligned text"
if
	[ -e $alignment_l ] && [ $alignment_l -nt $results_wivu_fl_nt ] && [ $alignment_l -nt $results_westm_fl_nt ] && [ $alignment_l -nt $alignment_sc ]
then
	echo "using previous $alignment_l"
else
	echo "creating new $alignment_l"
	$alignment_sc $results_wivu_fl_nt $results_westm_fl_nt $alignment_l
fi

exit;

# generating wivu anchors

echo "=== generating wivu anchors file"
if
	[ -e $anchors_wivu_l ] && [ $anchors_wivu_l -nt $results_wivu_fl_m ] && [ $anchors_wivu_l -nt $anchors_wivu_sc ]
then
	echo "using previous $anchors_wivu_l"
else
	echo "creating new $anchors_wivu_l"
	$anchors_wivu_sc $results_wivu_fl_m $anchors_wivu_l
fi

# generating westm anchors

echo "=== generating westm anchors file"
if
	[ -e $anchors_westm_l ] && [ $anchors_westm_l -nt $words_westm_fl ] && [ $anchors_westm_l -nt $anchors_westm_sc ]
then
	echo "using previous $anchors_westm_l"
else
	echo "creating new $anchors_westm_l"
	$anchors_westm_sc $words_westm_fl $anchors_westm_l
fi

# generating alignment

echo "=== generating aligned anchors"
if
	[ -e $alignment_l ] && [ $alignment_l -nt $anchors_wivu_l ] && [ $alignment_l -nt $anchors_westm_l ] && [ $alignment_l -nt $alignment_sc ]
then
	echo "using previous $alignment_l"
else
	echo "creating new $alignment_l"
	$alignment_sc $anchors_wivu_l $anchors_westm_l $alignment_l
fi

# generating anchors based on alignment

echo "=== generating anchors based on alignment"
if
	[ -e $alignment_la ] && [ $alignment_la -nt $alignment_l ] && [ $alignment_la -nt $anchors_sc ]
then
	echo "using previous $alignment_l"
else
	echo "creating new $alignment_l"
	$anchors_sc $alignment_l $alignment_la
fi

# generating wivu sql

echo "=== transforming xml-with-monads file into sql file"
if
	[ -e $results_wivu_fl_s ] && [ $results_wivu_fl_s -nt $results_wivu_fl_m ] && [ $results_wivu_fl_s -nt $results_wivu_sq ] && [ $results_wivu_fl_s -nt $source_sqc ] && [ -e $results_fl_a ] && [ $results_fl_a -nt $results_wivu_fl_m ] && [ $results_fl_a -nt $results_wivu_sq ]
then
	echo "using previous $results_wivu_fl_s and $results_fl_a"
else
	echo "creating new $results_wivu_fl_s and $results_fl_a"
	$results_wivu_sq $source_sqc $results_wivu_fl_m $results_wivu_fl_s $results_fl_a $results_wivu_l
fi

# generating westm sql

echo "=== generating westminster sql file"
if
	[ -e $results_westm_fl_s ] && [ $results_westm_fl_s -nt $words_westm_fl ] && [ $results_westm_fl_s -nt $results_westm_sq ] && [ $results_westm_fl_s -nt $source_sqc ]
then
	echo "using previous $results_westm_fl_s"
else
	echo "creating new $results_westm_fl_s"
	$results_westm_sq $source_sqc $words_westm_fl $results_westm_fl_s $results_westm_l
fi

# generating queries sql

echo "=== transforming queries into sql file"
cp $query_sqlc $query_sql
$query_sc $datawivu $results_fl_a $query_body $query_results $query_sql

echo "=== mql query for words (feature) ... "
if
	[ -e $words_feature_fl ] && [ $words_feature_fl -nt $words_feature_qu ]
then
	echo "using previous $words_feature_fl"
else
	echo "creating new $words_feature_fl"
	mql -b 3 -d $datawivu $words_feature_qu > $words_feature_fl
fi

# ordering wivu features

echo "=== formatting word list (feature) ..."
if
	[ -e $words_feature_fl_n ] && [ $words_feature_fl_n -nt $words_feature_fl ] && [ $words_feature_fl_n -nt $results_fl_a ] && [ $words_feature_fl_n -nt $words_feature_sc ]
then
	echo "using previous $words_feature_fl_n"
else
	echo "creating new $words_feature_fl_n"
	$words_feature_sc $results_fl_a $words_feature_fl $words_feature_fl_n
fi

# generating wivu features sql

echo "=== transforming word-with-features file into sql file"
if
	[ -e $results_wivu_fl_sf1 ] && [ $results_wivu_fl_sf1 -nt $words_feature_fl_n ] && [ $results_wivu_fl_sf1 -nt $results_sqf ] && [ -e $results_wivu_fl_sf2 ] && [ $results_wivu_fl_sf2 -nt $words_feature_fl_n ] && [ $results_wivu_fl_sf2 -nt $results_sqf ] && [ $results_wivu_fl_si -nt $results_sqf ]
then
	echo "using previous $results_wivu_fl_sf1 and $results_wivu_fl_sf2"
else
	echo "creating new $results_wivu_fl_sf1 and $results_wivu_fl_sf2"
	$results_sqf $words_feature_fl_n $results_wivu_fl_sf1 $results_wivu_fl_sf2 $results_wivu_fl_si
fi

