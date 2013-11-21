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

default_corpus = 1
default_letter = 1

def index():
    """
    example action using the internationalization operator T and flash
    rendered by views/default/index.html or views/generic.html
    """
    
    letters = SQLFORM.grid(db1.letter,
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
        headers={
            'letter.m_id':'id',
            'letter.m_date':'date',
            'letter.m_lang':'lang',
            'letter.m_sender':'sender',
            'letter.m_senderloc':'senderloc',
            'letter.m_recipient':'recipient',
            'letter.m_recipientloc':'recipientloc',
        },
        editable=False,
        deletable=False,
        create=False,
        details=False,
        showbuttontext=False
    )

    return dict(letters=letters)

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
