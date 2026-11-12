import json,re
def scalar(v):
 if isinstance(v,dict):return '{ '+', '.join(json.dumps(k,ensure_ascii=False)+' = '+scalar(x) for k,x in v.items())+' }'
 if isinstance(v,list):return '['+', '.join(scalar(x) for x in v)+']'
 return json.dumps(v,ensure_ascii=False)
def dumps(data):
 lines=[]
 def table(d,path=()):
  for k,v in d.items():
   if not isinstance(v,dict) and not (isinstance(v,list) and v and isinstance(v[0],dict)):
    lines.append((k if re.fullmatch('[A-Za-z0-9_-]+',k) else json.dumps(k,ensure_ascii=False))+' = '+scalar(v))
  for k,v in d.items():
   if isinstance(v,dict):
    lines.append('\n['+'.'.join((*path,k))+']');table(v,(*path,k))
   elif isinstance(v,list) and v and isinstance(v[0],dict):
    for item in v:
     lines.append('\n[['+'.'.join((*path,k))+']]');table(item,(*path,k))
 table(data);return '\n'.join(lines)+'\n'
