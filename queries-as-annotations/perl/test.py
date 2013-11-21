#!/usr/bin/python

import string

def formatquery1(q):
    tq = map(lambda x: str(x), q)
    return '''
        <p>{2}</p>
        <p>{3} , {4}</p>
        <p class="htext">{1}</p>
        <hr/>
    '''.format(*tq)

def formatquery2(q):
    t=string.Template('''
        <p>{2}</p>
        <p>{3} , {4}</p>
        <p class="htext">{1}</p>
        <hr/>
    ''')
    return t.substitute(dict(researcher=q[2], datecr=q[3], datern=q[4], resqu=q[1]))

def formatquery(q):
    t=string.Template('''
        <p>$researcher<br/>
        $datecr , $datern<br/>
        <span class="htext">$resqu</span><br/>
        <input type="checkbox" id="res$qid" onclick="qresult($qid)"/> results</p>
        <hr/>
    ''')
    return t.substitute(dict(qid=q[0], researcher=q[2], datecr=q[3], datern=q[4], resqu=q[1]))

querylist = [
    (1,'rq1','rs1','dcr1','dlr1','desc1','pub1'),
    (2,'rq2','rs2','dcr2','dlr2','desc2','pub2'),
    (3,'rq3','rs3','dcr3','dlr3','desc3','pub3')
]

def oannot():
    # now get body and metadata from the found queryids (=oannotids)
    querresstr = "".join(map(formatquery, querylist))
    return querresstr

print oannot()

resulttable = [
    (7,12284),
    (7,12286),
    (13,11747),
    (13,11748),
    (13,11749),
    (13,11750),
    (18,12099),
    (18,12100),
    (18,12101),
    (18,12284),
    (18,12285),
    (18,12286),
]
resultlist = {}
for (qid, wn) in resulttable:
    if not(str(qid) in resultlist):
        resultlist[str(qid)] = []
    resultlist[str(qid)].append(wn)

print resultlist
