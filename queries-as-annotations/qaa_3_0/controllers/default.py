# -*- coding: utf-8 -*-
# this file is released under public domain and you can use without limitations

#########################################################################
## This is a samples controller
## - index is the default action of any application
## - user is required for authentication and authorization
## - download is for downloading files uploaded in the db (does streaming)
## - call exposes all registered services (none by default)
#########################################################################

import cPickle

import re
import string
    
wpat = re.compile(r'<(\/?)w')

default_book = 1
default_chapter = 24

def index():
    """
    example action using the internationalization operator T and flash
    rendered by views/default/index.html or views/generic.html
    """

    booklist = []
    if not session.booklist :
        booklist = db1.executesql('''
select

id,name,

(select

max(chapter_num)

from

chapter

where

book_id = book.id

)
from book;
        ''')
        session.booklist = cPickle.dumps(booklist)
    else:
        booklist = cPickle.loads(session.booklist)

    annotlist = {}
    if not session.annotlist :
        annottable = db2.executesql('''
select annot_meta.annot_id, metarecord.annot_type from
annot_meta inner join metarecord
on annot_meta.metarecord_id = metarecord.id
;
        ''')
        for result in annottable:
            (aid, atype) = result
            if not(atype in annotlist):
                annotlist[atype] = []
            annotlist[atype].append(aid)
        session.annotlist = cPickle.dumps(annotlist)
    else:
        annotlist = cPickle.loads(session.annotlist)
    
    book=0
    chapter=0
    chapterid=0
    vresult=[]
    verseids=[]
    versetext=[]
    wordlist = []
    features = {}
    featureshl = {}
    if not session.features:
        sqlcmd2 = '''
            select
            body.text, annot_body.annot_id from
            body inner join annot_body
            on annot_body.body_id = body.id
            where annot_body.annot_id in
        '''
        sqlcmd2 += "(" + ", ".join(map(lambda x: str(x), annotlist['feature'])) + ");"
        items = db2.executesql(sqlcmd2)
        for item in items:
            name = item[0].partition('=')[0]
            value = item[0].partition('=')[2]
            id = item[1]
            if not(name in features):
                features[name] = {}
            features[name][value] = id
        session.features = cPickle.dumps(features)
    else:
        features = cPickle.loads(session.features)

    if request.vars.chapter:
        book=request.vars.book
        chapter=request.vars.chapter
    else:
        book = default_book
        chapter = default_chapter

    chresult = db1.executesql('''
    select id from chapter
    where
        book_id = ''' + str(book) + ''' and
        chapter_num = ''' + str(chapter) + ''';
    ''')
    chapterid=chresult[0][0]
    vresult = db1.executesql('''
    select id, verse_num, text from verse
    where chapter_id = ''' + str(chapterid) + '''
    order by verse_num;
    ''')
    versetext = map(lambda x: (x[1], wpat.sub('<\g<1>span', x[2])), vresult)
    verseids = map(lambda x: x[0], vresult)

    sqlcmd1 = '''
select anchor from word_verse where verse_id in
        '''
    sqlcmd1 += "(" + ", ".join(map(lambda x: str(x), verseids)) + ")"
    wordlist = db1.executesql(sqlcmd1)
    wordlist = map(lambda x: x[0], wordlist)
    session.wordlist = cPickle.dumps(wordlist)

    session.queryids = []

    sqlcmd4templ = string.Template('''
select
    annot_target.annot_id,
    target.anchor
from
    annot_target
inner join
    target
on
    annot_target.target_id = target.id
where
    annot_target.annot_id in ($annotids) and
    target.anchor in ($anchors);
    ''')
    sqlcmd4 = sqlcmd4templ.substitute(dict(
        annotids=",".join(map(lambda x: str(x), annotlist['feature'])),
        anchors=",".join(map(lambda x: "'"+str(x)+"'", wordlist)),
    ))
    resulttable = db2.executesql(sqlcmd4)
    for (qid, wn) in resulttable:
        if not(str(qid) in featureshl):
            featureshl[str(qid)] = []
        featureshl[str(qid)].append(wn)

    return dict(book=book, chapter=chapter, chapterid=chapterid, verselist=versetext, booklist=booklist, wordlist=wordlist, features=features, featureshl=featureshl)

def user():
    """
    exposes:
    http://..../[app]/default/user/login
    http://..../[app]/default/user/logout
    http://..../[app]/default/user/register
    http://..../[app]/default/user/profile
    http://..../[app]/default/user/retrieve_password
    http://..../[app]/default/user/change_password
    use @auth.requires_login()
        @auth.requires_membership('group name')
        @auth.requires_permission('read','table name',record_id)
    to decorate functions that need access control
    """
    return dict(form=auth())

def formatquery(q):
    qx = map(lambda x: xmlescape(x, quote=True), q)
    t=string.Template('''
        <div class="queryitem">
            <span class="qemph">$researcher</span><br/>
            $datecr , $datern<br/>
            <span class="hmtext">$resqu</span><br/>
            <input type="checkbox" id="res$qid" onclick="qresults($qid)"/>highlight results;
            <a id="ctlm$qid" href="javascript:void(0)" onclick="showmore($qid,1)" style="display: inline;">more info</a>
            <a id="ctll$qid" href="javascript:void(0)" onclick="showmore($qid,0)" style="display: none;">less info</a>
            <div id="extra$qid" style="display: none; width: 100%;>
                <span class="hmtext">$desc</span><br/>
                <span class="hmtext">$pub</span></br>
                <pre><code>$body</code></pre>
            </div>
        </div>
    ''')
    return t.substitute(dict(qid=qx[0], researcher=qx[2], datecr=qx[3], datern=qx[4], resqu=qx[1], desc=qx[5], pub=qx[6], body=qx[7]))

def oannot():
    annotlist = {}
    if session.annotlist:
        annotlist = cPickle.loads(session.annotlist)
    else:
        annotlist = dict(query=[], feature=[])

    wordlist = []
    if session.wordlist:
        wordlist = cPickle.loads(session.wordlist)

    queryids = []
    if wordlist:
        if not session.queryids:
            sqlcmd2 = '''
    select distinct annot_target.annot_id
    from annot_target
    inner join target
    on target.id = annot_target.target_id
    where
        annot_target.annot_id in
    '''
            sqlcmd2 += "(" + ", ".join(map(lambda x: str(x), annotlist['query'])) + ")"
            sqlcmd2 += '''
    and
        target.anchor in
    '''
            sqlcmd2 += "(" + ",".join(map(lambda x: "'"+str(x)+"'", wordlist)) + ")"
            queryids = db2.executesql(sqlcmd2)
            queryids = map(lambda x: x[0], queryids)
        else:
            queryids = cPickle.loads(session.queryids)

    # now get body and metadata from the found queryids (=oannotids)
    querylist = []
    if queryids:
        sqlcmd3 = '''
    select
        annot_meta.annot_id, 
        metarecord.research_question,
        metarecord.researcher,
        metarecord.date_created,
        metarecord.date_run,
        metarecord.description,
        metarecord.publications,
        body.text
    from
        metarecord
    inner join
        annot_meta
    on
        metarecord.id = annot_meta.annot_id
    inner join 
        annot_body
    on
        annot_meta.annot_id = annot_body.annot_id
    inner join
        body
    on
        body.id = annot_body.body_id
    where
        annot_meta.annot_id in
        '''
        sqlcmd3 += "(" + ", ".join(map(lambda x: str(x), queryids)) + ")"
        querylist = db2.executesql(sqlcmd3)

    querresstr = ""
    jstr = ""
    if not querylist:
        querresstr = "No relevant queries"
    else:
        querresstr = "".join(map(formatquery, querylist))

        # now get query results from the found query ids (=oannotids)
        sqlcmd4templ = string.Template('''
    select
        annot_target.annot_id,
        target.anchor
    from
        annot_target
    inner join
        target
    on
        annot_target.target_id = target.id
    where
        annot_target.annot_id in ($annotids) and
        target.anchor in ($anchors);
        ''')
        sqlcmd4 = sqlcmd4templ.substitute(dict(
            annotids=",".join(map(lambda x: str(x), queryids)),
            anchors=",".join(map(lambda x: "'"+str(x)+"'", wordlist)),
        ))
        resulttable = db2.executesql(sqlcmd4)
        resultlist = {}
        for (qid, wn) in resulttable:
            if not(str(qid) in resultlist):
                resultlist[str(qid)] = []
            resultlist[str(qid)].append(wn)



        jstr += "var qhighlights = {};\n"
        for qid, wl in sorted(resultlist.items()):
            jstr += "qhighlights["+qid+"] = " + "[" + ",".join(map(lambda x: "'"+str(x)+"'",wl))+ "];\n"

    result = ""
    result += "<script language='javascript'>\n" + jstr + "</script>\n"
    result += "<p>" + querresstr + "</p>"
    return result

def download():
    """
    allows downloading of uploaded files
    http://..../[app]/default/download/[filename]
    """
    return response.download(request,db)


def call():
    """
    exposes services. for example:
    http://..../[app]/default/call/jsonrpc
    decorate with @services.jsonrpc the functions to expose
    supports xml, json, xmlrpc, jsonrpc, amfrpc, rss, csv
    """
    return service()


@auth.requires_signature()
def data():
    """
    http://..../[app]/default/data/tables
    http://..../[app]/default/data/create/[table]
    http://..../[app]/default/data/read/[table]/[id]
    http://..../[app]/default/data/update/[table]/[id]
    http://..../[app]/default/data/delete/[table]/[id]
    http://..../[app]/default/data/select/[table]
    http://..../[app]/default/data/search/[table]
    but URLs must be signed, i.e. linked with
      A('table',_href=URL('data/tables',user_signature=True))
    or with the signed load operator
      LOAD('default','data.load',args='tables',ajax=True,user_signature=True)
    """
    return dict(form=crud())
