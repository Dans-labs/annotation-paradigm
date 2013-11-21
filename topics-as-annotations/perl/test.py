#!/usr/bin/python

words = (('a',293),('b',85),('c',40))
twords = map(lambda x:(x[0],x[1], 3 if x[1] > 90 else 2 if x[1] > 50 else 1), words)
for w in twords:
    print w[0]+" "+str(w[1])+" "+str(w[2])+"\n"
