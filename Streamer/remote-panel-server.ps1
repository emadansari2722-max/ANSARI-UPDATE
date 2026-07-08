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
    if (-not (Test-AuthLoggedIn)) { return }
    $clientAlive = Join-Path $stateDir 'web_client_alive.txt'
    Set-Content -Path $clientAlive -Value (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') -Encoding UTF8
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

function Test-DllConnected {
    $conn = Get-GameConnectionStatus
    return [bool]$conn.connected
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
    if (-not $script:WebSessionAuthed) { return $false }
    $auth = Get-AuthStatus
    return [bool]$auth.logged_in
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

function Get-GameConnectionStatus {
    $hbFile = Join-Path $stateDir 'game_heartbeat.txt'
    $connected = $false
    $heartbeatAt = ''
    $secondsAgo = -1
    $message = 'Pehle Inject Panel dabao'

    if (Test-Path $hbFile) {
        try {
            $raw = (Get-Content $hbFile -Raw).Trim()
            $hb = [datetime]::Parse($raw)
            $secondsAgo = [int]((Get-Date) - $hb).TotalSeconds
            $heartbeatAt = $raw
            if ($secondsAgo -lt 5) {
                $connected = $true
                $message = 'Game connected — sync chal raha hai'
            }
            else {
                $message = "Game offline — last signal ${secondsAgo}s pehle"
            }
        }
        catch {
            $message = 'Heartbeat file invalid — DLL dubara inject karo'
        }
    }

  return @{
        connected = $connected
        heartbeat_at = $heartbeatAt
        seconds_ago = $secondsAgo
        message = $message
    }
}

function Get-HtmlPage {
    @'
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><title>Ansari Cheats</title>
<style>:root{--bg:#0b0f14;--card:#121820;--accent:#0096ff;--text:#e8eef5;--muted:#7f8b99;--border:#1f2a36;--ok:#3ddc84;--bad:#ff5c5c;--wait:#f0b429}*{box-sizing:border-box;margin:0;padding:0}body{font-family:Segoe UI,system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100vh}.hidden{display:none!important}.wrap{min-height:100vh;padding:16px;max-width:420px;margin:0 auto}.card{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:18px;margin-bottom:12px}h1{font-size:1.2rem;margin-bottom:4px}.sub{color:var(--muted);font-size:.8rem;margin-bottom:12px;line-height:1.4}.connbox{border-radius:12px;padding:12px;border:1px solid var(--border);background:#0d1218;margin-bottom:12px}.connbox.ok{border-color:rgba(61,220,132,.5)}.connbox.bad{border-color:rgba(255,92,92,.45)}.connrow{display:flex;align-items:center;gap:10px;margin-bottom:6px}.dot{width:12px;height:12px;border-radius:50%;background:var(--bad)}.dot.ok{background:var(--ok)}.conn-title{font-weight:700;font-size:.95rem}.conn-msg{font-size:.78rem;color:var(--muted)}.steps{margin:10px 0;padding:0;list-style:none}.step{display:flex;align-items:center;gap:8px;padding:7px 9px;margin-bottom:5px;border-radius:8px;background:#0d1218;font-size:.78rem;color:var(--muted);border:1px solid var(--border)}.step .ico{width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:.65rem;font-weight:700;background:#2a3440;flex-shrink:0}.step.active{color:var(--text);border-color:rgba(0,150,255,.45)}.step.active .ico{background:var(--accent);color:#fff}.step.done{color:var(--ok)}.step.done .ico{background:var(--ok);color:#001}.step.err{color:var(--bad)}.step.err .ico{background:var(--bad);color:#fff}.btn{width:100%;border:none;background:var(--accent);color:#fff;border-radius:10px;padding:13px;font-size:.95rem;font-weight:700;margin-top:6px}.btn:disabled{opacity:.45}.btn.secondary{background:#2a3440;margin-top:8px}.status-box{margin-top:10px;padding:11px;border-radius:10px;font-size:.82rem;border:1px solid var(--border);background:#0d1218;color:var(--muted);min-height:40px}.status-box.wait{color:var(--wait);border-color:rgba(240,180,41,.4)}.status-box.ok{color:var(--ok);border-color:rgba(61,220,132,.45)}.status-box.bad{color:var(--bad);border-color:rgba(255,92,92,.45)}.field{margin:12px 0 8px}.field label{display:block;font-size:.75rem;color:var(--muted);margin-bottom:5px}.field input{width:100%;background:#0d1218;border:1px solid var(--border);border-radius:10px;padding:11px;color:var(--text);font-size:.92rem}.remember{display:flex;align-items:center;gap:8px;font-size:.82rem;color:var(--muted);margin:8px 0}.app header{padding:16px;position:sticky;top:0;background:rgba(11,15,20,.95);border-bottom:1px solid var(--border)}.tabs{display:flex;gap:8px;overflow:auto;padding:12px 16px}.tab{padding:8px 14px;border-radius:999px;background:var(--card);border:1px solid var(--border);color:var(--muted);font-size:.85rem}.tab.active{background:var(--accent);border-color:var(--accent);color:#fff}main{padding:0 16px 80px}.row{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 0;border-bottom:1px solid var(--border)}.row:last-child{border-bottom:none}.switch{position:relative;width:48px;height:28px}.switch input{opacity:0;width:0;height:0}.slider-sw{position:absolute;cursor:pointer;inset:0;background:#2a3440;border-radius:999px}.slider-sw:before{content:"";position:absolute;height:22px;width:22px;left:3px;bottom:3px;background:#fff;border-radius:50%;transition:.2s}input:checked+.slider-sw{background:var(--accent)}input:checked+.slider-sw:before{transform:translateX(20px)}input[type=range]{width:100%;accent-color:var(--accent)}select{background:#1a2330;color:var(--text);border:1px solid var(--border);border-radius:8px;padding:8px}footer{position:fixed;left:0;right:0;bottom:0;padding:12px 16px;background:rgba(11,15,20,.95);border-top:1px solid var(--border)}.foot-status{font-size:.8rem;color:var(--muted);text-align:center}.foot-status.ok{color:var(--ok)}.foot-status.bad{color:var(--bad)}</style></head>
<body>
<div id="homeView" class="wrap">
<div class="card">
<h1>Ansari Cheats</h1>
<div class="sub">Emulator + Free Fire kholo → Inject Panel → License login</div>
<div class="connbox bad" id="homeConn"><div class="connrow"><div class="dot" id="homeDot"></div><div class="conn-title" id="homeConnTitle">NOT CONNECTED</div></div><div class="conn-msg" id="homeConnMsg">Inject Panel dabao</div></div>
<ul class="steps" id="injectSteps">
<li class="step" data-step="downloading"><span class="ico">1</span><span>DLL Download</span></li>
<li class="step" data-step="waiting_emulator"><span class="ico">2</span><span>Emulator</span></li>
<li class="step" data-step="injecting"><span class="ico">3</span><span>Inject</span></li>
<li class="step" data-step="injected"><span class="ico">4</span><span>Done</span></li>
</ul>
<button class="btn" id="injectBtn">Inject Panel</button>
<div class="status-box" id="injectStatus">Ready — Inject dabao</div>
<div class="field"><label>License Key</label><input id="licenseKey" type="text" placeholder="ansari / 66" autocomplete="off"></div>
<label class="remember"><input id="rememberMe" type="checkbox" checked> Remember Me</label>
<button class="btn secondary" id="loginBtn">Login</button>
<div class="status-box" id="loginMsg" style="margin-top:8px;min-height:20px"></div>
</div></div>
<div id="appView" class="hidden"><header><h1>Remote Control</h1><div class="sub" id="subtitle">Logged in</div><button class="btn secondary" id="logoutBtn" style="margin:12px 16px;width:calc(100% - 32px)">Logout</button></header>
<div class="wrap" style="padding-top:0"><div class="card"><div class="connbox bad" id="connBox"><div class="connrow"><div class="dot" id="connDot"></div><div class="conn-title" id="connTitle">NOT CONNECTED</div></div><div class="conn-msg" id="connMsg">Checking...</div></div>
<button class="btn" id="reconnectBtn" style="margin-top:10px">Reconnect Panel</button></div></div>
<div class="tabs" id="tabs"></div><main id="main"></main><footer><div class="foot-status" id="status">Ready</div></footer></div>
<script>
let schema=[],values={},activeTab='Control',loggedIn=false,pollTimer=null,injectTimer=null;
const STEP_ORDER=['downloading','waiting_emulator','injecting','injected'];
async function api(p,o){const r=await fetch(p,o);if(!r.ok)throw 0;return r.json()}
function el(t,a={},k=[]){const n=document.createElement(t);Object.entries(a).forEach(([x,v])=>{if(x==='class')n.className=v;else if(x==='text')n.textContent=v;else n[x]=v});k.forEach(c=>n.appendChild(c));return n}
function showHome(){document.getElementById('homeView').classList.remove('hidden');document.getElementById('appView').classList.add('hidden');if(pollTimer){clearInterval(pollTimer);pollTimer=null}}
function showApp(){document.getElementById('homeView').classList.add('hidden');document.getElementById('appView').classList.remove('hidden')}
function updateSteps(state,isError){const idx=STEP_ORDER.indexOf(state);document.querySelectorAll('#injectSteps .step').forEach(li=>{const s=li.dataset.step;li.classList.remove('active','done','err');const si=STEP_ORDER.indexOf(s);if(isError&&state===s)li.classList.add('err');else if(si<idx)li.classList.add('done');else if(si===idx&&state!=='idle'&&state!=='error')li.classList.add('active');else if(state==='injected'&&s==='injected')li.classList.add('done')})}
function setHomeConn(gc,msg){const box=document.getElementById('homeConn');const dot=document.getElementById('homeDot');box.className='connbox '+(gc?'ok':'bad');dot.className='dot'+(gc?' ok':'');document.getElementById('homeConnTitle').textContent=gc?'CONNECTED':'NOT CONNECTED';document.getElementById('homeConnMsg').textContent=msg||''}
function updateInjectUI(s){const box=document.getElementById('injectStatus');const btn=document.getElementById('injectBtn');const busy=['downloading','waiting_emulator','injecting','reconnecting'].includes(s.state);btn.disabled=busy;box.textContent=s.message||'';const gc=!!s.game_connected||s.state==='injected';setHomeConn(gc,s.connection_message||s.message||'');if(s.state==='error'){box.className='status-box bad';updateSteps('downloading',true);btn.textContent='Retry Inject'}else if(s.state==='injected'||s.success){box.className='status-box ok';updateSteps('injected',false);btn.textContent='Inject Panel'}else if(busy){box.className='status-box wait';updateSteps(s.state,false);btn.textContent='Injecting...'}else{box.className='status-box';btn.textContent='Inject Panel';if(s.state==='idle')document.querySelectorAll('#injectSteps .step').forEach(li=>li.classList.remove('active','done','err'))}}
async function pollInject(){try{const s=await api('/api/inject/status');updateInjectUI(s)}catch(e){}}
document.getElementById('injectBtn').onclick=async()=>{const box=document.getElementById('injectStatus');const btn=document.getElementById('injectBtn');btn.disabled=true;box.className='status-box wait';box.textContent='Inject shuru...';try{const r=await api('/api/inject',{method:'POST'});box.textContent=r.message||'Inject shuru';if(!injectTimer)injectTimer=setInterval(pollInject,800);pollInject()}catch(e){box.className='status-box bad';box.textContent='Fail — PC par RESTART-PANEL.bat (Admin) chalao';btn.disabled=false}};
document.getElementById('loginBtn').onclick=async()=>{const key=document.getElementById('licenseKey').value.trim();const remember=document.getElementById('rememberMe').checked;const msg=document.getElementById('loginMsg');if(!key){msg.textContent='Key daalo';msg.className='status-box bad';return}msg.className='status-box wait';msg.textContent='Login check...';try{const r=await api('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({key,remember})});if(r.ok===false){msg.className='status-box bad';msg.textContent=r.message||'Login fail';return}let tries=0;const t=setInterval(async()=>{tries++;try{const a=await api('/api/auth/status');msg.textContent=a.message||'';if(a.logged_in){loggedIn=true;clearInterval(t);showApp();bootApp();return}if(!a.pending&&tries>2){clearInterval(t);msg.className='status-box bad'}if(tries>25){clearInterval(t);msg.className='status-box bad';msg.textContent=a.message||'DLL offline — dubara Inject dabao'}}catch(e){}},1000)}catch(e){msg.className='status-box bad';msg.textContent='Server error'}};
function updateConnection(st){const gc=!!st.game_connected;document.getElementById('connBox').className='connbox '+(gc?'ok':'bad');document.getElementById('connDot').className='dot'+(gc?' ok':'');document.getElementById('connTitle').textContent=gc?'CONNECTED':'NOT CONNECTED';document.getElementById('connMsg').textContent=st.connection_message||st.inject_message||'';document.getElementById('status').textContent=gc?'CONNECTED — Game + Web OK':'NOT CONNECTED';document.getElementById('status').className='foot-status '+(gc?'ok':'bad');document.getElementById('reconnectBtn').disabled=['downloading','waiting_emulator','injecting','reconnecting'].includes(st.inject_state||'')}
async function setValue(id,val){values[id]=val;await api('/api/set',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id,value:val})})}
function renderTabs(){const h=document.getElementById('tabs');h.innerHTML='';[...new Set(schema.map(c=>c.tab))].forEach(tab=>h.appendChild(el('button',{class:'tab'+(tab===activeTab?' active':''),text:tab,onclick:()=>{activeTab=tab;renderTabs();renderControls()}})))}
function renderControls(){const m=document.getElementById('main');m.innerHTML='';const card=el('div',{class:'card'});schema.filter(c=>c.tab===activeTab).forEach(c=>{const row=el('div',{class:'row'});row.appendChild(el('div',{text:c.label}));if(c.type==='bool'||c.type==='setting'&&c.id!=='max_fps'){const w=el('label',{class:'switch'});const i=el('input',{type:'checkbox'});i.checked=!!values[c.id];i.onchange=()=>setValue(c.id,i.checked);w.appendChild(i);w.appendChild(el('span',{class:'slider-sw'}));row.appendChild(w)}else if(c.type==='float'||c.id==='max_fps'){const w=el('div');const i=el('input',{type:'range',min:c.min,max:c.max,step:c.id.includes('strength')?0.01:1,value:values[c.id]??c.min});const t=el('div',{text:String(values[c.id]??c.min)});i.oninput=()=>t.textContent=i.value;i.onchange=()=>setValue(c.id,parseFloat(i.value));w.appendChild(i);w.appendChild(t);row.appendChild(w)}else if(c.type==='combo'){const s=el('select');(c.options||[]).forEach((o,j)=>s.appendChild(el('option',{value:String(j),text:o})));s.value=String(values[c.id]??0);s.onchange=()=>setValue(c.id,parseInt(s.value,10));row.appendChild(s)}card.appendChild(row)});m.appendChild(card)}
async function refresh(){const st=await api('/api/state');values=st.values||{};updateConnection(st);renderControls()}
document.getElementById('reconnectBtn').onclick=async()=>{try{await api('/api/reconnect',{method:'POST'});setTimeout(refresh,1000)}catch(e){}};
async function bootApp(){schema=(await api('/api/schema')).controls||[];renderTabs();await refresh();if(!pollTimer)pollTimer=setInterval(refresh,2000)}
async function boot(){showHome();try{await fetch('/api/logout',{method:'POST'})}catch(e){}try{const s=await api('/api/inject/status');updateInjectUI(s);if(s.state==='injected'){const a=await api('/api/auth/status');if(a.logged_in){loggedIn=true;showApp();bootApp();return}}}catch(e){}if(!injectTimer)injectTimer=setInterval(pollInject,1500)}
document.getElementById('logoutBtn').onclick=async()=>{loggedIn=false;try{await fetch('/api/logout',{method:'POST'})}catch(e){}showHome();boot()};
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
        Send-Response $res 200 'text/html; charset=utf-8' (Get-HtmlPage)
        continue
    }

    if ($method -eq 'GET' -and $path -eq '/api/auth/status') {
        [void](Test-PendingLoginTimeout)
        $auth = Get-AuthStatus
        if ($script:WebLoginPending -and [bool]$auth.logged_in) {
            $script:WebSessionAuthed = $true
            $script:WebLoginPending = $false
        }
        $loggedIn = $script:WebSessionAuthed -and [bool]$auth.logged_in
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
        $payload = Get-InjectStatusPayload | ConvertTo-Json -Compress
        Send-Response $res 200 'application/json' $payload
        continue
    }

    if ($method -eq 'POST' -and $path -eq '/api/login') {
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
            if (-not (Test-DllConnected)) {
                Write-AuthStatusFile $false $false 'Game DLL offline — pehle Inject OK hona chahiye'
                $payload = @{ ok = $false; message = 'Game DLL connect nahi — emulator kholo, Inject dabao, phir login' } | ConvertTo-Json -Compress
                Send-Response $res 200 'application/json' $payload
                continue
            }
            $request = @{ key = $key; remember = $remember } | ConvertTo-Json -Compress
            [System.IO.File]::WriteAllText($authRequestFile, $request, (New-Object System.Text.UTF8Encoding $false))
            $script:WebSessionAuthed = $false
            $script:WebLoginPending = $true
            $script:WebLoginStartedAt = Get-Date
            Write-AuthStatusFile $false $true 'License check ho rahi hai...'
            Send-Response $res 200 'application/json' '{"ok":true,"pending":true}'
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
        if (Test-AuthLoggedIn) { Write-WebClientHeartbeat }
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
