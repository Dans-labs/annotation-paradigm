#!/bin/sh

source="$1"
otype="application/xml"
result="$1.xml"
demoserver="http://gregor.middell.net/collatex/api/collate"
localserver="http://localhost:8080/collatex-web-1.1/api/collate"
collatex="$localserver"

curl --header 'Content-Type: application/json;charset=UTF-8;' --header "Accept: $otype;" --data @$source $collatex > $result
