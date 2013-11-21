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
    
default_corpus = 1
default_letter = 1

word_weight_high = 20
word_weight_low = 10

topic_no_weight = 0.5

interface_paginate = 50

def index():
    """
    example action using the internationalization operator T and flash
    rendered by views/default/index.html or views/generic.html
    """
    
    letters = ""
    lettertext = ""
    letterhead = None

    keywords = ()
    topics = ()
    topicids = ()
    topicwords = {}
    topicclass = {}

    lid = request.args(0)
    tletterids = None

    chosenitem = None
    chosentype = None
    chosensubtype = None

    if lid == None:
        therecords = db1.letter
        chosenitem = request.vars.chosenitem
        chosentype = request.vars.chosentype
        chosensubtype = request.vars.chosensubtype
        if chosenitem:
            cond = " annot.bodytext "
            if chosentype == 'topic':
                cond = " annot.bodyref "
            lettersql = '''
select
    target.anchor 
from
    target
inner join
    annot on target.annot_id = annot.id
where
    annot.metatype = '%s'
and
    annot.metasubtype = '%s'
and
    %s = '%s'
order by
    annot.bodyinfo desc, annot.bodytext
;
            ''' % (chosentype, chosensubtype, cond, chosenitem)

            tletterids = map(lambda x:x[0], db2.executesql(lettersql))
            therecords = reduce(lambda x,y:x|y,map(lambda x: db1.letter.m_id == x[0], db2.executesql(lettersql)))

        letters = SQLFORM.grid(therecords,
            user_signature=False,
            field_id=db1.letter.id,
            fields=[
                db1.letter.m_id,
                db1.letter.m_date,
                db1.letter.m_lang,
                db1.letter.m_sender,
                db1.letter.m_senderloc,
                db1.letter.m_recipient,
                db1.letter.m_recipientloc,
            ],
            editable=False,
            deletable=False,
            create=False,
            details=False,
            csv=False,
            showbuttontext=False,
            paginate=interface_paginate
        )

# cases:
#  lid = None and tletterids = None: show all letters and all topics
#  lid = None and tletterids is a list: show letters in letterids and all topics of those letters
#  lid != None: show that letter and all topics of that letter

    if lid != None:
        chunks = db1.executesql('''
select content
from contentchunk
where letter_id = %s
order by seq
''' % (lid))
        head = db1.executesql('''
select m_id, m_date, m_lang, m_sender, m_senderloc, m_recipient, m_recipientloc
from letter
where id = %s
''' % (lid))

        thistext = "".join(map(lambda x: x[0], chunks))
        wpat = re.compile(r'<lb/>')
        thistext = wpat.sub('<br/>', thistext)

        fpat = re.compile(r'<\/?figure>')
        thistext = fpat.sub('', thistext)

        gpat = re.compile(r'<graphic url="([^"]*)"><\/graphic>')
        thistext = gpat.sub('<img src="\g<1>" alt="\g<1>"/>', thistext)

        hbpat = re.compile(r'<hi rend')
        thistext = hbpat.sub('<span class', thistext)

        hepat = re.compile(r'<\/hi>')
        thistext = hepat.sub('</span>', thistext)

        rpat = re.compile(r'<(\/?)row>')
        thistext = rpat.sub('<\g<1>tr>', thistext)

        chpat = re.compile(r'<cell role="header">(.*?)<\/cell>')
        thistext = chpat.sub('<th>\g<1></th>', thistext)

        ccpat = re.compile(r'<cell cols="([0-9]+)">(.*?)<\/cell>')
        thistext = ccpat.sub('<td colspan="\g<1>">\g<2></td>', thistext)

        cpat = re.compile(r'<(\/?)cell>')
        thistext = cpat.sub('<\g<1>td>', thistext)

        ppat = re.compile(r'<persName[^>]*>(.*?)<\/persName>')
        thistext = ppat.sub('<span class="persName">\g<1></span>', thistext)

        letterhead = {
            'id':head[0][0],
            'date':head[0][1],
            'lang':head[0][2],
            'sender':head[0][3],
            'senderloc':head[0][4],
            'recipient':head[0][5],
            'recipientloc':head[0][6],
        }

        lettertext = XML(thistext)

    topicsql = ''
    keywordsql = ''

    if lid == None:
        if tletterids == None:
            topicsql = '''
select
    distinct 0, annot.metaresearcher, annot.bodyref, %d
from
    annot
where
    annot.metatype = 'topic'
and
    annot.metasubtype = 'auto'
;
            ''' % (topic_no_weight)
            keywordsql = '''
select
    distinct 0, annot.metaresearcher, annot.bodytext
from
    annot
where
    annot.metatype = 'keyword'
and
    annot.metasubtype = '%s'
order by annot.bodytext
;
            '''

        else:
            topicsql = '''
select
    distinct 0, annot.metaresearcher, annot.bodyref, %d
from
    target
inner join
    annot on target.annot_id = annot.id
where
    annot.metatype = 'topic'
and
    annot.metasubtype = 'auto'
and
    target.anchor in ('%s')
;
            ''' % (topic_no_weight, "','".join(tletterids))
            keywordsql = '''
select
    distinct 0, annot.metaresearcher, annot.bodytext
from
    target
inner join
    annot on target.annot_id = annot.id
where
    annot.metatype = 'keyword'
and
    annot.metasubtype = '%s'
and
    target.anchor in ('%s')
order by annot.bodytext
;
            ''' % ('%s', "','".join(tletterids))

    else:
        topicsql = '''
select
    distinct annot.id, annot.metaresearcher, annot.bodyref, annot.bodyinfo
from
    target
inner join
    annot on target.annot_id = annot.id
where
    annot.metatype = 'topic'
and
    annot.metasubtype = 'auto'
and
    target.anchor = '%s'
order by annot.bodyinfo desc
;
        ''' % (letterhead['id'])
        keywordsql = '''
select
    distinct annot.id, annot.metaresearcher, annot.bodytext
from
    target
inner join
    annot on target.annot_id = annot.id
where
    annot.metatype = 'keyword'
and
    annot.metasubtype = '%s'
and
    target.anchor = '%s'
order by annot.bodytext
;
        ''' % ('%s', letterhead['id'])

    keywordsauto = []
    if lid != None or tletterids != None:
        keywordsauto = db2.executesql(keywordsql % ('auto'))
    keywordsmanual = []
    keywordsmanual = db2.executesql(keywordsql % ('manual'))
    topics = []
    topics = db2.executesql(topicsql)

    if len(topics) > 0:

        topicids = map(lambda x:x[2],topics)
        for t in topics:
            topicclass[str(t[2])] = '%.0f' % (float(t[3]) * 5)

        topicwordsqltemplate = '''
select
    tw.topic_id, tw.weight, word.word
from
    topic_word as tw
inner join
    word on tw.word_id = word.id
%s
order
    by tw.weight desc, word.word
;
        '''
        if lid == None and tletterids == None:
            topicwordsql = topicwordsqltemplate % ('')
        else:
            topicwordsql = topicwordsqltemplate % (' where tw.topic_id in (' + ",".join(map(lambda x:str(x), topicids)) + ')')

        topicwordspre = db3.executesql(topicwordsql)

        for item in topicwordspre:
            (tid, weight, word) = item
            wclass = 3 if weight >= word_weight_high else 2 if weight >= word_weight_low else 1
            if tid in topicids:
                if not str(tid) in topicwords:
                    topicwords[str(tid)] = []
                topicwords[str(tid)].append((word,weight,topicclass[str(tid)],str(wclass)))

    return dict(letters=letters,lid=lid,text=lettertext,head=letterhead,keywordsauto=keywordsauto,keywordsmanual=keywordsmanual,topics=topics,topicids=topicids,topicwords=topicwords,topicclass=topicclass,chosenitem=chosenitem,chosentype=chosentype,chosensubtype=chosensubtype)

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
