/* Libation Warriors: local single-player dungeon vertical slice.
   These rooms and rewards are fictional gameplay, never real venue geometry. */
(()=>{
'use strict';
const W=17,H=13,T=32,X=W*T,Y=H*T;
const $=id=>document.getElementById(id);
const DIR={up:[0,-1],down:[0,1],left:[-1,0],right:[1,0]};
let state=null,root=null,canvas=null,ctx=null,atlas=null,raf=0,timer=0,held=null,heldAt=0;
function seed(value){let h=2166136261;for(const c of String(value))h=Math.imul(h^c.charCodeAt(0),16777619)>>>0;return h||1}
function rng(value){let n=seed(value);return()=>{n=(Math.imul(n,1664525)+1013904223)>>>0;return n/4294967296}}
function loc(x,y){return {x,y}}
function dist(a,b){return Math.abs(a.x-b.x)+Math.abs(a.y-b.y)}
function blocked(x,y){return x<1||x>=W-1||y<1||y>=H-1||state.walls.has(x+','+y)}
function announce(str){if(state){state.message=str;updateHUD()}}
function updateHUD(){
 if(!state)return;
 $('lwDHP').style.width=(100*state.hp/state.maxHP)+'%';
 $('lwDText').textContent='HP '+state.hp+'/'+state.maxHP+' · ROOM '+state.room+'/'+state.rooms+' · '+state.gold+' test gold';
 $('lwDMessage').textContent=state.message;
 $('lwDTitle').textContent=(state.kind==='challenge'?'WORMHOLE':'RUPTURE')+' · '+state.venue.name;
}
function makeRoom(){
 const s=state,r=rng(s.venue.id+':'+s.room+':'+s.kind);
 s.player=loc(2,6);s.face='right';s.walls=new Set();s.enemies=[];s.roomClear=false;
 for(let i=0;i<15;i++){
  const x=4+Math.floor(r()*10),y=2+Math.floor(r()*9);
  if(Math.abs(y-6)<=1||x>13)continue;
  s.walls.add(x+','+y);
 }
 const boss=s.room===s.rooms;
 for(let i=0;i<(boss?1:Math.min(5,(s.kind==='challenge'?3:2)+Math.floor(s.room/4)));i++){
  let x=11+i%3,y=3+(i*3)%7;
  while(blocked(x,y)||s.enemies.some(e=>e.x===x&&e.y===y)){x=10+Math.floor(r()*5);y=2+Math.floor(r()*9)}
  const hp=boss?(s.kind==='challenge'?17:12):(s.kind==='challenge'?5:3)+Math.floor(s.room/5);
  s.enemies.push({x,y,hp,maxHP:hp,boss,kind:i%2,lastMove:0,lastAttack:0});
 }
 announce(boss?'BOSS ROOM — defeat the guardian':'Clear the enemies, then find the glowing door →');
}
function rect(c,x,y,w,h){ctx.fillStyle=c;ctx.fillRect(x,y,w,h)}
function render(now){
 if(!state||root.hidden)return;
 const s=state;ctx.imageSmoothingEnabled=false;
 const cursed=s.kind==='challenge';
 const floor=cursed?['#696478','#716a7d','#766f80']:['#98876d','#a39071','#aa9777'];
 rect(cursed?'#182536':'#23373a',0,0,X,Y);
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){
  const xx=x*T,yy=y*T,grain=(x*37+y*71+s.room*13)%17;
  if(x===0||y===0||x===W-1||y===H-1){
   rect('#1c303a',xx,yy,T,T);
   rect(cursed?'#4c5268':'#526867',xx+1,yy+2,30,24);
   rect('#82908a',xx+3,yy+4,25,4);
   rect('#253f47',xx+1,yy+23,30,8);
   rect('#152c37',xx+1,yy+28,30,4);
   rect('#a0a397',xx+2,yy+1,4,2);
   if(x%3===1)rect('#303e49',xx+21,yy+12,2,10);
  }else{
   rect(floor[(x+2*y+grain)%floor.length],xx,yy,T,T);
   rect(cursed?'#918b9a':'#cab68a',xx+2,yy+2,27,2);
   rect(cursed?'#514d62':'#776c57',xx,yy+30,32,2);
   rect('#5a5660',xx+30,yy+3,2,26);
   if(grain%3===0){
    rect(cursed?'#9690a5':'#d7bc8d',xx+5,yy+10,3,2);
    rect('#5a5d5a',xx+19,yy+23,4,1);
   }
   if(grain%5===0){
    rect('#4f5958',xx+15,yy+13,9,2);
    rect('#a6a08c',xx+20,yy+15,2,2);
   }
   if(s.walls.has(x+','+y)){
    rect('#192f3b',xx+2,yy+12,30,20);
    rect(cursed?'#525a70':'#46606b',xx+2,yy+6,28,23);
    rect('#8da4a1',xx+2,yy+4,28,9);
    rect('#c3cebb',xx+5,yy+5,14,3);
    rect('#344653',xx+24,yy+14,3,12);
    rect('#283b46',xx+5,yy+27,21,4);
    if(grain%2)rect('#4d8b77',xx+3,yy+17,4,8);
   }
  }
 }
 // Torchlight, cracked masonry, and floor inlay belong only to the
 // fictional dungeon, never to a real business building.
 for(const cx of [3,8,13]){
  const bx=cx*T,flicker=Math.round(Math.sin(now/127+cx)*2);
  const glow=ctx.createRadialGradient(bx+16,12,2,bx+16,12,52);
  glow.addColorStop(0,'rgba(255,191,86,.24)');
  glow.addColorStop(1,'rgba(255,191,86,0)');
  ctx.fillStyle=glow;ctx.fillRect(bx-36,0,104,72);
  rect('#243a40',bx+6,7,20,7);
  rect('#765341',bx+10,2,12,14);
  rect('#b57b4c',bx+13,0,6,10);
  rect('#e99440',bx+12,1+flicker,9,11);
  rect('#ffe3a0',bx+15,1+flicker,4,6);
  rect('#4c5050',bx+9,(H-1)*T+4,15,8);
  rect('#aaa087',bx+12,(H-1)*T+2,10,3);
 }
 for(const [gx,gy] of [[5,3],[9,9],[13,3],[5,9]]){
  if(s.walls.has(gx+','+gy))continue;
  const px=gx*T+12,py=gy*T+12;
  rect('#574e54',px+2,py-2,4,2);
  rect('#bdb39c',px,py,9,2);rect('#584f51',px+2,py+2,6,2);
  rect('#bdb39c',px+4,py+4,3,2);
 }
 const dx=15*T,dy=6*T;
 const pulse=Math.round(2+Math.sin(now/180)*2);
 rect('#233943',dx+2,dy+1,28,31);
 rect(s.roomClear?'#80d5bb':'#74827f',dx+4,dy+2,24,4);
 rect(s.roomClear?'#b7ffcf':'#4e6469',dx+7,dy+6,18,25);
 rect(s.roomClear?'#50b8a8':'#223641',dx+10,dy+9,12,20);
 if(s.roomClear){
  rect('#e8ffca',dx+14,dy+8+pulse,4,13);
  rect('#98f2de',dx+8,dy+12,2,10);
 }
 rect('#172d3b',T+3,6*T+4,25,28);
 rect('#a777bb',T+7,6*T+8,17,21);
 rect('#d8b6ea',T+11,6*T+11,6,16);
 for(const e of s.enemies){
  const x=e.x*T,y=e.y*T;
  const bob=Math.round(Math.sin(now/170+e.x)*1.5),flash=now<(e.hitUntil||0);
  rect('#20313696',x+3,y+27,27,5);
  if(e.boss){
   rect('#302b45',x+2,y+2+bob,29,28);
   rect(flash?'#ffe7d2':'#8d4e99',x+4,y+8+bob,25,19);
   rect('#493454',x+9,y+3+bob,15,9);
   rect('#d4b0dd',x+6,y+9+bob,20,4);
   rect('#f2db9f',x+1,y+5+bob,6,9);rect('#f2db9f',x+26,y+5+bob,6,9);
   rect('#291e3a',x+9,y+17+bob,5,5);rect('#291e3a',x+21,y+17+bob,5,5);
   rect('#f9cc7c',x+11,y+18+bob,2,2);rect('#f9cc7c',x+23,y+18+bob,2,2);
  }else if(e.kind){
   rect('#273d4a',x+7,y+3+bob,20,28);
   rect(flash?'#ffe7d2':'#a89b8b',x+7,y+9+bob,20,16);
   rect('#d3c1a0',x+10,y+9+bob,14,5);
   rect('#324955',x+5,y+20+bob,5,9);rect('#324955',x+24,y+20+bob,5,9);
   rect('#302b3d',x+11,y+17+bob,4,3);rect('#302b3d',x+20,y+17+bob,4,3);
  }else{
   rect('#286c60',x+4,y+20+bob,25,9);
   rect(flash?'#ffe7d2':'#69b899',x+5,y+13+bob,24,14);
   rect('#a3dbad',x+8,y+14+bob,15,4);
   rect('#275c54',x+9,y+22+bob,4,3);rect('#275c54',x+23,y+22+bob,4,3);
   rect('#e0dca5',x+13,y+24+bob,3,2);
  }
  if(e.boss&&dist(e,s.player)===1&&now>=e.lastAttack-350){
   rect('#e8b45b',x+2,y+27,29,3);
   rect('#f7df97',x+4,y+25,25,2);
  }
  rect('#302c3b',x+3,y-8,26,5);
  rect('#e5a579',x+4,y-7,24*Math.max(0,e.hp)/e.maxHP,3);
 }
 const x=s.player.x*T,y=s.player.y*T;
 const walking=now-(s.lastStep||0)<260;
 const stride=walking?Math.round(Math.sin(now/72)*2):0;
 rect('#263e3b80',x+4,y+27,25,4);
 // Brief visible invulnerability feedback rather than invisible damage.
 const visible=now>=(s.hurtUntil||0)||Math.floor(now/65)%2===0;
 if(visible&&atlas?.complete&&atlas.naturalWidth>=192){
  const facing={down:0,up:1,left:2,right:3}[s.face];
  ctx.drawImage(atlas,facing*48,0,48,66,x-5,y-21+stride,42,55);
 }else if(visible){
  rect('#f4c28e',x+9,y-1+stride,14,13);
  rect('#875c78',x+7,y+12+stride,20,16);
  rect('#40373c',x+8,y+26,6,5);rect('#40373c',x+19,y+26,6,5);
 }
 if(now<s.attackUntil){
  const [vx,vy]=DIR[s.face];
  const sx=x+14+vx*20,sy=y+14+vy*18;
  rect('#5887a0',sx-6,sy-8,14,21);
  rect('#efffff',sx-3,sy-10,6,21);
  rect('#b7e6e5',sx+4,sy-4,4,12);
  rect('#ffefba',sx-7,sy+7,19,3);
 }
 for(const fx of s.sparks){
  if(fx.until<=now)continue;
  const f=Math.max(0,(fx.until-now)/240),px=fx.x*T+16,py=fx.y*T+15;
  rect('#fff1b2',px-9*f,py-8*f,5,5);
  rect('#b9edeb',px+6*f,py-5*f,4,6);
  rect('#ffd4a5',px-1,py+8*f,3,5);
 }
 s.sparks=s.sparks.filter(f=>f.until>now);
 if(now<(s.hurtUntil||0)){
  ctx.fillStyle='rgba(235,79,83,0.12)';ctx.fillRect(0,0,X,Y);
 }
 if(s.completed||s.defeated){
  rect('#101b31ea',24,138,X-48,134);ctx.strokeStyle='#e0c686';ctx.lineWidth=4;
  ctx.strokeRect(24,138,X-48,134);ctx.textAlign='center';
  ctx.fillStyle='#ffdf9b';ctx.font='bold 23px monospace';
  ctx.fillText(s.completed?'DUNGEON CLEARED!':'PARTY DEFEATED',X/2,184);
  ctx.fillStyle='#cde8e2';ctx.font='14px monospace';
  ctx.fillText(s.completed?s.gold+' test gold · '+s.rooms+' rooms':'Retry or return to overworld',X/2,213);
  ctx.textAlign='left';
 }
 raf=requestAnimationFrame(render);
}
function step(dir){
 const s=state;if(!s||s.completed||s.defeated||!DIR[dir])return false;
 s.face=dir;const [dx,dy]=DIR[dir],x=s.player.x+dx,y=s.player.y+dy;
 if(blocked(x,y)||s.enemies.some(e=>e.x===x&&e.y===y))return false;
 s.player=loc(x,y);s.lastStep=performance.now();
 if(s.roomClear&&x===15&&y===6){
  if(s.room===s.rooms){s.completed=true;announce('CLEARED · Local prototype rewards only');$('lwDResult').hidden=false;
   $('lwDResult').textContent='VICTORY · '+s.gold+' local test gold · '+s.kills+' enemies';}
  else{s.room++;s.hp=Math.min(s.maxHP,s.hp+2);makeRoom()}
 }
 return true;
}
function attack(){
 const s=state,now=performance.now();
 if(!s||s.completed||s.defeated||now<s.nextAttack)return false;
 s.nextAttack=now+350;s.attackUntil=now+190;
 const [dx,dy]=DIR[s.face],front=loc(s.player.x+dx,s.player.y+dy);
 let hit=false;
 for(const e of [...s.enemies])if(dist(e,front)<=1){
  hit=true;e.hp-=2;e.hitUntil=now+145;e.stunnedUntil=now+210;
  s.sparks.push({x:e.x,y:e.y,until:now+240});
  if(e.hp<=0){s.enemies.splice(s.enemies.indexOf(e),1);s.gold+=e.boss?40:4;s.kills++}
 }
 if(!s.enemies.length&&!s.roomClear){s.roomClear=true;announce('ROOM CLEARED — take the glowing exit →')}
 else if(hit)announce('SWORD HIT!');
 return hit;
}
// Find a short legal route to an adjacent strike tile; never stand inside
// the player, another enemy, a wall, or the exit. Small rooms bound the BFS.
function chase(enemy){
 const s=state,seen=new Set([enemy.x+','+enemy.y]);
 const queue=[{x:enemy.x,y:enemy.y,first:null}];
 const occupied=(x,y)=>blocked(x,y)||(x===15&&y===6)||
  (x===s.player.x&&y===s.player.y)||
  s.enemies.some(other=>other!==enemy&&other.x===x&&other.y===y);
 for(let n=0;n<queue.length;n++){
  const p=queue[n];
  if(dist(p,s.player)===1){
   if(p.first){enemy.x=p.first.x;enemy.y=p.first.y}
   return;
  }
  const ordered=Object.values(DIR).sort((a,b)=>
   dist(loc(p.x+a[0],p.y+a[1]),s.player)-
   dist(loc(p.x+b[0],p.y+b[1]),s.player));
  for(const [dx,dy] of ordered){
   const x=p.x+dx,y=p.y+dy,key=x+','+y;
   if(seen.has(key)||occupied(x,y))continue;
   seen.add(key);queue.push({x,y,first:p.first||loc(x,y)});
  }
 }
}
function tick(){
 const s=state;if(!s||s.completed||s.defeated)return;
 const now=performance.now();
 for(const e of s.enemies){
  if(now<(e.stunnedUntil||0))continue;
  if(dist(e,s.player)===1){
   if(now>=e.lastAttack&&now>=s.invulnUntil){
    s.hp=Math.max(0,s.hp-(e.boss?3:s.kind==='challenge'?2:1));
    s.invulnUntil=now+650;s.hurtUntil=now+400;
    // Slow, clearly readable boss swings give touch players a fair dodge window.
    e.lastAttack=now+(e.boss?1350:900);
    if(!s.hp){s.defeated=true;announce('DEFEATED — retry or return to world')}
    else announce('HIT! Dodge away, then counterattack');
   }
  }else if(now-e.lastMove>(s.kind==='challenge'?390:560)){
   e.lastMove=now;chase(e);
  }
 }
 if(held&&now-heldAt>130){step(held);heldAt=now}
 updateHUD();
}
function initialize(){
 if(root)return;
 root=document.createElement('section');root.id='lwDungeonStage';root.hidden=true;
 root.innerHTML='<header><strong id="lwDTitle">DUNGEON</strong><button id="lwDExit">EXIT ×</button></header>'+
  '<div class="lwDStats"><div class="lwDHealth"><span id="lwDHP"></span></div><span id="lwDText"></span></div>'+
  '<div class="lwDView"><canvas id="lwDCanvas" width="'+X+'" height="'+Y+'" aria-label="Playable top-down dungeon"></canvas></div>'+
  '<p id="lwDMessage" aria-live="polite"></p>'+
  '<div class="lwDControls"><div class="lwDPad">'+
  '<button data-dmove="up" class="up" aria-label="Move up">▲</button>'+
  '<button data-dmove="left" class="left" aria-label="Move left">◀</button>'+
  '<button data-dmove="down" class="down" aria-label="Move down">▼</button>'+
  '<button data-dmove="right" class="right" aria-label="Move right">▶</button></div>'+
  '<button id="lwDAttack" aria-label="Attack" data-dmove="attack">⚔<small>ATTACK</small></button></div>'+
  '<div id="lwDResult" hidden></div>'+
  '<footer><button id="lwDRetry">RESTART</button><button id="lwDReturn">RETURN TO WORLD</button></footer>';
 const css=document.createElement('style');css.textContent=
 '#lwDungeonStage[hidden],#lwDResult[hidden]{display:none!important}'+
 '#lwDungeonStage{position:fixed;inset:0;z-index:1001;display:flex;flex-direction:column;'+
 'align-items:center;justify-content:space-between;box-sizing:border-box;overflow:auto;'+
 'padding:calc(env(safe-area-inset-top) + 8px) 10px calc(env(safe-area-inset-bottom) + 8px);'+
 'background:radial-gradient(circle at 50% 35%,#2b4657,#081525 80%);'+
 'color:#efe1ba;font:12px monospace;touch-action:none}'+
 '#lwDungeonStage header,#lwDungeonStage footer{width:min(100%,700px);display:flex;gap:10px;'+
 'justify-content:space-between;align-items:center;padding:6px 2px}'+
 '#lwDungeonStage strong{color:#f5da9c;font-size:13px}'+
 '#lwDungeonStage button{touch-action:none;font-family:monospace;font-weight:bold;'+
 'border:2px solid #c8b784;background:#304e57;color:#f7e9d0;padding:9px;border-radius:7px}'+
 '.lwDStats{width:min(100%,700px);display:flex;align-items:center;gap:9px;min-height:28px}'+
 '.lwDHealth{width:82px;height:12px;background:#6b3948;border:2px solid #d5c18c}'+
 '#lwDHP{display:block;height:100%;background:#85c985;width:100%}'+
 '.lwDView{width:min(100%,700px);flex:1;min-height:0;display:flex;align-items:center}'+
 '#lwDCanvas{display:block;width:100%;max-height:55vh;aspect-ratio:17 / 13;object-fit:contain;'+
 'image-rendering:pixelated;border:3px solid #cfb680;background:#1c293a}'+
 '#lwDMessage{text-align:center;min-height:20px;margin:5px;font-size:12px;color:#e8d397}'+
 '.lwDControls{width:min(100%,530px);min-height:147px;display:flex;justify-content:space-around;align-items:center}'+
 '.lwDPad{display:grid;grid-template-columns:repeat(3,48px);grid-template-rows:repeat(3,42px)}'+
 '.lwDPad button{font-size:22px!important;padding:3px!important}'+
 '.lwDPad .up{grid-column:2;grid-row:1}.lwDPad .left{grid-column:1;grid-row:2}'+
 '.lwDPad .down{grid-column:2;grid-row:3}.lwDPad .right{grid-column:3;grid-row:2}'+
 '#lwDAttack{width:90px;height:90px;border-radius:50%!important;background:#79475e!important;font-size:32px}'+
 '#lwDAttack small{display:block;font-size:10px}'+
 '#lwDungeonStage footer button{flex:1}#lwDResult{color:#baffce;text-align:center;padding:5px}'+
 '@media(max-height:690px){.lwDControls{min-height:115px}.lwDPad{transform:scale(.85)}#lwDAttack{width:72px;height:72px}}';
 document.head.appendChild(css);document.body.appendChild(root);
 canvas=$('lwDCanvas');ctx=canvas.getContext('2d');atlas=new Image();atlas.src='./avatar_snes.png';
 for(const b of root.querySelectorAll('[data-dmove]')){
  const dir=b.dataset.dmove;
  b.addEventListener('pointerdown',e=>{
   e.preventDefault();b.setPointerCapture?.(e.pointerId);
   if(dir==='attack'){attack();return}held=dir;step(dir);heldAt=performance.now();
  });
  for(const type of ['pointerup','pointercancel','lostpointercapture'])
   b.addEventListener(type,()=>{if(held===dir)held=null});
 }
 $('lwDExit').onclick=stop;$('lwDReturn').onclick=stop;
 $('lwDRetry').onclick=()=>{if(state)start({venue:state.venue,warrior:state.warrior})};
 window.addEventListener('keydown',e=>{
  if(!state||root.hidden)return;
  const dir={arrowup:'up',w:'up',arrowdown:'down',s:'down',
   arrowleft:'left',a:'left',arrowright:'right',d:'right'}[e.key.toLowerCase()];
  if(dir){e.preventDefault();step(dir)}
  else if(e.key===' '||e.key==='Enter'){e.preventDefault();attack()}
  else if(e.key==='Escape'){e.preventDefault();stop()}
 },{passive:false});
 window.addEventListener('blur',()=>{held=null});
}
function start({venue,warrior}={}){
 if(!venue||!['rupture','challenge'].includes(venue.type))return false;
 initialize();stop();
 const kind=venue.type;
 state={venue:{id:String(venue.id||venue.name),name:String(venue.name||'Rift'),type:kind},
  warrior:warrior||'Training Warrior',kind,room:1,rooms:kind==='challenge'?14:10,
  hp:kind==='challenge'?14:18,maxHP:kind==='challenge'?14:18,player:loc(2,6),
  walls:new Set(),enemies:[],face:'right',gold:0,kills:0,nextAttack:0,
  attackUntil:0,invulnUntil:0,hurtUntil:0,lastStep:0,sparks:[],
  completed:false,defeated:false,roomClear:false,message:''};
 root.hidden=false;document.body.classList.add('in-dungeon');$('lwDResult').hidden=true;
 makeRoom();timer=setInterval(tick,170);raf=requestAnimationFrame(render);return true;
}
function stop(){
 if(timer){clearInterval(timer);timer=0}if(raf){cancelAnimationFrame(raf);raf=0}
 held=null;if(root)root.hidden=true;document.body.classList.remove('in-dungeon');state=null;
}
function snapshot(){
 if(!state)return {active:false};
 return {active:!root.hidden,room:state.room,rooms:state.rooms,hp:state.hp,maxHP:state.maxHP,
  enemies:state.enemies.length,cleared:state.roomClear,completed:state.completed,
  defeated:state.defeated,kind:state.kind,player:{...state.player},face:state.face,
  gold:state.gold,kills:state.kills,bossHP:state.enemies.find(e=>e.boss)?.hp??null};
}
function debugClearRoom(){
 if(!state||!(new URLSearchParams(location.search).has('dev')||window.LibationDeveloper?.enabled()))return false;
 state.enemies=[];state.roomClear=true;announce('DEV TEST: room clear — reach exit');return true;
}
// Isolated developer test combat encounter; cannot mint account rewards.
function debugCombatEncounter(){
 if(!state||!(new URLSearchParams(location.search).has('dev')||window.LibationDeveloper?.enabled()))return false;
 const s=state,[dx,dy]=DIR[s.face];
 s.enemies=[{x:s.player.x+dx,y:s.player.y+dy,hp:2,maxHP:2,
  boss:false,kind:0,lastMove:performance.now(),lastAttack:performance.now()}];
 s.roomClear=false;s.nextAttack=0;
 announce('DEV COMBAT CHECK: use ATTACK to defeat adjacent enemy');
 return true;
}
// Boss combat fixture uses the actual final-room guardian health/damage;
// it only repositions the encounter in explicit developer sessions.
function debugBossEncounter(){
 if(!state||!(new URLSearchParams(location.search).has('dev')||window.LibationDeveloper?.enabled()))return false;
 const s=state;s.room=s.rooms;makeRoom();s.player=loc(2,6);s.face='right';
 s.enemies=[{x:3,y:6,hp:s.kind==='challenge'?17:12,
  maxHP:s.kind==='challenge'?17:12,boss:true,kind:0,
  lastMove:performance.now(),lastAttack:performance.now()+1000}];
 // This fixture represents arriving at the final room with full health.
 // Boss durability and outgoing damage remain identical to normal gameplay.
 s.hp=s.maxHP;s.hurtUntil=0;s.nextAttack=0;
 s.invulnUntil=performance.now()+800;
 announce('DEV BOSS CHECK: defeat the real guardian with sword attacks');
 return true;
}
window.LibationDungeon=Object.freeze({start,stop,snapshot,move:step,attack,debugClearRoom,debugCombatEncounter,debugBossEncounter});
})();