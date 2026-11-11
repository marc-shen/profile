#!/usr/bin/env python3
"""Local-only Clash subscription composition and Steam Deck proxy management."""
import copy
import gzip
import json
import os
from pathlib import Path
import pwd
import subprocess as sp
import tarfile
import time
import urllib.request

REPO = Path(__file__).resolve().parents[1]


def compose(provider, root, address):
    config = copy.deepcopy(provider)
    if not isinstance(config, dict) or not config.get('rules') or not config.get('proxy-groups'):
        raise RuntimeError('Expected a complete Clash configuration with rules and proxy groups')
    # The vendor retains ownership of proxy selection, rule order and groups.
    bypass = [f'PROCESS-NAME,{p},DIRECT' for p in ('tailscaled','tailscale','steamcommunity_302.cli','steamcommunity_302.caddy','caddy')]
    bypass += ['DOMAIN-SUFFIX,ts.net,DIRECT','DOMAIN-SUFFIX,tailscale.com,DIRECT','DOMAIN-SUFFIX,tailscale.io,DIRECT',
               'IP-CIDR,100.64.0.0/10,DIRECT,no-resolve','IP-CIDR6,fd7a:115c:a1e0::/48,DIRECT,no-resolve',
               'IP-CIDR,127.0.0.0/8,DIRECT,no-resolve','IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
               'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve','IP-CIDR,192.168.0.0/16,DIRECT,no-resolve']
    config['rules'] = bypass + config['rules']
    for key in ('external-controller-tls','external-controller-unix','external-controller-pipe','external-ui-url','listeners','redir-port','tproxy-port','port','socks-port'):
        config.pop(key, None)
    config.update({'mixed-port':2080,'allow-lan':False,'bind-address':'127.0.0.1','mode':'rule',
                   'external-controller':'0.0.0.0:9090','external-ui':str(root/'apps/metacubexd/current'),
                   'secret':'','external-controller-cors':{'allow-origins':list(dict.fromkeys(['http://'+address+':9090','http://127.0.0.1:9090','http://localhost:9090'])),'allow-private-network':True},
                   'find-process-mode':'always','log-level':'info'})
    config['tun']={'enable':True,'device':'mihomo-tun','stack':'mixed','auto-route':True,'auto-redirect':True,
                   'auto-detect-interface':True,'strict-route':False,'dns-hijack':['any:53','tcp://any:53'],
                   'route-exclude-address':['100.64.0.0/10','fd7a:115c:a1e0::/48','127.0.0.0/8','::1/128','10.0.0.0/8','172.16.0.0/12','192.168.0.0/16'],
                   'exclude-interface':['tailscale0']}
    dns=config.setdefault('dns',{})
    dns.update({'enable':True,'listen':'127.0.0.1:1053','use-hosts':True,'use-system-hosts':True})
    dns.setdefault('nameserver-policy',{})['+.ts.net']='100.100.100.100'
    dns['fake-ip-filter']=list(dict.fromkeys(dns.get('fake-ip-filter',[])+['*.ts.net','*.tailscale.com','*.tailscale.io']))
    config.setdefault('profile',{})['store-selected']=True
    return config


def ensure_yaml(root, action):
    try:
        import yaml
        return True
    except ImportError:
        runtime=root/'data/mihomo-helper';python=runtime/'bin/python'
        if not python.exists():sp.run([root/'bin/uv','venv','--python','3.13',runtime],check=True)
        sp.run([root/'bin/uv','pip','install','--python',python,'PyYAML==6.0.2'],check=True)
        sp.run([python,REPO/'libexec/deck_network.py','--prefix',root,'mihomo',action],check=True)
        return False


def refresh_config(root, refresh=False):
    """Validate before replacing either local subscription or live configuration."""
    import yaml
    from deck_network import write, tailscale_ip
    folder=root/'config/mihomo'
    data=None
    if refresh or not (folder/'provider.yaml').exists():
        url=(folder/'subscription.url').read_text().strip()
        try:
            request=urllib.request.Request(url,headers={'User-Agent':'clash.meta'})
            with urllib.request.urlopen(request,timeout=60) as reply:data=reply.read().decode()
            provider=yaml.safe_load(data)
            compose(provider,root,tailscale_ip())
        except Exception as error:
            raise RuntimeError('Subscription fetch/validation failed; old configuration retained ('+type(error).__name__+')') from None
    else:
        provider=yaml.safe_load((folder/'provider.yaml').read_text())
    config=compose(provider,root,tailscale_ip())
    candidate=folder/'candidate.yaml';write(candidate,yaml.safe_dump(config,allow_unicode=True,sort_keys=False),0o600)
    env=dict(os.environ,SAFE_PATHS=str(root/'apps'))
    with (folder/'validation.log').open('w') as log:
        result=sp.run([root/'apps/mihomo/current/mihomo','-t','-d',folder,'-f',candidate],env=env,stdout=log,stderr=sp.STDOUT,timeout=120)
    if result.returncode:raise RuntimeError('Mihomo validation failed; old configuration retained; see local config/mihomo/validation.log')
    target=folder/'config.yaml'
    changed=not target.exists() or target.read_bytes()!=candidate.read_bytes()
    candidate.replace(target)
    if data is not None:write(folder/'provider.yaml',data,0o600)
    print('Prepared:',len(provider.get('proxies',[])),'nodes,',len(provider['proxy-groups']),'vendor groups,',len(provider['rules']),'vendor rules')
    return changed


def install_update_timer(root):
    from deck_network import write
    units=Path.home()/'.config/systemd/user'
    write(units/'mihomo-subscription-update.service',f'''[Unit]
Description=Refresh Mihomo subscription and apply validated configuration
ConditionPathExists={root / 'config/mihomo/subscription.url'}
[Service]
Type=oneshot
UMask=0077
ExecStart="{root / 'bin/workbench'}" network update mihomo
TimeoutStartSec=8min
''')
    write(units/'mihomo-subscription-update.timer','''[Unit]
Description=Daily Mihomo subscription update
[Timer]
OnCalendar=*-*-* 04:00:00
RandomizedDelaySec=10min
Persistent=true
[Install]
WantedBy=timers.target
''')
    sp.run(['systemctl','--user','daemon-reload'],check=True)
    sp.run(['systemctl','--user','enable','--now','mihomo-subscription-update.timer'],check=True)


def daily_update(root):
    if not ensure_yaml(root,'update'):return
    os.umask(0o077)
    folder=root/'config/mihomo'
    previous={name:(folder/name).read_bytes() if (folder/name).exists() else None
              for name in ('config.yaml','provider.yaml')}
    active=sp.run(['systemctl','--user','is-active','--quiet','mihomo']).returncode==0
    try:
        changed=refresh_config(root,True)
    except Exception:
        restore_config(folder,previous)
        raise
    if not changed or not active:
        print('Subscription checked; configuration unchanged or service intentionally inactive. No restart.')
        return
    try:
        sp.run(['systemctl','--user','restart','mihomo'],check=True,timeout=45)
        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
        for i in range(20):
            try:
                with opener.open('http://127.0.0.1:9090/version',timeout=2) as reply:
                    if reply.status==200 and Path('/sys/class/net/mihomo-tun').exists():break
            except Exception:pass
            time.sleep(1)
        else:raise RuntimeError('Updated controller failed its health check')
    except Exception:
        restore_config(folder,previous)
        result=sp.run(['systemctl','--user','restart','mihomo'],timeout=45)
        raise RuntimeError('Update activation failed; previous configuration restored; recovery restart exit='+str(result.returncode)) from None
    print('Subscription updated and Mihomo restarted successfully.')


def restore_config(folder, previous):
    for name,data in previous.items():
        target=folder/name
        if data is None:target.unlink(missing_ok=True)
        else:
            temporary=target.with_suffix('.restore')
            temporary.write_bytes(data);temporary.chmod(0o600);temporary.replace(target)


def prepare(root):
    if not ensure_yaml(root,'prepare'):return
    from deck_network import archive, link, load, write, tailscale_ip
    os.umask(0o077)
    specs=load(REPO/'catalog/mihomo.json')
    for name,spec in specs.items():
        app=root/'apps'/name/spec['version'];app.mkdir(parents=True,exist_ok=True)
        if not (app/('mihomo' if name=='mihomo' else 'index.html')).exists():
            source=archive(root,spec)
            if name=='mihomo':
                binary=app/'mihomo';binary.write_bytes(gzip.decompress(source.read_bytes()));binary.chmod(0o755)
                sp.run([binary,'-v'],check=True,stdout=sp.DEVNULL)
            else:
                with tarfile.open(source) as tar:tar.extractall(app,filter='data')
        link(app,root/'apps'/name/'current',root)
    # The dashboard and API share an origin on both localhost and Tailscale.
    write(root/'apps/metacubexd/current/config.js',
          'window.__METACUBEXD_CONFIG__ = {defaultBackendURL: window.location.origin};\n')
    folder=root/'config/mihomo';folder.mkdir(parents=True,exist_ok=True);folder.chmod(0o700)
    if not (folder/'provider.yaml').exists() and not (folder/'subscription.url').exists():
        install_update_timer(root)
        print('Clients installed. Put your subscription URL in config/mihomo/subscription.url (mode 600), then run workbench network install mihomo.')
        return
    refresh_config(root)
    unit=f'''[Unit]
Description=Mihomo proxy with MetaCubeXD
After=network-online.target
[Service]
Type=simple
UMask=0077
Environment="SAFE_PATHS={root / 'apps'}"
ExecStartPre=/usr/bin/systemctl is-active --quiet profile-mihomo-firewall.service
ExecStartPre=/usr/bin/grep -Fq "tcp dport 9090 drop" /etc/profile-mihomo/firewall.nft
ExecStart={root / 'apps/mihomo/current/mihomo'} -d {folder} -f {folder / 'config.yaml'}
Restart=on-failure
RestartSec=5
[Install]
WantedBy=default.target
'''
    write(Path.home()/'.config/systemd/user/mihomo.service',unit)
    install_update_timer(root)
    if sp.run(['systemctl','--user','is-active','--quiet','mihomo']).returncode:
        print('Run workbench network apply mihomo in local Konsole for one-time administrator setup.')
    else:
        print('Running service preserved; restart mihomo when ready to apply configuration changes.')


def activate(root):
    from deck_network import tailscale_ip,write,load
    if os.environ.get('SSH_CONNECTION'):raise RuntimeError('Run activate in the local Deck Konsole')
    sp.run(['sudo','bash',REPO/'platforms/steamdeck/network/mihomo-privileged.sh',root,pwd.getpwuid(os.getuid()).pw_name],check=True)
    try:
        sp.run(['systemctl','--user','restart','mihomo'],check=True)
        # Avoid proxy environment variables when testing the local controller.
        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
        for i in range(30):
            try:
                with opener.open('http://'+tailscale_ip()+':9090/version',timeout=2) as reply:
                    if reply.status==200 and Path('/sys/class/net/mihomo-tun').exists():break
            except Exception:time.sleep(1)
        else:raise RuntimeError('Mihomo controller did not become healthy')
    except Exception:
        sp.run(['systemctl','--user','stop','mihomo'])
        raise
    sp.run(['systemctl','--user','enable','mihomo'],check=True)
    local=root/'config/local/deck-network.json';settings=load(local,{})
    settings['backend']='mihomo';write(local,json.dumps(settings)+'\n',0o600)
    print('Active: http://'+tailscale_ip()+':9090/ui/ (Tailscale only, no password)')
