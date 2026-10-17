/* Libation Warriors: procedural, fictional single-player dungeon.
   No account rewards, scanned warrior blueprints, real-business interiors or GPS
   geography are generated or changed by this module. Original pixel artwork. */
(()=>{
'use strict';
const W=17,H=13,T=32,X=W*T,Y=H*T;
const $=id=>document.getElementById(id);
const DIR={up:[0,-1],right:[1,0],down:[0,1],left:[-1,0]};
const ORDER=['up','right','down','left'];
const OPP={up:'down',right:'left',down:'up',left:'right'};
const DOOR={up:{x:8,y:1},right:{x:15,y:6},
 down:{x:8,y:11},left:{x:1,y:6}};
const ENTRY={up:{x:8,y:2},right:{x:14,y:6},
 down:{x:8,y:10},left:{x:2,y:6}};
const THEMES=['pillars','crypt','gallery','arcade','sanctum','ruins','vault'];
let state=null,root=null,canvas=null,ctx=null,raf=0,timer=0,held=null,heldAt=0;
function seed(value){let h=2166136261;for(const c of String(value))h=Math.imul(h^c.charCodeAt(0),16777619)>>>0;return h||1}
function rng(value){let n=seed(value);return()=>{n=(Math.imul(n,1664525)+1013904223)>>>0;return n/4294967296}}
function loc(x,y){return {x,y}}
function dist(a,b){return Math.abs(a.x-b.x)+Math.abs(a.y-b.y)}
function randomItem(r,arr){return arr[Math.floor(r()*arr.length)]}
function generateLayout(value,count){
 const r=rng(value),nodes=[{id:0,gx:3,gy:3,edges:{},type:'entrance'}];
 const byPoint=new Map([['3,3',0]]);
 let last=0;
 while(nodes.length<count){
  const choices=[];
  for(const a of nodes)for(const dir of ORDER){
   const v=DIR[dir],x=a.gx+v[0],y=a.gy+v[1];
   if(x<0||x>7||y<0||y>7||byPoint.has(x+','+y))continue;
   choices.push({a,dir,x,y});
  }
  if(!choices.length)throw Error('Dungeon generator exhausted candidate cells');
  const favored=choices.filter(c=>c.a.id===last);
  const c=randomItem(r,favored.length&&r()<.64?favored:choices);
  const id=nodes.length,b={id,gx:c.x,gy:c.y,edges:{},type:'combat'};
  c.a.edges[c.dir]=id;b.edges[OPP[c.dir]]=c.a.id;
  nodes.push(b);byPoint.set(c.x+','+c.y,id);last=id;
 }
 // One optional cross-link makes a route loop without disconnecting the tree.
 const loops=[];
 for(const a of nodes)for(const dir of ORDER){
  const v=DIR[dir],other=byPoint.get((a.gx+v[0])+','+(a.gy+v[1]));
  if(other!==undefined&&other>a.id&&a.edges[dir]===undefined)
   loops.push({a,dir,other});
 }
 if(loops.length&&r()<.8){
  const link=randomItem(r,loops);
  link.a.edges[link.dir]=link.other;
  nodes[link.other].edges[OPP[link.dir]]=link.a.id;
 }
 const queue=[0],depth=Array(count).fill(-1);depth[0]=0;
 for(let i=0;i<queue.length;i++){
  const a=nodes[queue[i]];
  for(const id of Object.values(a.edges))if(depth[id]<0){
   depth[id]=depth[a.id]+1;queue.push(id);
  }
 }
 let boss=0;
 for(const n of nodes)if(depth[n.id]>depth[boss])boss=n.id;
 const leaves=nodes.filter(n=>n.id!==boss&&n.id!==0&&Object.keys(n.edges).length===1);
 const treasure=leaves.sort((a,b)=>depth[b.id]-depth[a.id])[0]?.id ??
  nodes.find(n=>n.id!==0&&n.id!==boss)?.id;
 const shrine=nodes.find(n=>n.id!==0&&n.id!==boss&&n.id!==treasure&&depth[n.id]>=2)?.id;
 for(const n of nodes){
  if(n.id===boss)n.type='boss';
  else if(n.id===treasure)n.type='treasure';
  else if(n.id===shrine)n.type='shrine';
  n.depth=depth[n.id];
  n.template=n.type==='boss'?'sanctum':randomItem(r,THEMES);
  n.cleared=false;n.collected=false;
 }
 return {seed:String(value),count,boss,treasure,shrine,nodes};
}
function blocked(x,y){return x<1||x>=W-1||y<1||y>=H-1||state.walls.has(x+','+y)}
function announce(str){if(state){state.message=str;updateHUD()}}
function updateHUD(){
 const s=state;if(!s)return;
 $('lwDHP').style.width=(100*s.hp/s.maxHP)+'%';
 $('lwDText').textContent='HP '+s.hp+'/'+s.maxHP+' · '+s.visited.size+'/'+s.rooms+' ROOMS · '+s.gold+' test gold';
 $('lwDMessage').textContent=s.message;
 $('lwDTitle').textContent=(s.kind==='challenge'?'WORMHOLE':'RUPTURE')+' · '+s.venue.name;
 $('lwDRoomInfo').textContent=s.current.type.toUpperCase()+' · '+s.current.template.toUpperCase()+' · '+s.current.depth+' STEPS FROM ENTRY';
}
function makeRoom(entry='left'){
 const s=state,n=s.current=s.plan.nodes[s.nodeIndex],r=rng(s.plan.seed+':room:'+n.id);
 s.player=loc(ENTRY[entry].x,ENTRY[entry].y);
 s.face=entry==='left'?'right':entry==='right'?'left':entry==='up'?'down':'up';
 s.walls=new Set();s.props=[];s.enemies=[];s.roomClear=!!n.cleared;
 const wall=(x,y)=>{if(x>=2&&x<=14&&y>=2&&y<=10)s.walls.add(x+','+y)};
 const pillar=(x,y)=>{wall(x,y);s.props.push({x,y,kind:'pillar'})};
 if(n.template==='pillars'||n.template==='sanctum'){
  for(const x of [4,12])for(const y of [3,9])pillar(x,y);
 }else if(n.template==='crypt'){
  for(const x of [4,11])for(const y of [3,8]){
   wall(x,y);wall(x+1,y);s.props.push({x,y,kind:'coffin'});
  }
 }else if(n.template==='gallery'){
  for(let x=3;x<=13;x++){if(x!==8){wall(x,3);wall(x,9)}}
 }else if(n.template==='arcade'){
  for(const x of [5,11])for(const y of [3,4,8,9])wall(x,y);
 }else if(n.template==='ruins'){
  for(let i=0;i<12;i++){const x=3+Math.floor(r()*11),y=3+Math.floor(r()*7);wall(x,y)}
 }else if(n.template==='vault'){
  for(const x of [4,5,11,12])for(const y of [4,8])pillar(x,y);
 }
 // Carved passages guarantee unobstructed travel among every connected door.
 // Decoration may vary, but a room must never be unsolvable by construction.
 for(let x=1;x<=15;x++)for(let y=5;y<=7;y++)s.walls.delete(x+','+y);
 for(let x=7;x<=9;x++)for(let y=1;y<=11;y++)s.walls.delete(x+','+y);
 s.props=s.props.filter(p=>s.walls.has(p.x+','+p.y));
 s.visited.add(n.id);
 if(n.type==='treasure'&&!n.collected){
  n.collected=true;s.gold+=12;s.hp=Math.min(s.maxHP,s.hp+3);
 }
 if(n.type==='shrine'&&!n.collected){
  n.collected=true;s.hp=Math.min(s.maxHP,s.hp+5);
 }
 if(n.type==='treasure'||n.type==='shrine'||n.type==='entrance')s.roomClear=true;
 if(!s.roomClear){
  const boss=n.type==='boss',amount=boss?1:Math.min(5,(s.kind==='challenge'?3:2)+Math.floor(n.depth/3));
  const spots=[];
  for(let y=3;y<=9;y++)for(let x=4;x<=13;x++){
   if(s.walls.has(x+','+y)||dist({x,y},s.player)<4||Math.abs(x-8)<2&&Math.abs(y-6)<2)continue;
   spots.push({x,y});
  }
  for(let i=0;i<amount&&spots.length;i++){
   const k=Math.floor(r()*spots.length),pos=spots.splice(k,1)[0];
   const kind=boss?'guardian':randomItem(r,['slime','skeleton','bat','sentinel']);
   const hp=boss?(s.kind==='challenge'?17:12):kind==='sentinel'?6:kind==='skeleton'?5:kind==='bat'?3:3;
   s.enemies.push({...pos,kind,boss,hp,maxHP:hp,
    lastMove:0,nextSwing:performance.now()+850,windup:0,hitUntil:0,stunnedUntil:0});
   for(let j=spots.length-1;j>=0;j--)if(dist(spots[j],pos)<3)spots.splice(j,1);
  }
 }
 n.cleared=s.roomClear;
 if(n.type==='boss')announce('GUARDIAN ALTAR · defeat the keeper, then claim the central seal');
 else if(n.type==='treasure')announce('TREASURE VAULT · +12 local test gold · doors unlocked');
 else if(n.type==='shrine')announce('SHRINE · you recover health · doors unlocked');
 else if(s.roomClear)announce('ENTRANCE · explore through any open doorway');
 else announce('Clear this chamber to unlock its doors');
 drawMap();
}
function rect(c,x,y,w,h){ctx.fillStyle=c;ctx.fillRect(Math.round(x),Math.round(y),Math.round(w),Math.round(h))}
function drawFloor(now){
 const s=state,n=s.current,dark=s.kind==='challenge',rseed=n.id*27;
 const stone=dark?['#5c5b73','#66677b','#707185']:['#878470','#98937b','#a9a184'];
 rect('#12232b',0,0,X,Y);
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){
  const px=x*T,py=y*T,outer=!x||!y||x===W-1||y===H-1;
  const salt=(x*41+y*71+rseed)%19;
  if(outer){
   rect('#1a2b39',px,py,32,32);
   rect(dark?'#485266':'#52646a',px+1,py+2,30,21);
   rect('#87928d',px+2,py+3,27,4);
   rect('#293d49',px+2,py+23,28,6);rect('#142633',px,py+29,32,3);
   if(x%3===0)rect('#253a44',px+16,py+11,3,12);
  }else{
   rect(stone[(x*3+y+salt)%3],px,py,32,32);
   rect('#c5bca0',px+2,py+2,26,2);rect('#494e56',px+30,py+3,2,27);
   rect('#575d5c',px+2,py+30,29,2);
   if(salt%4===0){
    rect('#6c6d68',px+8,py+15,9,2);
    rect('#d7c6a8',px+14,py+17,4,2);
   }
   if(salt%7===0){rect('#4c5f5a',px+23,py+7,2,5);rect('#c0ae8c',px+25,py+10,3,2)}
   if(s.walls.has(x+','+y)){
    rect('#1a303b',px+2,py+10,30,22);
    rect(dark?'#485466':'#4e6b70',px+1,py+5,30,24);
    rect('#9dadab',px+1,py+3,30,9);
    rect('#d5d4bd',px+3,py+4,22,3);
    rect('#283f4c',px+4,py+27,25,4);
   }
  }
 }
 // Distinct themed, carefully framed masonry and scenic set-pieces.
 for(const prop of s.props){
  const x=prop.x*T,y=prop.y*T;
  if(prop.kind==='coffin'){
   rect('#2c353e',x-3,y+3,65,25);rect('#79796e',x,y,60,23);
   rect('#c6b99a',x+5,y+4,49,4);rect('#423c43',x+29,y+8,3,10);
   rect('#c6b99a',x+23,y+11,15,3);
  }else{
   rect('#233744',x+1,y+8,30,25);
   rect('#98a8a2',x+2,y+1,28,13);
   rect('#cbd1b8',x+5,y+2,21,4);
   rect('#495b60',x+8,y+14,16,15);
  }
 }
 // Floor inlays differ between galleries, vaults, crypts and sanctums.
 for(const [x,y] of [[4,6],[12,6],[8,3],[8,9]]){
  const px=x*T+12,py=y*T+12;
  rect(n.type==='boss'?'#8e658b':'#5b7776',px,py,8,2);
  rect('#d5bd92',px+2,py+2,5,2);rect('#574e57',px+3,py+4,3,2);
 }
 for(const [i,cx] of [3,8,13].entries()){
  const x=cx*T,flame=Math.round(Math.sin(now/160+i)*2);
  ctx.fillStyle='rgba(242,170,73,.18)';
  ctx.beginPath();ctx.arc(x+15,13,36,0,Math.PI*2);ctx.fill();
  rect('#334b50',x+6,7,20,7);rect('#8f6146',x+10,2,12,14);
  rect('#f0a34b',x+12,2+flame,9,13);
  rect('#fff0ac',x+15,4+flame,4,8);
 }
 for(const dir of ORDER){
  const to=n.edges[dir];if(to===undefined)continue;
  const d=DOOR[dir],px=d.x*T,py=d.y*T;
  rect('#263b42',px-1,py-2,34,35);
  rect(s.roomClear?'#83e2be':'#ab6d71',px+3,py+2,26,27);
  rect(s.roomClear?'#326d78':'#3d3c49',px+7,py+5,19,24);
  rect(s.roomClear?'#c1ffdf':'#c7867d',px+10,py+7,12,3);
  if(s.roomClear)rect('#edffc9',px+15,py+12+Math.sin(now/220)*2,3,11);
 }
 if(n.type==='treasure'){
  rect('#3c3440',8*T-15,6*T+6,58,20);
  rect('#966539',8*T-8,6*T-2,44,26);
  rect('#e3be68',8*T-8,6*T-2,44,6);
  rect('#ffe0a3',8*T+9,6*T+4,9,12);
 }else if(n.type==='shrine'){
  rect('#35465b',8*T-14,6*T+7,54,21);
  rect('#7db8c8',8*T-7,6*T-13,39,30);
  rect('#d1f5dc',8*T+8,6*T-8,8,25);
 }else if(n.type==='boss'){
  const x=8*T,y=6*T;
  rect('#232838',x-29,y-24,90,77);rect('#765c69',x-24,y-19,80,67);
  rect('#c2a17b',x-17,y-12,67,53);
  rect(s.roomClear?'#b6f4c6':'#9e5879',x+5,y+7,23,10);
  rect('#f3deb0',x+12,y+9,9,5);
 }
}
function drawEnemy(e,now){
 const x=e.x*T,y=e.y*T,b=Math.round(Math.sin(now/165+e.x)*2);
 const flash=now<e.hitUntil,skin=flash?'#fff6dd':null;
 rect('#142e3388',x+3,y+27,26,4);
 if(e.kind==='guardian'){
  rect('#282944',x-3,y-5+b,38,37);
  rect(skin||'#6c4a89',x,y+1+b,32,27);
  rect('#c697af',x+3,y+2+b,26,5);
  rect('#d4a568',x-4,y-7+b,9,16);rect('#d4a568',x+27,y-7+b,9,16);
  rect('#e6d4a7',x+7,y+9+b,19,15);
  rect('#422b49',x+9,y+14+b,5,4);rect('#422b49',x+20,y+14+b,5,4);
  rect('#f3ab68',x+11,y+15+b,2,2);rect('#f3ab68',x+22,y+15+b,2,2);
  rect('#222a41',x+3,y+26+b,8,6);rect('#222a41',x+22,y+26+b,8,6);
 }else if(e.kind==='skeleton'){
  rect('#5d4260',x+3,y+7+b,28,20);
  rect(skin||'#e2d4af',x+7,y+1+b,20,19);
  rect('#7e5964',x+10,y+9+b,4,5);rect('#7e5964',x+20,y+9+b,4,5);
  rect('#463545',x+14,y+15+b,8,3);
  rect('#b7a77e',x+8,y+21+b,18,5);
  rect('#b7a77e',x+11,y+26+b,4,5);rect('#b7a77e',x+22,y+26+b,4,5);
  rect('#e8d9b7',x+28,y+12+b,3,18);
 }else if(e.kind==='bat'){
  rect(skin||'#6a5e96',x,y+11+b,32,10);
  rect('#a18dc4',x+4,y+7+b,8,9);rect('#a18dc4',x+20,y+7+b,8,9);
  rect('#343450',x+10,y+14+b,14,12);
  rect('#e9bd89',x+12,y+16+b,3,3);rect('#e9bd89',x+20,y+16+b,3,3);
  rect('#d8bfd4',x+14,y+24+b,7,3);
 }else if(e.kind==='sentinel'){
  rect('#2b4256',x+4,y+1+b,24,30);
  rect(skin||'#7994a4',x+7,y+3+b,20,21);
  rect('#c0c9b3',x+9,y+6+b,16,6);
  rect('#273e4a',x+10,y+14+b,5,5);rect('#273e4a',x+20,y+14+b,5,5);
  rect('#f0bb6e',x+13,y+18+b,8,2);
  rect('#344a56',x+2,y+22+b,7,9);rect('#344a56',x+26,y+22+b,7,9);
 }else{
  rect('#2b6a65',x+2,y+20+b,28,11);
  rect(skin||'#64bf9e',x+4,y+13+b,26,16);
  rect('#bceac0',x+8,y+14+b,17,4);
  rect('#255e58',x+10,y+22+b,4,3);rect('#255e58',x+23,y+22+b,4,3);
  rect('#e5d99a',x+16,y+26+b,4,3);
 }
 if(e.windup){
  rect('#f7bd77',x+1,y+1,30,3);
  rect('#fff3c6',x+5,y+5,22,2);
 }
 rect('#2e2e3f',x+2,y-11,28,5);
 rect('#eea27e',x+4,y-10,24*Math.max(0,e.hp)/e.maxHP,3);
}
function drawHero(now){
 const s=state,x=s.player.x*T,y=s.player.y*T;
 const walking=now-s.lastStep<220,step=walking?Math.round(Math.sin(now/75)*2):0;
 const hit=now<s.hurtUntil;if(hit&&Math.floor(now/70)%2===1)return;
 const blue=seed(s.warrior)%3,cloak=['#573f78','#366278','#657249'][blue];
 const tunic=['#468a83','#537ab2','#b07a57'][blue];
 const py=y-13+step;
 rect('#1b2b31aa',x+3,y+28,27,5);
 // A fully original four-facing 16-bit adventurer: mantle, layered armor,
 // hair, face, gloves, greaves and a visible sword hand.
 rect('#252c43',x+8,py+25,7,19);rect('#252c43',x+20,py+25,7,19);
 rect('#d1b88e',x+7,py+38,9,5);rect('#d1b88e',x+19,py+38,9,5);
 rect(cloak,x+3,py+13,29,22);
 rect('#d6b26a',x+6,py+16,24,4);
 rect(tunic,x+9,py+17,19,20);
 rect('#e2bf86',x+12,py+29,14,4);
 rect('#d9b18d',x+4,py+22,6,9);rect('#d9b18d',x+29,py+22,6,9);
 rect('#9dbabb',x+3,py+16,9,10);rect('#9dbabb',x+25,py+16,9,10);
 rect('#425569',x+9,py+33,19,3);
 if(s.face==='up'){
  rect('#49394a',x+11,py+1,18,17);
  rect('#796276',x+13,py+3,14,13);
  rect('#e4c992',x+13,py+14,12,4);
 }else if(s.face==='left'||s.face==='right'){
  const facingRight=s.face==='right';
  rect('#eab997',x+10,py+3,17,16);
  rect('#59415b',x+9,py+1,18,8);
  rect('#392e41',x+(facingRight?22:11),py+10,3,3);
  rect('#caa47f',x+(facingRight?25:9),py+14,3,3);
 }else{
  rect('#eab997',x+10,py+4,18,16);
  rect('#59415b',x+9,py+1,20,10);
  rect('#b48564',x+13,py+10,13,3);
  rect('#332d41',x+13,py+12,3,3);rect('#332d41',x+23,py+12,3,3);
 }
 rect('#f4d79c',x+17,py+21,5,7);
 if(now<s.attackUntil){
  const [dx,dy]=DIR[s.face],phase=(s.attackUntil-now)/205;
  const sx=x+18+dx*24,sy=y+7+dy*20;
  rect('#e6faff',sx-8,sy-7,15,5);
  rect('#f8fcff',sx-4,sy-12,6,21);
  rect('#84ccd7',sx+4,sy-5,5,17);
  rect('#fff0b6',sx-10,sy+9,21,4);
  rect('#c9e8e3',sx-15+phase*4,sy-14,6,5);
 }
}
function drawMap(){
 const map=$('lwDMap');if(!map||!state)return;
 const g=map.getContext('2d'),s=state;g.clearRect(0,0,170,90);
 g.fillStyle='#121c30';g.fillRect(0,0,170,90);
 const xx=n=>10+n.gx*19,yy=n=>8+n.gy*10;
 for(const n of s.plan.nodes)for(const id of Object.values(n.edges)){
  const m=s.plan.nodes[id];
  g.strokeStyle='#4f6173';g.lineWidth=3;g.beginPath();g.moveTo(xx(n)+6,yy(n)+5);
  g.lineTo(xx(m)+6,yy(m)+5);g.stroke();
 }
 for(const n of s.plan.nodes){
  const visible=s.visited.has(n.id)||n.id===s.nodeIndex;
  g.fillStyle=n.id===s.nodeIndex?'#ffe0a3':visible?(n.type==='boss'?'#bc7cca':n.type==='treasure'?'#d3b364':'#7cccb1'):'#394755';
  g.fillRect(xx(n),yy(n),12,9);
  if(n.id===s.nodeIndex){g.strokeStyle='#fff9c9';g.lineWidth=1;g.strokeRect(xx(n)-2,yy(n)-2,16,13)}
 }
}
function render(now){
 if(!state||root.hidden)return;
 const s=state;ctx.imageSmoothingEnabled=false;
 drawFloor(now);
 for(const e of s.enemies)drawEnemy(e,now);
 drawHero(now);
 for(const fx of s.sparks){
  if(fx.until<=now)continue;
  const f=(fx.until-now)/270,x=fx.x*T+16,y=fx.y*T+15;
  rect('#ffedb2',x-10*f,y-9*f,5,5);
  rect('#b2f1ef',x+8*f,y-6*f,4,6);
  rect('#edaa8a',x,y+9*f,3,4);
 }
 s.sparks=s.sparks.filter(fx=>fx.until>now);
 if(now<s.hurtUntil)rect('rgba(255,75,72,.10)',0,0,X,Y);
 if(s.completed||s.defeated){
  rect('#121c31ed',26,132,X-52,149);
  ctx.strokeStyle='#e7c689';ctx.lineWidth=4;ctx.strokeRect(26,132,X-52,149);
  ctx.textAlign='center';ctx.fillStyle='#ffdda3';ctx.font='bold 22px monospace';
  ctx.fillText(s.completed?'DUNGEON CONQUERED':'PARTY DEFEATED',X/2,187);
  ctx.fillStyle='#d5efe8';ctx.font='13px monospace';
  ctx.fillText(s.completed?s.gold+' local test gold · '+s.kills+' foes':'Restart or return to the world',X/2,216);
  ctx.textAlign='left';
 }
 raf=requestAnimationFrame(render);
}
function step(dir){
 const s=state;if(!s||s.completed||s.defeated||!DIR[dir])return false;
 s.face=dir;const [dx,dy]=DIR[dir],x=s.player.x+dx,y=s.player.y+dy;
 if(blocked(x,y)||s.enemies.some(e=>e.x===x&&e.y===y))return false;
 s.player=loc(x,y);s.lastStep=performance.now();
 const destination=s.current.edges[dir],door=DOOR[dir];
 if(s.roomClear&&destination!==undefined&&x===door.x&&y===door.y){
  s.nodeIndex=destination;makeRoom(OPP[dir]);return true;
 }
 if(s.roomClear&&s.current.type==='boss'&&x===8&&y===6){
  s.completed=true;announce('GUARDIAN SEAL CLAIMED · local prototype rewards only');
  $('lwDResult').hidden=false;
  $('lwDResult').textContent='VICTORY · '+s.gold+' test gold · '+s.kills+' enemies';
 }
 return true;
}
function attack(){
 const s=state,now=performance.now();
 if(!s||s.completed||s.defeated||now<s.nextAttack)return false;
 s.nextAttack=now+325;s.attackUntil=now+205;
 const [dx,dy]=DIR[s.face],front=loc(s.player.x+dx,s.player.y+dy);
 let hit=false;
 for(const e of [...s.enemies]){
  // A narrow 3-tile forward arc. No sideways or behind-the-back hits.
  const forward=(e.x-s.player.x)*dx+(e.y-s.player.y)*dy;
  const side=Math.abs((e.x-s.player.x)*dy-(e.y-s.player.y)*dx);
  if(forward!==1||side>1)continue;
  hit=true;e.hp-=2;e.hitUntil=now+180;e.stunnedUntil=now+250;
  e.windup=0;s.sparks.push({x:e.x,y:e.y,until:now+270});
  if(e.hp<=0){
   s.enemies.splice(s.enemies.indexOf(e),1);
   s.gold+=e.boss?40:4;s.kills++;
  }else if(!e.boss){
   const xx=e.x+dx,yy=e.y+dy;
   if(!blocked(xx,yy)&&!(xx===s.player.x&&yy===s.player.y)&&
     !s.enemies.some(other=>other!==e&&other.x===xx&&other.y===yy)){
    e.x=xx;e.y=yy;
   }
  }
 }
 if(!s.enemies.length&&!s.roomClear){
  s.roomClear=true;s.current.cleared=true;
  announce(s.current.type==='boss'?'GUARDIAN DEFEATED · claim the central seal':'CHAMBER CLEARED · doors unlocked');
 }else if(hit)announce('SWORD STRIKE!');
 return hit;
}
function chase(enemy){
 const s=state,seen=new Set([enemy.x+','+enemy.y]),queue=[{x:enemy.x,y:enemy.y,first:null}];
 const occupied=(x,y)=>blocked(x,y)||(x===s.player.x&&y===s.player.y)||
  s.enemies.some(other=>other!==enemy&&other.x===x&&other.y===y);
 for(let i=0;i<queue.length;i++){
  const p=queue[i];
  if(dist(p,s.player)===1){if(p.first){enemy.x=p.first.x;enemy.y=p.first.y}return}
  const directions=ORDER.slice().sort((a,b)=>{
   const [ax,ay]=DIR[a],[bx,by]=DIR[b];
   return dist(loc(p.x+ax,p.y+ay),s.player)-dist(loc(p.x+bx,p.y+by),s.player);
  });
  for(const dir of directions){
   const [dx,dy]=DIR[dir],x=p.x+dx,y=p.y+dy,key=x+','+y;
   if(seen.has(key)||occupied(x,y))continue;
   seen.add(key);queue.push({x,y,first:p.first||loc(x,y)});
  }
 }
}
function tick(){
 const s=state;if(!s||s.completed||s.defeated)return;
 const now=performance.now();
 for(const e of s.enemies){
  if(now<e.stunnedUntil)continue;
  if(dist(e,s.player)===1){
   if(e.windup&&now>=e.windup){
    e.windup=0;e.nextSwing=now+(e.boss?1200:950);
    if(now>=s.invulnUntil){
     s.hp=Math.max(0,s.hp-(e.boss?3:s.kind==='challenge'?2:1));
     s.invulnUntil=now+770;s.hurtUntil=now+430;
     announce(s.hp?'HIT · dodge away or counterattack':'DEFEATED · retry or return to world');
     if(!s.hp)s.defeated=true;
    }
   }else if(!e.windup&&now>=e.nextSwing){
    e.windup=now+(e.boss?530:e.kind==='bat'?280:420);
   }
  }else{
   if(e.windup)e.windup=0;
   if(now-e.lastMove>(s.kind==='challenge'?430:550)){
    e.lastMove=now;chase(e);
   }
  }
 }
 if(held&&now-heldAt>145){step(held);heldAt=now}
 updateHUD();
}
function initialize(){
 if(root)return;
 root=document.createElement('section');root.id='lwDungeonStage';root.hidden=true;
 root.innerHTML='<header><strong id="lwDTitle">DUNGEON</strong><button id="lwDExit">EXIT ×</button></header>'+
  '<div class="lwDStats"><div class="lwDHealth"><span id="lwDHP"></span></div><span id="lwDText"></span></div>'+
  '<div class="lwDInfo"><canvas id="lwDMap" width="170" height="90" aria-label="Explored dungeon minimap"></canvas>'+
  '<span id="lwDRoomInfo"></span></div>'+
  '<div class="lwDView"><canvas id="lwDCanvas" width="'+X+'" height="'+Y+'" aria-label="Playable procedurally generated fantasy dungeon"></canvas></div>'+
  '<p id="lwDMessage" aria-live="polite"></p>'+
  '<div class="lwDControls"><div class="lwDPad">'+
  '<button data-dmove="up" class="up" aria-label="Move up">▲</button>'+
  '<button data-dmove="left" class="left" aria-label="Move left">◀</button>'+
  '<button data-dmove="down" class="down" aria-label="Move down">▼</button>'+
  '<button data-dmove="right" class="right" aria-label="Move right">▶</button></div>'+
  '<button id="lwDAttack" aria-label="Attack">⚔<small>ATTACK</small></button></div>'+
  '<div id="lwDResult" hidden></div>'+
  '<footer><button id="lwDRetry">NEW LAYOUT</button><button id="lwDReturn">RETURN TO WORLD</button></footer>';
 const css=document.createElement('style');css.textContent=
 '#lwDungeonStage[hidden],#lwDResult[hidden]{display:none!important}'+
 '#lwDungeonStage{position:fixed;inset:0;z-index:1001;display:flex;flex-direction:column;'+
 'align-items:center;justify-content:space-between;box-sizing:border-box;overflow:auto;'+
 'padding:calc(env(safe-area-inset-top) + 5px) 9px calc(env(safe-area-inset-bottom) + 5px);'+
 'background:radial-gradient(circle at 50% 35%,#304451,#071622 80%);'+
 'color:#f0ddb5;font:12px monospace;touch-action:none}'+
 '#lwDungeonStage header,#lwDungeonStage footer{width:min(100%,700px);display:flex;gap:8px;'+
 'justify-content:space-between;align-items:center;padding:4px 2px}'+
 '#lwDungeonStage strong{color:#f9dda8;font-size:13px}'+
 '#lwDungeonStage button{touch-action:none;font-family:monospace;font-weight:bold;'+
 'border:2px solid #c8b784;background:#304e57;color:#f7e9d0;padding:9px;border-radius:7px}'+
 '.lwDStats{width:min(100%,700px);display:flex;align-items:center;gap:9px;min-height:27px}'+
 '.lwDHealth{width:78px;height:13px;background:#6b3948;border:2px solid #d5c18c}'+
 '#lwDHP{display:block;height:100%;background:#85c985;width:100%}'+
 '.lwDInfo{width:min(100%,700px);display:flex;gap:12px;align-items:center;'+
 'background:#132438ce;border:1px solid #516a73;padding:3px 6px;min-height:64px}'+
 '#lwDMap{height:57px;width:110px;image-rendering:pixelated;border:1px solid #7d8b7f}'+
 '#lwDRoomInfo{font-size:11px;line-height:1.4;color:#ead6a8}'+
 '.lwDView{width:min(100%,700px);flex:1;min-height:0;display:flex;align-items:center}'+
 '#lwDCanvas{display:block;width:100%;max-height:52vh;aspect-ratio:17 / 13;object-fit:contain;'+
 'image-rendering:pixelated;border:3px solid #cfb680;background:#1c293a}'+
 '#lwDMessage{text-align:center;min-height:20px;margin:4px;font-size:11px;color:#e8d397}'+
 '.lwDControls{width:min(100%,530px);min-height:140px;display:flex;justify-content:space-around;align-items:center}'+
 '.lwDPad{display:grid;grid-template-columns:repeat(3,48px);grid-template-rows:repeat(3,42px)}'+
 '.lwDPad button{font-size:22px!important;padding:3px!important}'+
 '.lwDPad .up{grid-column:2;grid-row:1}.lwDPad .left{grid-column:1;grid-row:2}'+
 '.lwDPad .down{grid-column:2;grid-row:3}.lwDPad .right{grid-column:3;grid-row:2}'+
 '#lwDAttack{width:88px;height:88px;border-radius:50%!important;background:#79536b!important;font-size:32px}'+
 '#lwDAttack small{display:block;font-size:10px}'+
 '#lwDungeonStage footer button{flex:1;min-height:42px}'+
 '#lwDResult{color:#baffce;text-align:center;padding:5px}'+
 '@media(max-height:690px){.lwDControls{min-height:108px}.lwDPad{transform:scale(.83)}'+
 '#lwDAttack{width:73px;height:73px}.lwDInfo{min-height:48px}#lwDMap{height:44px}}';
 document.head.appendChild(css);document.body.appendChild(root);
 canvas=$('lwDCanvas');ctx=canvas.getContext('2d');
 for(const b of root.querySelectorAll('[data-dmove]')){
  const dir=b.dataset.dmove;
  b.addEventListener('pointerdown',e=>{
   e.preventDefault();b.setPointerCapture?.(e.pointerId);
   held=dir;step(dir);heldAt=performance.now();
  });
  for(const type of ['pointerup','pointercancel','lostpointercapture'])
   b.addEventListener(type,()=>{if(held===dir)held=null});
 }
 $('lwDAttack').addEventListener('pointerdown',e=>{e.preventDefault();attack()});
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
 const kind=venue.type,rooms=kind==='challenge'?14:10;
 const runSeed=String(venue.id||venue.name)+':'+Date.now()+':'+Math.random();
 state={venue:{id:String(venue.id||venue.name),name:String(venue.name||'Rift'),type:kind},
  warrior:warrior||'Training Warrior',kind,rooms,plan:generateLayout(runSeed,rooms),
  nodeIndex:0,visited:new Set(),hp:kind==='challenge'?14:18,
  maxHP:kind==='challenge'?14:18,player:loc(2,6),walls:new Set(),props:[],
  enemies:[],face:'right',gold:0,kills:0,nextAttack:0,
  attackUntil:0,invulnUntil:0,hurtUntil:0,lastStep:0,sparks:[],
  completed:false,defeated:false,roomClear:false,message:''};
 root.hidden=false;document.body.classList.add('in-dungeon');$('lwDResult').hidden=true;
 makeRoom();timer=setInterval(tick,100);
 const loop=now=>{if(!state||root.hidden)return;render(now)};
 raf=requestAnimationFrame(loop);return true;
}
function stop(){
 if(timer){clearInterval(timer);timer=0}if(raf){cancelAnimationFrame(raf);raf=0}
 held=null;if(root)root.hidden=true;document.body.classList.remove('in-dungeon');state=null;
}
function snapshot(){
 if(!state)return {active:false};
 const s=state;
 return {active:!root.hidden,room:s.visited.size,rooms:s.rooms,
  hp:s.hp,maxHP:s.maxHP,enemies:s.enemies.length,cleared:s.roomClear,
  completed:s.completed,defeated:s.defeated,kind:s.kind,
  player:{...s.player},face:s.face,gold:s.gold,kills:s.kills,
  bossHP:s.enemies.find(e=>e.boss)?.hp??null,
  node:s.nodeIndex,roomType:s.current.type,template:s.current.template,
  exits:{...s.current.edges},layoutSeed:s.plan.seed,visited:[...s.visited],
  // These are only local fictional dungeon geometry, never user location.
  walls:[...s.walls]};
}
function inspectLayout(value,kind='rupture'){
 const plan=generateLayout(value,kind==='challenge'?14:10);
 return {seed:plan.seed,count:plan.count,boss:plan.boss,treasure:plan.treasure,
  nodes:plan.nodes.map(n=>({id:n.id,gx:n.gx,gy:n.gy,edges:{...n.edges},
    depth:n.depth,type:n.type,template:n.template}))};
}
function devAllowed(){return new URLSearchParams(location.search).has('dev')||window.LibationDeveloper?.enabled()}
function debugClearRoom(){
 if(!state||!devAllowed())return false;
 state.enemies=[];state.roomClear=true;state.current.cleared=true;
 announce('DEV TEST: enemies cleared · doors unlocked');return true;
}
function debugCombatEncounter(){
 if(!state||!devAllowed())return false;
 const s=state,[dx,dy]=DIR[s.face],x=s.player.x+dx,y=s.player.y+dy;
 s.enemies=[{x,y,hp:2,maxHP:2,kind:'slime',boss:false,lastMove:0,
  nextSwing:performance.now()+1200,windup:0,hitUntil:0,stunnedUntil:0}];
 s.roomClear=false;s.current.cleared=false;s.nextAttack=0;
 announce('DEV COMBAT CHECK: strike the enemy in front');return true;
}
function debugBossEncounter(){
 if(!state||!devAllowed())return false;
 const s=state;s.nodeIndex=s.plan.boss;makeRoom();
 s.player=loc(2,6);s.face='right';
 s.enemies=[{x:3,y:6,hp:s.kind==='challenge'?17:12,
  maxHP:s.kind==='challenge'?17:12,kind:'guardian',boss:true,
  lastMove:performance.now(),nextSwing:performance.now()+850,
  windup:0,hitUntil:0,stunnedUntil:0}];
 s.roomClear=false;s.current.cleared=false;
 s.hp=s.maxHP;s.hurtUntil=0;s.nextAttack=0;s.invulnUntil=performance.now()+700;
 announce('DEV BOSS CHECK: fight a full-health guardian');
 return true;
}
window.LibationDungeon=Object.freeze({start,stop,snapshot,move:step,attack,
 inspectLayout,debugClearRoom,debugCombatEncounter,debugBossEncounter});
})();