# Hidden web server — sirf PowerShell, koi EXE/DLL nahi.
# open-panel.ps1 se start hota hai.

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $scriptDir 'launcher-config.json'
$port = 8765
if (Test-Path $configFile) {
    try {
        $cfg = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.web_panel_port) { $port = [int]$cfg.web_panel_port }
    } catch { }
}
$stateDir = "$env:APPDATA\AnsariCheats"
$stateFile = "$stateDir\web_remote_state.json"
$urlFile = "$stateDir\remote.url"
$pidFile = "$stateDir\remote-server.pid"
$authRequestFile = "$stateDir\web_auth_request.json"
$authStatusFile = "$stateDir\web_auth_status.json"
$injectRequestFile = "$stateDir\inject_request.json"
$injectStatusFile = "$stateDir\inject_status.json"
$script:WebSessionAuthed = $false
$script:WebLoginPending = $false
$script:WebLoginStartedAt = $null
$configFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'launcher-config.json'

New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

function Get-LanIp {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
        Select-Object -First 1 -ExpandProperty IPAddress)
    if ($ip) { return $ip }
    return '127.0.0.1'
}

function Get-DefaultState {
    return @{
        stream_proof = $true
        aim_enable = $false
        aim_fov_draw = $false
        aim_fov = 100
        aim_range = 500
        aim_safe = $false
        aim_safe_delay = 0
        aim_type = 0
        ignore_knocked = $false
        no_recoil = $false
        fast_reload = $false
        esp_enable = $false
        esp_snaplines = $false
        esp_line_pos = 0
        esp_box = $false
        esp_health_bar = $false
        esp_health_pos = 2
        esp_name = $false
        esp_distance = $false
        esp_weapon_icon = $false
        esp_skeleton = $false
        esp_health_text = $false
        esp_weapon_text = $false
        esp_distance_slider = 300
        esp_refresh = $false
        loot_esp = $false
        loot_range = 300
        rapid_fire = $false
        fire_speed = 50
        sniper_scope = $false
        scope_target = 0
        speed_internal = $false
        spin_bot = $false
        spin_speed = 4.2
        snap_pull = $false
        pull_speed = 0
        pull_strength = 0.5
        limit_fps = $false
        max_fps = 60
        reduce_gpu = $true
        mute_beep = $false
    }
}

function Load-State {
    if (Test-Path $stateFile) {
        try {
            $raw = Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $state = Get-DefaultState
            $raw.PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value }
            return $state
        }
        catch { }
    }
    return Get-DefaultState
}

function Save-State($state) {
    $json = $state | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($stateFile, $json, (New-Object System.Text.UTF8Encoding $false))
}

function Reset-WebPanelState {
    $state = Get-DefaultState
    Save-State $state
    $offlineFlag = Join-Path $stateDir 'web_offline.flag'
    $clientAlive = Join-Path $stateDir 'web_client_alive.txt'
    Set-Content -Path $offlineFlag -Value (Get-Date -Format 'o') -Encoding UTF8
    if (Test-Path $clientAlive) {
        Remove-Item $clientAlive -Force -ErrorAction SilentlyContinue
    }
}

function Write-WebClientHeartbeat {
    Touch-WebClientSession
}

function Touch-WebClientSession {
    $clientAlive = Join-Path $stateDir 'web_client_alive.txt'
    Set-Content -Path $clientAlive -Value (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') -Encoding UTF8
    Clear-WebOfflineFlag
}

function Clear-WebOfflineFlag {
    $offlineFlag = Join-Path $stateDir 'web_offline.flag'
    if (Test-Path $offlineFlag) {
        Remove-Item $offlineFlag -Force -ErrorAction SilentlyContinue
    }
}

function Write-UrlInfo {
    $lan = Get-LanIp
    $mobile = "http://${lan}:$port"
    "pc=http://127.0.0.1:$port`nmobile=$mobile" | Set-Content -Path $urlFile -Encoding UTF8
}

function Get-SchemaJson {
    $controls = @(
        @{ id='stream_proof'; label='Stream Proof'; tab='Control'; type='setting' }
        @{ id='aim_enable'; label='Enable Aimbot'; tab='Aimbot'; type='bool' }
        @{ id='aim_fov_draw'; label='Draw Aim FOV'; tab='Aimbot'; type='bool' }
        @{ id='aim_fov'; label='Aim FOV'; tab='Aimbot'; type='float'; min=0; max=1000 }
        @{ id='aim_range'; label='Range'; tab='Aimbot'; type='float'; min=0; max=1000 }
        @{ id='aim_safe'; label='Aimbot Safe'; tab='Aimbot'; type='bool' }
        @{ id='aim_safe_delay'; label='Safe Delay (ms)'; tab='Aimbot'; type='float'; min=0; max=50 }
        @{ id='aim_type'; label='Aimbot Type'; tab='Aimbot'; type='combo'; options=@('Silent Aim','Aimbot Rage','Aimbot Visible') }
        @{ id='ignore_knocked'; label='Ignore Knocked'; tab='Aimbot'; type='bool' }
        @{ id='no_recoil'; label='No Recoil'; tab='Aimbot'; type='bool' }
        @{ id='fast_reload'; label='Fast Reload'; tab='Aimbot'; type='bool' }
        @{ id='esp_enable'; label='Enable ESP'; tab='Visuals'; type='bool' }
        @{ id='esp_snaplines'; label='Snap Lines'; tab='Visuals'; type='bool' }
        @{ id='esp_line_pos'; label='Line Position'; tab='Visuals'; type='combo'; options=@('Top Line','Middle Line','Bottom Line') }
        @{ id='esp_box'; label='Box'; tab='Visuals'; type='bool' }
        @{ id='esp_health_bar'; label='Health Bar'; tab='Visuals'; type='bool' }
        @{ id='esp_health_pos'; label='Health Bar Position'; tab='Visuals'; type='combo'; options=@('Up','Down','Left','Right') }
        @{ id='esp_name'; label='Name'; tab='Visuals'; type='bool' }
        @{ id='esp_distance'; label='Distance'; tab='Visuals'; type='bool' }
        @{ id='esp_weapon_icon'; label='Weapon Icons'; tab='Visuals'; type='bool' }
        @{ id='esp_skeleton'; label='Skeleton'; tab='Visuals'; type='bool' }
        @{ id='esp_health_text'; label='Health Text'; tab='Visuals'; type='bool' }
        @{ id='esp_weapon_text'; label='Weapon Text'; tab='Visuals'; type='bool' }
        @{ id='esp_distance_slider'; label='ESP Distance'; tab='Visuals'; type='float'; min=0; max=700 }
        @{ id='esp_refresh'; label='Auto Refresh ESP'; tab='Visuals'; type='bool' }
        @{ id='loot_esp'; label='Loot ESP'; tab='Visuals'; type='bool' }
        @{ id='loot_range'; label='Loot Range'; tab='Visuals'; type='float'; min=20; max=500 }
        @{ id='rapid_fire'; label='Rapid Fire'; tab='Misc'; type='bool' }
        @{ id='fire_speed'; label='Fire Speed'; tab='Misc'; type='float'; min=1; max=100 }
        @{ id='sniper_scope'; label='Sniper Scope'; tab='Misc'; type='bool' }
        @{ id='scope_target'; label='Scope Target'; tab='Misc'; type='combo'; options=@('Head','Body') }
        @{ id='speed_internal'; label='Speed Internal'; tab='Hardcore'; type='bool' }
        @{ id='spin_bot'; label='Spin Bot'; tab='Hardcore'; type='bool' }
        @{ id='spin_speed'; label='Spin Speed'; tab='Hardcore'; type='float'; min=1; max=15 }
        @{ id='snap_pull'; label='Snap Pull'; tab='Hardcore'; type='bool' }
        @{ id='pull_speed'; label='Pull Speed'; tab='Hardcore'; type='combo'; options=@('Slow','Fast') }
        @{ id='pull_strength'; label='Pull Strength'; tab='Hardcore'; type='float'; min=0.05; max=1 }
        @{ id='limit_fps'; label='Limit FPS'; tab='Settings'; type='setting' }
        @{ id='max_fps'; label='Max FPS'; tab='Settings'; type='float'; min=30; max=240 }
        @{ id='reduce_gpu'; label='Reduce GPU Load'; tab='Settings'; type='setting' }
        @{ id='mute_beep'; label='Mute Beep'; tab='Settings'; type='setting' }
    )
    return (@{ controls = $controls } | ConvertTo-Json -Depth 6 -Compress)
}

function Get-GameConnectionStatus {
    $hbFiles = @(
        (Join-Path $stateDir 'game_heartbeat.txt'),
        (Join-Path $env:APPDATA 'BlazeXiter\game_heartbeat.txt')
    )
    $connected = $false
    $loginOk = $false
    $heartbeatAt = ''
    $secondsAgo = -1
    $message = 'Pehle Inject Panel dabao'
    $liveSeconds = 8
    $loginSeconds = 90

    foreach ($hbFile in $hbFiles) {
        if (-not (Test-Path $hbFile)) { continue }
        try {
            $raw = (Get-Content $hbFile -Raw).Trim()
            $hb = [datetime]::Parse($raw)
            $age = [int]((Get-Date) - $hb).TotalSeconds
            if ($secondsAgo -lt 0 -or $age -lt $secondsAgo) {
                $secondsAgo = $age
                $heartbeatAt = $raw
            }
        } catch { }
    }

    if ($secondsAgo -ge 0) {
        if ($secondsAgo -lt $liveSeconds) {
            $connected = $true
            $loginOk = $true
            $message = 'Game connected — sync chal raha hai'
        }
        elseif ($secondsAgo -lt $loginSeconds) {
            $loginOk = $true
            $message = "Game slow signal — ${secondsAgo}s pehle (login try karo)"
        }
        else {
            $message = "Game offline — last signal ${secondsAgo}s pehle — dubara Inject dabao"
        }
    }

    return @{
        connected    = $connected
        login_ok     = $loginOk
        heartbeat_at = $heartbeatAt
        seconds_ago  = $secondsAgo
        message      = $message
    }
}

function Test-DllConnected {
    $conn = Get-GameConnectionStatus
    return [bool]$conn.login_ok
}

function Clear-PendingLogin($message) {
    $script:WebLoginPending = $false
    $script:WebLoginStartedAt = $null
    if (Test-Path $authRequestFile) {
        Remove-Item $authRequestFile -Force -ErrorAction SilentlyContinue
    }
    Write-AuthStatusFile $false $false $message
}

function Test-PendingLoginTimeout {
    if (-not $script:WebLoginPending) { return $false }
    if (-not $script:WebLoginStartedAt) { return $false }

    $elapsed = ((Get-Date) - $script:WebLoginStartedAt).TotalSeconds
    if ($elapsed -lt 12) { return $false }

    if (-not (Test-DllConnected)) {
        Clear-PendingLogin 'Game DLL offline — emulator kholo aur dubara Inject dabao'
        return $true
    }
    if (Test-Path $authRequestFile) {
        Clear-PendingLogin 'Login timeout — dubara try karo (emulator restart + inject)'
        return $true
    }
    return $false
}

function Get-AuthStatus {
    if (Test-Path $authStatusFile) {
        try {
            return Get-Content $authStatusFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch { }
    }
    return [pscustomobject]@{ logged_in = $false; pending = $false; message = 'Login required' }
}

function Test-AuthLoggedIn {
    $auth = Get-AuthStatus
    if ([bool]$auth.logged_in) {
        $script:WebSessionAuthed = $true
        return $true
    }
    if ($script:WebLoginPending) { return $true }
    return $false
}

function Clear-WebSession {
    $script:WebSessionAuthed = $false
    $script:WebLoginPending = $false
    $script:WebLoginStartedAt = $null
    if (Test-Path $authRequestFile) {
        Remove-Item $authRequestFile -Force -ErrorAction SilentlyContinue
    }
    Write-AuthStatusFile $false $false 'Login on web panel'
}

function Write-AuthStatusFile($loggedIn, $pending, $message) {
    $payload = @{ logged_in = $loggedIn; pending = $pending; message = $message } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($authStatusFile, $payload, (New-Object System.Text.UTF8Encoding $false))
}

function Write-InjectStatusWeb($state, $message) {
    $payload = @{
        state   = [string]$state
        message = [string]$message
        at      = (Get-Date -Format 'o')
    } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($injectStatusFile, $payload, (New-Object System.Text.UTF8Encoding $false))
}

function Get-InjectStatus {
    if (Test-Path $injectStatusFile) {
        try {
            return Get-Content $injectStatusFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch { }
    }
    return [pscustomobject]@{
        state   = 'idle'
        message = 'Web panel se Inject Panel dabao'
        at      = ''
    }
}

function Get-InjectStatusPayload {
    $inj = Get-InjectStatus
    $conn = Get-GameConnectionStatus
    $state = [string]$inj.state
  $success = ($state -eq 'injected') -or [bool]$conn.connected
    return @{
        state              = $state
        message            = [string]$inj.message
        at                 = [string]$inj.at
        success            = $success
        game_connected     = [bool]$conn.connected
        connection_message = [string]$conn.message
    }
}

function Get-HtmlPage {
    @'
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><title>Ansari Cheats</title>
<style>:root{--bg:#0b0f14;--card:#121820;--accent:#0096ff;--text:#e8eef5;--muted:#7f8b99;--border:#1f2a36;--ok:#3ddc84;--bad:#ff5c5c;--wait:#f0b429}*{box-sizing:border-box;margin:0;padding:0}body{font-family:Segoe UI,system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100vh}.hidden{display:none!important}.wrap{padding:16px;max-width:420px;margin:0 auto}.card{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:18px;margin-bottom:12px}h1{font-size:1.3rem;margin-bottom:4px}.sub{color:var(--muted);font-size:.8rem;margin-bottom:14px}.btn{width:100%;border:none;background:var(--accent);color:#fff;border-radius:12px;padding:15px;font-size:1rem;font-weight:700;margin-top:8px}.btn:disabled{opacity:.45}.btn.inject{font-size:1.1rem;padding:18px}.btn.secondary{background:#2a3440;font-size:.9rem;padding:12px}.field{margin:14px 0}.field label{display:block;font-size:.75rem;color:var(--muted);margin-bottom:6px}.field input{width:100%;background:#0d1218;border:1px solid var(--border);border-radius:10px;padding:12px;color:var(--text);font-size:1rem}.status-box{margin-top:10px;padding:12px;border-radius:10px;font-size:.85rem;border:1px solid var(--border);background:#0d1218;color:var(--muted)}.status-box.ok{color:var(--ok)}.status-box.bad{color:var(--bad)}.status-box.wait{color:var(--wait)}.connbox{border-radius:12px;padding:12px;border:1px solid var(--border);background:#0d1218;margin-bottom:10px}.connbox.ok{border-color:rgba(61,220,132,.5)}.connbox.bad{border-color:rgba(255,92,92,.45)}.connrow{display:flex;align-items:center;gap:10px}.dot{width:10px;height:10px;border-radius:50%;background:var(--bad)}.dot.ok{background:var(--ok)}.conn-title{font-weight:700}.conn-msg{font-size:.78rem;color:var(--muted);margin-top:4px}.tabs{display:flex;gap:8px;overflow:auto;padding:8px 0 12px}.tab{padding:8px 14px;border-radius:999px;background:var(--card);border:1px solid var(--border);color:var(--muted);font-size:.85rem;white-space:nowrap}.tab.active{background:var(--accent);border-color:var(--accent);color:#fff}.row{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 0;border-bottom:1px solid var(--border)}.row:last-child{border-bottom:none}.switch{position:relative;width:48px;height:28px;flex-shrink:0}.switch input{opacity:0;width:0;height:0}.slider-sw{position:absolute;cursor:pointer;inset:0;background:#2a3440;border-radius:999px}.slider-sw:before{content:"";position:absolute;height:22px;width:22px;left:3px;bottom:3px;background:#fff;border-radius:50%;transition:.2s}input:checked+.slider-sw{background:var(--accent)}input:checked+.slider-sw:before{transform:translateX(20px)}input[type=range]{width:100%;accent-color:var(--accent)}select{background:#1a2330;color:var(--text);border:1px solid var(--border);border-radius:8px;padding:8px}main{padding-bottom:24px}</style></head>
<body>
<div id="loginView" class="wrap">
<div class="card">
<h1>Ansari Cheats</h1>
<div class="sub">License key daalo — login ke baad panel khulega</div>
<div class="field"><label>License Key</label><input id="licenseKey" type="text" placeholder="ansari / 66" autocomplete="off"></div>
<button class="btn" id="loginBtn">Login</button>
<div class="status-box" id="loginMsg" style="min-height:20px;margin-top:12px"></div>
</div></div>
<div id="mainView" class="hidden">
<div class="wrap">
<div class="card">
<h1>Ansari Cheats</h1>
<div class="sub">Emulator + Free Fire lobby kholo</div>
<div class="connbox bad" id="connBox"><div class="connrow"><div class="dot" id="connDot"></div><div class="conn-title" id="connTitle">NOT CONNECTED</div></div><div class="conn-msg" id="connMsg">Inject DLL dabao</div></div>
<button class="btn inject" id="injectBtn">Inject DLL</button>
<div class="status-box" id="injectStatus">Ready</div>
<button class="btn secondary" id="logoutBtn">Logout</button>
</div>
<div class="tabs" id="tabs"></div>
<main id="main"></main>
</div></div>
<script>
let schema=[],values={},activeTab='Control',loggedIn=false,pollTimer=null,injectTimer=null;
async function api(p,o){const r=await fetch(p,o);if(!r.ok)throw 0;return r.json()}
function el(t,a={},k=[]){const n=document.createElement(t);Object.entries(a).forEach(([x,v])=>{if(x==='class')n.className=v;else if(x==='text')n.textContent=v;else n[x]=v});k.forEach(c=>n.appendChild(c));return n}
function showLogin(){document.getElementById('loginView').classList.remove('hidden');document.getElementById('mainView').classList.add('hidden');if(pollTimer){clearInterval(pollTimer);pollTimer=null}}
function showMain(){document.getElementById('loginView').classList.add('hidden');document.getElementById('mainView').classList.remove('hidden')}
function updateConn(st){const gc=!!st.game_connected;document.getElementById('connBox').className='connbox '+(gc?'ok':'bad');document.getElementById('connDot').className='dot'+(gc?' ok':'');document.getElementById('connTitle').textContent=gc?'CONNECTED':'NOT CONNECTED';document.getElementById('connMsg').textContent=st.connection_message||st.inject_message||'';const box=document.getElementById('injectStatus');const busy=['downloading','waiting_emulator','injecting'].includes(st.inject_state||'');document.getElementById('injectBtn').disabled=busy;box.textContent=st.inject_message||'';if(st.inject_state==='injected'||gc){box.className='status-box ok'}else if(busy){box.className='status-box wait'}else{box.className='status-box'}}
async function pollInject(){try{const s=await api('/api/inject/status');updateConn({game_connected:s.game_connected,connection_message:s.connection_message,inject_state:s.state,inject_message:s.message})}catch(e){}}
document.getElementById('injectBtn').onclick=async()=>{const box=document.getElementById('injectStatus');const btn=document.getElementById('injectBtn');btn.disabled=true;box.className='status-box wait';box.textContent='Inject shuru...';try{await api('/api/inject',{method:'POST'});if(!injectTimer)injectTimer=setInterval(pollInject,1000);pollInject()}catch(e){box.className='status-box bad';box.textContent='Inject fail';btn.disabled=false}};
document.getElementById('loginBtn').onclick=async()=>{const key=document.getElementById('licenseKey').value.trim();const msg=document.getElementById('loginMsg');if(!key){msg.textContent='Key daalo';msg.className='status-box bad';return}msg.className='status-box wait';msg.textContent='Login...';try{const r=await api('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({key,remember:true})});if(r.ok===false){msg.className='status-box bad';msg.textContent=r.message||'Fail';return}loggedIn=true;showMain();bootApp();if(!injectTimer)injectTimer=setInterval(pollInject,1500);let tries=0;const t=setInterval(async()=>{tries++;try{const a=await api('/api/auth/status');if(a.logged_in){clearInterval(t);return}if(tries>30)clearInterval(t)}catch(e){}},1000)}catch(e){msg.className='status-box bad';msg.textContent='Server error'}};
function renderTabs(){const h=document.getElementById('tabs');h.innerHTML='';[...new Set(schema.map(c=>c.tab))].forEach(tab=>h.appendChild(el('button',{class:'tab'+(tab===activeTab?' active':''),text:tab,onclick:()=>{activeTab=tab;renderTabs();renderControls()}})))}
function renderControls(){const m=document.getElementById('main');m.innerHTML='';const card=el('div',{class:'card'});schema.filter(c=>c.tab===activeTab).forEach(c=>{const row=el('div',{class:'row'});row.appendChild(el('div',{text:c.label}));if(c.type==='bool'||(c.type==='setting'&&c.id!=='max_fps')){const w=el('label',{class:'switch'});const i=el('input',{type:'checkbox'});i.checked=!!values[c.id];i.onchange=()=>setValue(c.id,i.checked);w.appendChild(i);w.appendChild(el('span',{class:'slider-sw'}));row.appendChild(w)}else if(c.type==='float'||c.id==='max_fps'){const w=el('div');const i=el('input',{type:'range',min:c.min,max:c.max,step:c.id.includes('strength')?0.01:1,value:values[c.id]??c.min});const t=el('div',{text:String(values[c.id]??c.min)});i.oninput=()=>t.textContent=i.value;i.onchange=()=>setValue(c.id,parseFloat(i.value));w.appendChild(i);w.appendChild(t);row.appendChild(w)}else if(c.type==='combo'){const s=el('select');(c.options||[]).forEach((o,j)=>s.appendChild(el('option',{value:String(j),text:o})));s.value=String(values[c.id]??0);s.onchange=()=>setValue(c.id,parseInt(s.value,10));row.appendChild(s)}card.appendChild(row)});m.appendChild(card)}
async function setValue(id,val){values[id]=val;await api('/api/set',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id,value:val})})}
async function refresh(){const st=await api('/api/state');values=st.values||{};updateConn(st);renderControls()}
async function bootApp(){try{schema=(await api('/api/schema')).controls||[];renderTabs();await refresh();if(!pollTimer)pollTimer=setInterval(refresh,2000)}catch(e){document.getElementById('main').innerHTML='<div class="card"><div class="status-box bad">Panel load fail — refresh karo</div></div>'}}
async function boot(){try{const a=await api('/api/auth/status');if(a.logged_in){loggedIn=true;showMain();bootApp();if(!injectTimer)injectTimer=setInterval(pollInject,1500);pollInject();return}}catch(e){}showLogin()}
document.getElementById('logoutBtn').onclick=async()=>{loggedIn=false;try{await fetch('/api/logout',{method:'POST'})}catch(e){}showLogin()};
boot();
</script></body></html>
'@
}

function Send-Response($response, $code, $contentType, $body) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $response.StatusCode = $code
    $response.ContentType = $contentType
    $response.Headers.Add('Access-Control-Allow-Origin', '*')
    $response.Headers.Add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    $response.Headers.Add('Access-Control-Allow-Headers', 'Content-Type')
    $response.Headers.Add('Cache-Control', 'no-store, no-cache, must-revalidate')
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
    $response.OutputStream.Close()
}

# Firewall + URL ACL
netsh advfirewall firewall delete rule name="Ansari Cheats Remote Panel" | Out-Null
netsh advfirewall firewall add rule name="Ansari Cheats Remote Panel" dir=in action=allow protocol=TCP localport=$port | Out-Null
netsh http delete urlacl url="http://+:$port/" | Out-Null
netsh http add urlacl url="http://+:$port/" user="$env:USERDOMAIN\$env:USERNAME" | Out-Null

$PID | Set-Content -Path $pidFile -Encoding UTF8
Clear-WebOfflineFlag
$state = Load-State
Save-State $state
Write-UrlInfo
Clear-WebSession

trap {
    Reset-WebPanelState
    if (Test-Path $pidFile) { Remove-Item $pidFile -Force -ErrorAction SilentlyContinue }
    break
}

$listener = New-Object System.Net.HttpListener
$started = $false
foreach ($pfx in @("http://+:$port/", "http://127.0.0.1:$port/")) {
    try {
        $listener.Prefixes.Clear()
        $listener.Prefixes.Add($pfx)
        $listener.Start()
        $started = $true
        break
    } catch { }
}
if (-not $started) {
    throw "Web panel start fail — Desktop par RESTART-PANEL.bat (Admin) chalao"
}

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $req = $context.Request
    $res = $context.Response
    $path = $req.Url.AbsolutePath
    $method = $req.HttpMethod

    if ($method -eq 'OPTIONS') {
        Send-Response $res 204 'text/plain' ''
        continue
    }

    if ($method -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
        Touch-WebClientSession
        Send-Response $res 200 'text/html; charset=utf-8' (Get-HtmlPage)
        continue
    }

    if ($method -eq 'GET' -and $path -eq '/api/auth/status') {
        Touch-WebClientSession
        [void](Test-PendingLoginTimeout)
        $auth = Get-AuthStatus
        if ([bool]$auth.logged_in) { $script:WebSessionAuthed = $true }
        if ($script:WebLoginPending -and [bool]$auth.logged_in) {
            $script:WebSessionAuthed = $true
            $script:WebLoginPending = $false
        }
        $loggedIn = [bool]$auth.logged_in
        $payload = @{
            logged_in = $loggedIn
            pending = [bool]$auth.pending
            message = [string]$auth.message
        } | ConvertTo-Json -Compress
        Send-Response $res 200 'application/json' $payload
        continue
    }

    if ($method -eq 'POST' -and $path -eq '/api/logout') {
        Clear-WebSession
        Send-Response $res 200 'application/json' '{"ok":true}'
        continue
    }

    if ($method -eq 'POST' -and $path -eq '/api/inject') {
        $inj = Get-InjectStatus
        if ($inj.state -in @('downloading', 'waiting_emulator', 'injecting', 'reconnecting')) {
            $msg = [string]$inj.message
            $payload = @{ ok = $true; message = $msg } | ConvertTo-Json -Compress
            Send-Response $res 200 'application/json' $payload
            continue
        }
        if ([string]$inj.state -eq 'injected') {
            Write-InjectStatusWeb 'downloading' 'Dubara inject shuru ho raha hai...'
        } else {
            Write-InjectStatusWeb 'downloading' 'Step 1/3: DLL download shuru...'
        }
        $req = @{ requested_at = (Get-Date -Format 'o') } | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText($injectRequestFile, $req, (New-Object System.Text.UTF8Encoding $false))
        $payload = @{ ok = $true; message = 'Inject shuru — emulator kholo ya wait karo' } | ConvertTo-Json -Compress
        Send-Response $res 200 'application/json' $payload
        continue
    }

    if ($method -eq 'POST' -and $path -eq '/api/reconnect') {
        if (-not (Test-AuthLoggedIn)) {
            Send-Response $res 401 'application/json' '{"ok":false,"error":"login required"}'
            continue
        }
        $inj = Get-InjectStatus
        if ($inj.state -in @('downloading', 'waiting_emulator', 'injecting', 'reconnecting')) {
            $msg = [string]$inj.message
            $payload = @{ ok = $true; message = $msg } | ConvertTo-Json -Compress
            Send-Response $res 200 'application/json' $payload
            continue
        }
        Write-InjectStatusWeb 'reconnecting' 'Reconnect — purani DLL band, phir dubara inject...'
        $req = @{ requested_at = (Get-Date -Format 'o'); reconnect = $true } | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText($injectRequestFile, $req, (New-Object System.Text.UTF8Encoding $false))
        $payload = @{ ok = $true; message = 'Reconnect shuru — 15-30 sec wait. Agar crash ho to emulator band karke dubara kholo' } | ConvertTo-Json -Compress
        Send-Response $res 200 'application/json' $payload
        continue
    }

    if ($method -eq 'GET' -and $path -eq '/api/inject/status') {
        Touch-WebClientSession
        $payload = Get-InjectStatusPayload | ConvertTo-Json -Compress
        Send-Response $res 200 'application/json' $payload
        continue
    }

    if ($method -eq 'POST' -and $path -eq '/api/login') {
        Touch-WebClientSession
        $reader = New-Object System.IO.StreamReader($req.InputStream, $req.ContentEncoding)
        $body = $reader.ReadToEnd()
        $reader.Close()
        try {
            $data = $body | ConvertFrom-Json
            $key = [string]$data.key
            $remember = [bool]$data.remember
            if ([string]::IsNullOrWhiteSpace($key)) {
                Write-AuthStatusFile $false $false 'Enter license key'
                Send-Response $res 200 'application/json' '{"ok":false,"message":"Enter license key"}'
                continue
            }
            $request = @{ key = $key; remember = $remember } | ConvertTo-Json -Compress
            [System.IO.File]::WriteAllText($authRequestFile, $request, (New-Object System.Text.UTF8Encoding $false))
            $script:WebSessionAuthed = $false
            $script:WebLoginPending = $true
            $script:WebLoginStartedAt = Get-Date
            if (Test-DllConnected) {
                Write-AuthStatusFile $false $true 'License check ho rahi hai...'
                Send-Response $res 200 'application/json' '{"ok":true,"pending":true}'
            } else {
                Write-AuthStatusFile $false $true 'Pehle Inject DLL dabao — phir login complete hoga'
                $payload = @{ ok = $true; pending = $true; needs_inject = $true; message = 'Login saved — ab Inject DLL dabao' } | ConvertTo-Json -Compress
                Send-Response $res 200 'application/json' $payload
            }
        }
        catch {
            Send-Response $res 200 'application/json' '{"ok":false}'
        }
        continue
    }

    if ($method -eq 'GET' -and $path -eq '/api/schema') {
        if (-not (Test-AuthLoggedIn)) {
            Send-Response $res 401 'application/json' '{"error":"login required"}'
            continue
        }
        Send-Response $res 200 'application/json' (Get-SchemaJson)
        continue
    }

    if ($method -eq 'GET' -and ($path -eq '/api/state' -or $path -eq '/api/check')) {
        Touch-WebClientSession
        $auth = Get-AuthStatus
        $lan = Get-LanIp
        $conn = Get-GameConnectionStatus
        $inj = Get-InjectStatus
        $state = Load-State
        $payload = @{
            values = $(if (Test-AuthLoggedIn) { $state } else { @{} })
            ip = $lan
            port = $port
            running = $true
            logged_in = [bool]$auth.logged_in
            game_connected = $conn.connected
            connection_message = $conn.message
            heartbeat_at = $conn.heartbeat_at
            seconds_ago = $conn.seconds_ago
            inject_state = [string]$inj.state
            inject_message = [string]$inj.message
        } | ConvertTo-Json -Compress
        Send-Response $res 200 'application/json' $payload
        continue
    }

    if ($method -eq 'POST' -and $path -eq '/api/set') {
        if (-not (Test-AuthLoggedIn)) {
            Send-Response $res 401 'application/json' '{"ok":false,"error":"login required"}'
            continue
        }
        Write-WebClientHeartbeat
        $reader = New-Object System.IO.StreamReader($req.InputStream, $req.ContentEncoding)
        $body = $reader.ReadToEnd()
        $reader.Close()
        try {
            $data = $body | ConvertFrom-Json
            $state = Load-State
            $id = [string]$data.id
            if ($state.ContainsKey($id)) {
                $state[$id] = $data.value
                Save-State $state
            }
            Send-Response $res 200 'application/json' '{"ok":true}'
        }
        catch {
            Send-Response $res 200 'application/json' '{"ok":false}'
        }
        continue
    }

    Send-Response $res 404 'application/json' '{"error":"not found"}'
}

Reset-WebPanelState
if (Test-Path $pidFile) { Remove-Item $pidFile -Force -ErrorAction SilentlyContinue }
