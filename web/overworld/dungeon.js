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
 s.projectiles=[];s.warnings=[];s.player=loc(ENTRY[entry].x,ENTRY[entry].y);
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
   const roster=s.kind==='challenge'?
    ['specter','sentinel','thornbound','skeleton','mimic','bat','slime']:
    ['slime','skeleton','bat','thornbound','sentinel','mimic','specter'];
   const kind=boss?'guardian':randomItem(r,roster);
   const hp=boss?(s.kind==='challenge'?17:12):
    kind==='sentinel'?7:kind==='skeleton'?5:
    kind==='thornbound'?5:kind==='mimic'?5:kind==='specter'?4:3;
   s.enemies.push({...pos,kind,boss,hp,maxHP:hp,awake:kind!=='mimic',
    lastMove:performance.now(),nextSwing:performance.now()+1100,
    windup:0,hitUntil:0,stunnedUntil:0,blocking:false,phase:1});
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
 // Seven hand-dressed chamber identities built over the procedural tile grid.
 // Decorations never change collision and never imply real venue interiors.
 const style=n.template;
 if(style==='gallery'||style==='crypt'){
  for(let tx=3;tx<=13;tx++){
   for(const ty of (style==='crypt'?[4,8]:[5,6,7])){
    const x=tx*T,y=ty*T;
    if(s.walls.has(tx+','+ty))continue;
    rect(style==='gallery'?'#67536b':'#514856',x+3,y+3,26,26);
    rect(style==='gallery'?'#b58b70':'#978080',x+4,y+4,24,2);
    rect('#a89b87',x+4,y+26,24,2);
    if(tx%3===0){
     rect('#d6b488',x+13,y+11,7,7);rect('#3e4758',x+15,y+13,3,3);
    }
   }
  }
 }
 if(style==='sanctum'||style==='vault'){
  // Bronze temple seal: the guardian room visibly differs from combat halls.
  for(let k=0;k<3;k++){
   ctx.strokeStyle=k===1?'#d4b77c':'#6e6e73';
   ctx.lineWidth=3;ctx.strokeRect(6*T+12+k*9,4*T+13+k*8,4*T+6-k*18,4*T+4-k*16);
  }
  for(const [gx,gy] of [[6,4],[10,4],[6,8],[10,8]]){
   const x=gx*T,y=gy*T;
   rect('#5b4b58',x+11,y+6,15,22);rect('#d1aa67',x+12,y+7,13,3);
   rect('#f7dba1',x+18,y+12,3,8);
  }
 }
 if(style==='ruins'){
  for(const [gx,gy] of [[3,4],[13,4],[4,9],[12,9]]){
   const x=gx*T,y=gy*T;
   if(s.walls.has(gx+','+gy))continue;
   rect('#4c7167',x+3,y+13,22,4);
   rect('#75977a',x+10,y+6,3,18);
   rect('#3a5e57',x+19,y+19,6,5);
  }
 }
 if(style==='arcade'||style==='pillars'){
  for(const [gx,gy] of [[4,4],[12,4],[4,8],[12,8]]){
   const x=gx*T,y=gy*T;
   rect('#31404b',x-9,y-6,47,8);
   rect('#a5a794',x-7,y-8,43,4);
   rect('#6d8080',x-5,y+2,6,16);rect('#6d8080',x+31,y+2,6,16);
   rect('#d6bd8d',x-5,y+17,43,3);
  }
 }
 // Room-specific wall banners, braziers and foreground architecture.
 for(const tile of [2,14]){
  const x=tile*T,y=2*T;
  rect('#232c3b',x+4,y+2,24,27);
  rect(style==='sanctum'?'#774b78':style==='crypt'?'#5a506f':'#3c6470',
   x+7,y+2,18,22);
  rect('#d6aa72',x+10,y+3,12,3);
  rect('#e6d7aa',x+14,y+10,4,9);
  rect('#242f3c',x+12,y+21,8,6);
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
// Selection and gameplay share the exact same four-direction, five-state atlas.
const HERO_W=48,HERO_H=64,ACTIONS=['idle','walk','attack','hurt','defeat'];
const heroCache=new Map();
function identity(v){
 return v&&typeof v==='object'?
  {id:String(v.id||v.code||'training'),name:String(v.name||'Warrior'),
   faction:String(v.faction||'Pirate'),gender:v.gender==='female'?'female':'male'}:
  {id:'training',name:String(v||'Training Warrior'),faction:'Pirate',gender:'male'};
}
function pose(g,who,dir,action,frame){
 const woman=who.gender==='female',walking=action==='walk',attacking=action==='attack';
 const walk=walking?[0,3,0,-3][frame]:0;
 const bodyShift=action==='hurt'?(frame%2?0:3):action==='idle'&&frame%2?1:0;
 const swing=attacking?[0,5,11,4][frame]:0;
 const coat=woman?'#245b98':'#91333c',coatLight=woman?'#64b7de':'#c95e4d';
 const dark=woman?'#193b64':'#2d2637',hair=woman?'#f0c36d':'#362737';
 const gold='#ddba73',skin=woman?'#f1bf94':'#d6a077';
 const p=(c,x,y,w,h)=>{g.fillStyle=c;g.fillRect(x,y,w,h)};
 g.save();
 if(dir==='left'){g.translate(48,0);g.scale(-1,1)}
 if(action==='defeat'){g.translate(-4,43);g.rotate(-Math.PI/2);g.translate(4,-43)}
 p('#18313877',7,57,35,4);
 // Two separate boots animate out of phase on actual walking frames.
 for(let i=0;i<2;i++){
  const x=i?28:14,dy=bodyShift+(i?walk:-walk);
  p('#242b42',x,40+dy,8,15);p('#6f7480',x+2,43+dy,4,7);
  p('#262334',x-2,54+dy,13,5);p(gold,x-2,55+dy,12,2);
 }
 // Distinctive red pirate captain or blue-gold magic corsair silhouette.
 p('#1b263b',8,24+bodyShift,31,27);
 p(dark,8,28+bodyShift,33,21);
 p(coat,12,27+bodyShift,25,21);
 p(coatLight,15,30+bodyShift,18,12);
 p(gold,15,39+bodyShift,18,3);p('#2b3040',21,41+bodyShift,8,5);
 if(woman){
  p('#133e66',8,25+bodyShift,6,26);p('#215c9a',35,25+bodyShift,6,26);
  p('#f3ce7a',9,45+bodyShift,3,4);
 }else{
  p('#b34746',8,41+bodyShift,6,9);p('#b34746',35,40+bodyShift,5,10);
  p('#edd28f',10,31+bodyShift,5,5);
 }
 const handY=attacking?Math.max(0,swing-2):0;
 p('#253144',7,29+bodyShift,9,14);p(gold,8,29+bodyShift,9,4);
 p(skin,9,40+bodyShift,7,6);
 p('#263548',32,28+bodyShift-handY,10,15);
 p(gold,32,29+bodyShift-handY,9,4);
 p(skin,34,40+bodyShift-handY,7,6);
 // True direction-specific faces, hair and headgear.
 p(hair,14,7+bodyShift,24,22);
 if(dir==='up'){
  p('#7e5e58',17,13+bodyShift,20,15);
  p(hair,16,10+bodyShift,21,8);
 }else{
  p(skin,16,13+bodyShift,21,16);
  if(dir==='down'){
   p('#22263a',21,23+bodyShift,3,3);
   p('#22263a',31,23+bodyShift,3,3);
   p('#a77862',26,26+bodyShift,4,2);
  }else{
   p('#283042',32,21+bodyShift,3,3);
   p('#ba8b73',36,24+bodyShift,2,2);
  }
 }
 if(woman){
  p(hair,12,16+bodyShift,6,20);p(hair,36,16+bodyShift,5,18);
  p('#215d97',13,8+bodyShift,27,8);
  p('#4c99be',16,4+bodyShift,19,8);
  p('#13395c',7,13+bodyShift,36,6);p(gold,10,14+bodyShift,30,2);
  p('#fff0b5',24,8+bodyShift,5,5);p('#f1e0a0',34,0+bodyShift,3,9);
 }else{
  p('#101c2c',9,5+bodyShift,30,10);
  p('#262839',5,12+bodyShift,38,7);
  p(gold,8,12+bodyShift,33,3);
  p('#152032',13,2+bodyShift,24,7);
  p('#f1dfbb',24,9+bodyShift,5,4);
 }
 if(attacking){
  const arc=[11,4,-3,0][frame],y=17+bodyShift-handY;
  p('#a2d7e0',39+arc,y-11,4,26);
  p('#f5ffff',40+arc,y-12,3,22);
  p(gold,34+arc,y+12,12,4);
  p('#d6faf2',34+arc,y-16,5,6);
 }else if(woman){
  p('#816040',40,17+bodyShift,3,29);
  p('#5bb6df',35,8+bodyShift,12,11);
  p('#fff6c3',39,11+bodyShift,5,5);
 }else{
  p('#abbccf',40,21+bodyShift,4,24);
  p('#f0f5e8',40,20+bodyShift,2,18);
  p(gold,35,42+bodyShift,12,4);
 }
 if(action==='hurt'){p('#ffe3cd99',14,16,21,13);p('#f5887a',8,23,5,8)}
 g.restore();
}
function heroAtlas(v){
 const who=identity(v),key=who.id+':'+who.gender+':'+who.faction;
 if(heroCache.has(key))return heroCache.get(key);
 const atlas=document.createElement('canvas');
 atlas.width=48*4*ACTIONS.length;atlas.height=64*4;
 const g=atlas.getContext('2d');g.imageSmoothingEnabled=false;
 for(let dir=0;dir<4;dir++)for(let a=0;a<ACTIONS.length;a++)for(let f=0;f<4;f++){
  g.save();g.translate((a*4+f)*48,dir*64);
  pose(g,who,ORDER[dir],ACTIONS[a],f);g.restore();
 }
 if(heroCache.size>16)heroCache.clear();
 heroCache.set(key,atlas);return atlas;
}
function previewWarrior(v,dir='down',action='idle',frame=0){
 const atlas=heroAtlas(v),c=document.createElement('canvas');
 c.width=48;c.height=64;const g=c.getContext('2d');
 g.imageSmoothingEnabled=false;
 const a=Math.max(0,ACTIONS.indexOf(action)),f=Math.max(0,Math.min(3,frame|0));
 const row=Math.max(0,ORDER.indexOf(dir));
 g.drawImage(atlas,(a*4+f)*48,row*64,48,64,0,0,48,64);
 return c.toDataURL('image/png');
}
function heroAnimation(now){
 const s=state;if(!s)return 'idle';
 if(s.defeated)return 'defeat';
 if(now<s.hurtUntil)return 'hurt';
 if(now<s.attackUntil)return 'attack';
 if(now<s.walkUntil)return 'walk';
 return 'idle';
}
function drawHero(now){
 const s=state,x=s.player.x*T,y=s.player.y*T,action=heroAnimation(now);
 const frame=action==='walk'?s.walkFrame%4:
  action==='attack'?Math.max(0,Math.min(3,Math.floor((205-(s.attackUntil-now))/55))):
  action==='hurt'?Math.floor(now/85)%4:action==='defeat'?3:Math.floor(now/550)%2;
 const sheet=heroAtlas(s.warrior);
 ctx.drawImage(sheet,(ACTIONS.indexOf(action)*4+frame)*48,ORDER.indexOf(s.face)*64,
  48,64,x-8,y-31,48,64);
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
 const s=state;ctx.imageSmoothingEnabled=true;
 const art=window.LibationDungeonArt;
 if(art)art.drawRoom(ctx,s,now);else drawFloor(now);
 for(const e of s.enemies){
  if(art)art.drawEnemy(ctx,e,now,s.kind);else drawEnemy(e,now);
 }
 if(art)art.drawEffects(ctx,s,now);
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
 s.player=loc(x,y);s.lastStep=performance.now();s.walkUntil=s.lastStep+230;s.walkFrame=(s.walkFrame+1)%4;
 // A doorway responds to the tile reached, regardless of whether the
 // player approached its threshold from the side or straight on.
 if(s.roomClear)for(const side of ORDER){
  const destination=s.current.edges[side],door=DOOR[side];
  if(destination!==undefined&&x===door.x&&y===door.y){
   s.nodeIndex=destination;makeRoom(OPP[side]);return true;
  }
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
  hit=true;
  const parried=e.kind==='skeleton'&&e.blocking&&e.hp>2;
  e.hp-=parried?1:2;
  e.blocking=false;e.awake=true;
  e.hitUntil=now+200;e.stunnedUntil=now+(e.boss?230:320);
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
  s.projectiles=[];s.warnings=[];
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
function hurtPlayer(s,damage,now){
 s.hp=Math.max(0,s.hp-damage);
 s.invulnUntil=now+780;s.hurtUntil=now+440;
 announce(s.hp?'HIT · dodge and counterattack':'DEFEATED · retry or return to world');
 if(!s.hp)s.defeated=true;
}
function tick(){
 const s=state;if(!s||s.completed||s.defeated)return;
 const now=performance.now();
 // Projectile attacks move independently of pursuit. Warnings are fair:
 // a visible marker appears before damage and can be dodged.
 for(const shot of [...s.projectiles]){
  if(now-shot.started>shot.lifetime){
   s.projectiles.splice(s.projectiles.indexOf(shot),1);continue;
  }
  if(now<shot.nextMove)continue;
  shot.nextMove=now+220;
  const xx=shot.x+shot.dx,yy=shot.y+shot.dy;
  if(blocked(xx,yy)){
   s.projectiles.splice(s.projectiles.indexOf(shot),1);continue;
  }
  shot.x=xx;shot.y=yy;
  if(xx===s.player.x&&yy===s.player.y){
   s.projectiles.splice(s.projectiles.indexOf(shot),1);
   if(now>=s.invulnUntil)hurtPlayer(s,1,now);
  }
 }
 for(const warning of [...s.warnings]){
  if(now<warning.until)continue;
  s.warnings.splice(s.warnings.indexOf(warning),1);
  if(dist(warning,s.player)<=warning.radius&&now>=s.invulnUntil)
   hurtPlayer(s,warning.kind==='root'?1:2,now);
 }
 for(const e of s.enemies){
  if(now<e.stunnedUntil)continue;
  const distance=dist(e,s.player);
  if(e.boss){e.phase=e.hp<=Math.ceil(e.maxHP*.52)?2:1;
   if(e.phase===2&&distance<=2&&now>=e.nextPulse){
    e.nextPulse=now+2600;
    s.warnings.push({x:e.x,y:e.y,radius:1.65,kind:'pulse',
     started:now,until:now+800});
   }
  }
  if(e.kind==='mimic'&&!e.awake){
   if(distance<=3){e.awake=true;e.nextSwing=now+700}
   else continue;
  }
  if(e.kind==='specter'&&distance>=2&&distance<=6&&now>=e.nextSwing){
   const dx=Math.abs(s.player.x-e.x)>Math.abs(s.player.y-e.y)?
    Math.sign(s.player.x-e.x):0;
   const dy=dx?0:Math.sign(s.player.y-e.y);
   s.projectiles.push({x:e.x,y:e.y,dx,dy,kind:'rift',
    nextMove:now+230,started:now,lifetime:1600});
   e.nextSwing=now+1700;e.lastMove=now;continue;
  }
  if(e.kind==='thornbound'&&distance>=2&&distance<=4&&now>=e.nextSwing){
   s.warnings.push({x:s.player.x,y:s.player.y,kind:'root',radius:.5,
    started:now,until:now+720});
   e.nextSwing=now+1700;continue;
  }
  if(e.kind==='skeleton')e.blocking=distance===1&&now>=e.nextSwing-450;
  if(distance===1){
   if(e.windup&&now>=e.windup){
    e.windup=0;e.nextSwing=now+(e.boss?1200:950);
    if(now>=s.invulnUntil){
     hurtPlayer(s,e.boss?3:s.kind==='challenge'?2:1,now);
    }
   }else if(!e.windup&&now>=e.nextSwing){
    e.windup=now+(e.boss?530:e.kind==='bat'?280:420);
   }
  }else{
   if(e.windup)e.windup=0;
   const pace=e.kind==='bat'?330:e.kind==='sentinel'?580:
    e.kind==='skeleton'?520:e.kind==='guardian'?560:
    e.kind==='specter'?790:e.kind==='thornbound'?680:
    e.kind==='mimic'?610:470;
   if(now-e.lastMove>pace*(s.kind==='challenge'?.88:1)){
    e.lastMove=now;
    // Ancient sentinels charge along a clear lane; specters slip through
    // walls only as a last resort. Everything respects chamber borders.
    if(e.kind==='sentinel'&&dist(e,s.player)>=3&&
       (e.x===s.player.x||e.y===s.player.y)){
      chase(e);chase(e);
    }else if(e.kind==='specter'&&dist(e,s.player)>=5){
      const dx=Math.sign(s.player.x-e.x),dy=Math.sign(s.player.y-e.y);
      const nx=e.x+dx,ny=e.y+dy;
      if(!blocked(nx,ny)&&!s.enemies.some(o=>o!==e&&o.x===nx&&o.y===ny)){
       e.x=nx;e.y=ny;
      }else chase(e);
    }else chase(e);
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
  '<button id="lwDAttack" aria-label="Attack" title="Attack"><span class="lwDAttackIcon" aria-hidden="true">⚔</span><span class="lwDAttackLabel">ATTACK</span></button></div>'+
  '<div id="lwDResult" hidden></div>'+
  '<footer><button id="lwDRetry">NEW LAYOUT</button><button id="lwDReturn">RETURN TO WORLD</button></footer>';
 const css=document.createElement('style');css.textContent=
 '#lwDungeonStage[hidden],#lwDResult[hidden]{display:none!important}'+
 '#lwDungeonStage{position:fixed;inset:0;z-index:1001;display:flex;flex-direction:column;'+
 'align-items:center;justify-content:flex-start;gap:6px;box-sizing:border-box;overflow:auto;'+
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
 '.lwDView{width:min(100%,700px);flex:none;min-height:0;display:flex;align-items:center;margin:5px 0}'+
 '#lwDCanvas{display:block;width:100%;max-height:52vh;aspect-ratio:17 / 13;object-fit:contain;'+
 'image-rendering:auto;border:3px solid #cfb680;background:#1c293a;border-radius:8px;'+
 'box-shadow:0 8px 22px #040c14ad,0 0 22px #9679ba44}'+
 '#lwDMessage{text-align:center;min-height:20px;margin:4px;font-size:11px;color:#e8d397}'+
 '.lwDControls{width:min(100%,530px);min-height:132px;display:flex;justify-content:space-around;align-items:center}'+
 '.lwDPad{display:grid;grid-template-columns:repeat(3,48px);grid-template-rows:repeat(3,42px)}'+
 '.lwDPad button{font-size:22px!important;padding:3px!important}'+
 '.lwDPad .up{grid-column:2;grid-row:1}.lwDPad .left{grid-column:1;grid-row:2}'+
 '.lwDPad .down{grid-column:2;grid-row:3}.lwDPad .right{grid-column:3;grid-row:2}'+
 '#lwDAttack{width:88px;height:88px;border-radius:50%!important;background:#79536b!important;'+
 'display:flex;flex-direction:column;justify-content:center;align-items:center;gap:2px;'+
 'padding:5px!important;line-height:1!important;letter-spacing:0;text-shadow:none!important;white-space:nowrap}'+
 '#lwDAttack .lwDAttackIcon{display:block;font:normal 30px/1 sans-serif;text-shadow:none!important}'+
 '#lwDAttack .lwDAttackLabel{display:block;font:700 11px/1.1 monospace;text-shadow:none!important}'+
 '#lwDungeonStage footer{margin-top:auto}#lwDungeonStage footer button{flex:1;min-height:42px;'+
 'font-size:11px!important;line-height:1.2;letter-spacing:0;text-shadow:none!important}'+
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
  warrior:identity(warrior),kind,rooms,plan:generateLayout(runSeed,rooms),
  nodeIndex:0,visited:new Set(),hp:kind==='challenge'?14:18,
  maxHP:kind==='challenge'?14:18,player:loc(2,6),walls:new Set(),props:[],
  enemies:[],projectiles:[],warnings:[],face:'right',gold:0,kills:0,nextAttack:0,
  attackUntil:0,invulnUntil:0,hurtUntil:0,lastStep:0,walkUntil:0,walkFrame:0,sparks:[],
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
  player:{...s.player},face:s.face,warrior:{...s.warrior},animation:heroAnimation(performance.now()),gold:s.gold,kills:s.kills,
  bossHP:s.enemies.find(e=>e.boss)?.hp??null,
  node:s.nodeIndex,roomType:s.current.type,template:s.current.template,
  enemyTypes:s.enemies.map(e=>e.kind),projectiles:s.projectiles.length,
  warnings:s.warnings.length,bossPhase:s.enemies.find(e=>e.boss)?.phase??null,
  artStyle:window.LibationDungeonArt?'painted-2.5d':'legacy-pixel',
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
function debugEnemyEncounter(kind){
 if(!state||!devAllowed())return false;
 const allowed=window.LibationDungeonArt?.enemyTypes||['slime','skeleton','bat','sentinel'];
 if(!allowed.includes(kind))return false;
 const s=state,[dx,dy]=DIR[s.face],x=s.player.x+dx,y=s.player.y+dy,now=performance.now();
 s.enemies=[{x,y,hp:kind==='sentinel'?7:5,maxHP:kind==='sentinel'?7:5,
  kind,boss:false,lastMove:now,nextSwing:now+850,
  windup:0,hitUntil:0,stunnedUntil:0,awake:kind!=='mimic',blocking:false,phase:1}];
 s.projectiles=[];s.warnings=[];s.roomClear=false;s.current.cleared=false;
 s.nextAttack=0;announce('DEV ENEMY CHECK: '+kind.toUpperCase());
 return true;
}
function debugBossEncounter(){
 if(!state||!devAllowed())return false;
 const s=state;s.nodeIndex=s.plan.boss;makeRoom();
 s.player=loc(2,6);s.face='right';
 s.enemies=[{x:3,y:6,hp:s.kind==='challenge'?17:12,
  maxHP:s.kind==='challenge'?17:12,kind:'guardian',boss:true,
  lastMove:performance.now(),nextSwing:performance.now()+850,
  windup:0,hitUntil:0,stunnedUntil:0,phase:1,awake:true}];
 s.projectiles=[];s.warnings=[];
 s.roomClear=false;s.current.cleared=false;
 s.hp=s.maxHP;s.hurtUntil=0;s.nextAttack=0;s.invulnUntil=performance.now()+700;
 announce('DEV BOSS CHECK: fight a full-health guardian');
 return true;
}
window.LibationDungeon=Object.freeze({start,stop,snapshot,move:step,attack,
 previewWarrior,inspectLayout,debugClearRoom,debugCombatEncounter,
 debugEnemyEncounter,debugBossEncounter});
})();