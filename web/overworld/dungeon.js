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
 rect(s.kind==='challenge'?'#22223c':'#223d44',0,0,X,Y);
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){
  const xx=x*T,yy=y*T;
  if(x===0||y===0||x===W-1||y===H-1){
   rect('#40595b',xx,yy,32,32);rect('#5f7270',xx+2,yy+3,28,6);
   rect('#223b43',xx,yy+24,32,8);
  }else{
   rect((x+y)%2?'#a19b77':'#ada27d',xx,yy,32,32);
   rect('#d6be90',xx+2,yy+2,26,2);
   rect('#756c57',xx,yy+31,32,1);
   if((x*13+y*7)%5===0)rect('#8a8268',xx+7,yy+17,7,2);
   if(s.walls.has(x+','+y)){
    rect('#334b56',xx+2,yy+7,28,25);rect('#69818a',xx+2,yy+4,28,11);
    rect('#acc2bb',xx+5,yy+5,14,3);
   }
  }
 }
 // Wall torchlight and stone ornaments: dungeon art only, no implication
 // that the actual real-world venue has these structures.
 for(const cx of [3,8,13]){
  const bx=cx*T;
  rect('#2e484b',bx+7,7,18,6);
  rect('#8b6554',bx+11,3,10,12);
  rect('#e9a554',bx+14,1,6,9);
  rect('#f7dc7f',bx+16,1,3,5);
  rect('#65594b',bx+10,(H-1)*T+4,14,8);
  rect('#9b9070',bx+12,(H-1)*T+2,10,3);
 }
 // Shallow engraved floor diamonds add scale without obstruction.
 for(const [gx,gy] of [[5,3],[9,9],[13,3],[5,9]]){
  if(s.walls.has(gx+','+gy))continue;
  const px=gx*T+12,py=gy*T+12;
  rect('#817966',px,py,8,2);rect('#dbbe8f',px+2,py+2,5,2);
  rect('#817966',px+2,py+4,5,2);
 }
 const dx=15*T,dy=6*T;
 rect(s.roomClear?'#b8eab8':'#42565a',dx+5,dy+5,23,27);
 rect(s.roomClear?'#8ce8bc':'#2c3a43',dx+9,dy+8,16,21);
 if(s.roomClear)rect('#f2f7bc',dx+15,dy+10,6,16);
 rect('#24404b',T+5,6*T+4,20,28);rect('#ae76ba',T+10,6*T+8,10,19);
 for(const e of s.enemies){
  const x=e.x*T,y=e.y*T;
  rect('#233a38',x+4,y+25,25,6);
  if(e.boss){
   rect('#3f294e',x+5,y+2,22,27);rect('#b46ac4',x+6,y+5,20,18);
   rect('#f4ce8e',x+10,y+14,4,5);rect('#f4ce8e',x+21,y+14,4,5);
  }else if(e.kind){
   rect('#405a62',x+6,y+3,22,26);rect('#bba678',x+8,y+8,18,14);
  }else{
   rect('#398366',x+5,y+12,23,16);rect('#75c89c',x+7,y+13,19,11);
   rect('#213e3a',x+13,y+21,2,2);rect('#213e3a',x+21,y+21,2,2);
  }
  rect('#442f40',x+4,y-7,24,4);rect('#ed9a78',x+4,y-7,24*e.hp/e.maxHP,4);
 }
 const x=s.player.x*T,y=s.player.y*T;
 rect('#263e3b80',x+4,y+26,25,4);
 if(atlas?.complete&&atlas.naturalWidth>=192){
  const facing={down:0,up:1,left:2,right:3}[s.face];
  ctx.drawImage(atlas,facing*48,0,48,66,x-5,y-21,42,55);
 }else{
  rect('#f4c28e',x+9,y-1,14,13);rect('#875c78',x+7,y+12,20,16);
  rect('#40373c',x+8,y+26,6,5);rect('#40373c',x+19,y+26,6,5);
 }
 if(now<s.attackUntil){
  const v=DIR[s.face];rect('#c9eef0',x+11+v[0]*21,y+5+v[1]*20,11,16);
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
 s.player=loc(x,y);
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
  hit=true;e.hp-=2;
  if(e.hp<=0){s.enemies.splice(s.enemies.indexOf(e),1);s.gold+=e.boss?40:4;s.kills++}
 }
 if(!s.enemies.length&&!s.roomClear){s.roomClear=true;announce('ROOM CLEARED — take the glowing exit →')}
 else if(hit)announce('SWORD HIT!');
 return hit;
}
function tick(){
 const s=state;if(!s||s.completed||s.defeated)return;
 const now=performance.now();
 for(const e of s.enemies){
  if(dist(e,s.player)<=1){
   if(now>=e.lastAttack&&now>=s.invulnUntil){
    s.hp=Math.max(0,s.hp-(e.boss?3:s.kind==='challenge'?2:1));
    s.invulnUntil=now+390;e.lastAttack=now+720;
    if(!s.hp){s.defeated=true;announce('DEFEATED — retry or return to world')}
   }
  }else if(now-e.lastMove> (s.kind==='challenge'?390:560)){
   e.lastMove=now;
   const dx=Math.sign(s.player.x-e.x),dy=Math.sign(s.player.y-e.y);
   for(const [vx,vy] of [[dx,0],[0,dy]]){
    const x=e.x+vx,y=e.y+vy;
    if((vx||vy)&&!blocked(x,y)&&!(x===15&&y===6)&&
      !s.enemies.some(other=>other!==e&&other.x===x&&other.y===y)){
     e.x=x;e.y=y;break;
    }
   }
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
  attackUntil:0,invulnUntil:0,completed:false,defeated:false,roomClear:false,message:''};
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
  defeated:state.defeated,kind:state.kind,player:{...state.player},gold:state.gold};
}
function debugClearRoom(){
 if(!state||!(new URLSearchParams(location.search).has('dev')||window.LibationDeveloper?.enabled()))return false;
 state.enemies=[];state.roomClear=true;announce('DEV TEST: room clear — reach exit');return true;
}
window.LibationDungeon=Object.freeze({start,stop,snapshot,move:step,attack,debugClearRoom});
})();