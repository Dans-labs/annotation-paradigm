#!/bin/sh

checkserver="http://gregor.middell.net/collatex/api/collate"
thisserver="http://localhost:7369/service/collate"

curl --verbose -X POST --header 'Content-Type: application/json;charset=UTF-8;' --header 'Accept: application/json' --data-binary '{"witnesses":[{"id" : "0142", "content":"επιστολη ιουδα του αποστολου"},{"id":"049", "content" : "του αγιου αποστολου ιουδα επιστολη"}],"algorithm": "dekker"}' $thisserver
