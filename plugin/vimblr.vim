if !has('python')
    echo "Error: You must have vim compiled with +python"
    finish
endif

python << EOF
import vim, urllib, base64, hmac, time, hashlib, httplib, json, urlparse

consumer_key = 'consumer_key'
secret_key = 'secret_key' 
oauth_token = 'oauth_token'
oauth_token_secret =  'token_secret' 

def parse(url):
    p = urlparse.urlparse(url)
    return (p.netloc,p.netloc,p.path) 

def oauth_sig(method,uri,params):
    """
    Creates the valid OAuth signature.
    """
    #eg: POST&http%3A%2F%2Fapi.tumblr.com%2Fv2%2Fblog%2Fexample.tumblr.com%2Fpost
    s = method + '&'+ urllib.quote(uri).replace('/','%2F')+ '&' + '%26'.join(
        #escapes all the key parameters, we then strip and url encode these guys
        [urllib.quote(k) +'%3D'+ urllib.quote(params[k]).replace('/','%2F') for k in sorted(params.keys())]
    )
    s = s.replace('%257E','~')
    return urllib.quote(base64.encodestring(hmac.new(secret_key + "&"+oauth_token_secret,s,hashlib.sha1).digest()).strip())

def oauth_gen(method,url,iparams,headers):
    """
    Creates the oauth parameters we're going to need to sign the body
    """
    params = dict([(x[0], urllib.quote(str(x[1])).replace('/','%2F')) for x in iparams.iteritems()]) 
    params['oauth_consumer_key'] = consumer_key
    params['oauth_nonce'] = str(time.time())[::-1]
    params['oauth_signature_method'] = 'HMAC-SHA1'
    params['oauth_timestamp'] = str(int(time.time()))
    params['oauth_version'] = '1.0'
    params['oauth_token']= oauth_token
    params['oauth_signature'] = oauth_sig(method,'http://'+headers['Host'] + url, params)
    headers['Authorization' ] =  'OAuth ' + ',  '.join(['%s="%s"' %(k,v) for k,v in params.iteritems() if 'oauth' in k ])

def postOAuth(url,params={}):
    """
    Does the actual posting. Content-type is set as x-www-form-urlencoded
    Everything url-encoded and data is sent through the body of the request.
    """
    (machine,host,uri) = parse(url)
    headers= {'Host': host,"Content-type": 'application/x-www-form-urlencoded'}
    oauth_gen('POST',uri,params,headers)
    conn = httplib.HTTPConnection(machine)
    #URL Encode the paramers and  make sure and kill any trailing slashes.
    conn.request('POST',uri,urllib.urlencode(params).replace('/','%2F'),headers);
    return conn.getresponse()

def create(blogname,title):
    params = {}
    params['title'] = title
    params['body'] = " ".join(vim.current.buffer)
    params['type'] = "text"
    url = 'http://api.tumblr.com/v2/blog/%s/post' % blogname 
    print _resp(postOAuth(url,params),201)

def _resp(resp,code=200):
    if resp.status != code: 
        raise Exception('response code is %d - %s' % (resp.status,resp.read()));
    return json.loads(resp.read())['response']
EOF
command -nargs=* VimblrPost :python create(<f-args>)
