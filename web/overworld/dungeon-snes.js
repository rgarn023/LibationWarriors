/* Libation Warriors · original 16-bit SNES-inspired dungeon renderer.
 * Dynamic 25×19 tile arena, legible at 4-hero capacity. The illustrated
 * reference provided by the player guides palette, architecture and density;
 * no static screenshot is used as playable terrain or copied tiles.
 */
(()=>{
'use strict';
const TILE=32,GRID_W=25,GRID_H=19,W=GRID_W*TILE,H=GRID_H*TILE,TAU=Math.PI*2;
const THEMES={
rupture:{base:'#656170',joint:'#363545',hi:'#9a8a85',deep:'#202638',gold:'#ce995e',
 moss:'#527459',fire:'#ffb55c',carpet:'#784653',water:'#477c95'},
challenge:{base:'#56536b',joint:'#242b44',hi:'#88809c',deep:'#151c32',gold:'#b89273',
 moss:'#4d597f',fire:'#a78fff',carpet:'#5c416e',water:'#455ea4'}};
const HASH=n=>{n=Math.imul((n|0)^0x9e3779b9,1597334677);n^=n>>>16;n=Math.imul(n,2246822507);return ((n^(n>>>13))>>>0)/4294967296};
const color=(c,x,y,w,h,t)=>{c.fillStyle=t;c.fillRect(Math.round(x),Math.round(y),Math.ceil(w),Math.ceil(h))};
function tile(c,x,y,seed,p,kind){
 const salt=HASH(seed),sx=x*TILE,sy=y*TILE;
 color(c,sx,sy,32,32,p.joint);
 const col=salt>.7?p.hi:salt>.33?p.base:p.deep;
 color(c,sx+2,sy+2,28,27,col);color(c,sx+2,sy+2,27,2,'#d6b59c66');
 color(c,sx+29,sy+3,2,27,'#1c2335');color(c,sx+2,sy+29,29,2,'#262d42');
 if(salt>.24){
  color(c,sx+5,sy+8,3,2,p.hi);
  color(c,sx+8,sy+7,10,2,'#d2c0a35c');
  color(c,sx+7,sy+22,8,1,p.deep);
 }
 if(salt>.55){
  color(c,sx+17,sy+15,2,7,p.joint);
  color(c,sx+13,sy+21,6,2,p.joint);
 }
 if(salt>.81){
  color(c,sx+5,sy+25,4,2,p.moss);
  color(c,sx+9,sy+24,5,3,p.moss);
  color(c,sx+7,sy+23,2,2,'#9cae72');
 }
 if(kind==='flooded'&&salt>.45){
  color(c,sx+4,sy+12,24,13,p.water);
  color(c,sx+5,sy+12,20,2,'#a5c9d1');
  color(c,sx+17,sy+24,8,2,'#7ba2c3');
 }
 if(kind==='fracture'&&salt>.78){
  color(c,sx+11,sy+13,3,5,'#b6a3ec');
  color(c,sx+14,sy+18,2,9,'#634e99');
  color(c,sx+16,sy+26,5,2,'#9983d2');
 }
 if(kind==='cellar'&&salt>.8){
  color(c,sx+7,sy+24,13,3,'#76523a');
  color(c,sx+9,sy+22,5,2,'#bf9467');
 }
}
function column(c,x,y,p){
 const sx=x*TILE,sy=y*TILE;
 color(c,sx-6,sy+17,43,14,'#0f1b2ca8');
 color(c,sx+5,sy-16,23,43,p.deep);
 color(c,sx+7,sy-15,19,40,p.base);
 color(c,sx+9,sy-15,5,39,p.hi);
 for(const yy of [-14,5,20]){
  color(c,sx+2,sy+yy,31,6,p.deep);
  color(c,sx+4,sy+yy,27,3,p.hi);
  color(c,sx+4,sy+yy+4,29,2,p.gold);
 }
 color(c,sx+14,sy-11,2,21,'#e0c4a0a0');
}
function barrel(c,x,y,p){
 const sx=x*TILE,sy=y*TILE;
 color(c,sx-1,sy+10,36,18,'#141c2ab9');
 color(c,sx+4,sy+3,27,27,'#352b30');
 color(c,sx+6,sy+5,23,24,'#80553c');
 color(c,sx+10,sy+6,4,22,'#ac8153');
 color(c,sx+23,sy+6,2,22,'#493a33');
 for(const yy of [7,22]){
  color(c,sx+5,sy+yy,25,5,'#525866');
  color(c,sx+6,sy+yy,24,2,'#ad9c86');
 }
 color(c,sx+13,sy+13,6,7,p.gold);
}
function rubble(c,x,y,p,s){
 const px=x*TILE,py=y*TILE;
 color(c,px+6,py+20,22,7,'#15202d96');
 const q=HASH(s);
 color(c,px+7,py+15,12,10,p.deep);
 color(c,px+8,py+13,11,5,q>.5?p.hi:p.base);
 color(c,px+18,py+18,11,7,p.base);
 color(c,px+21,py+17,6,2,p.hi);
}
function banner(c,x,y,p){
 const px=x*TILE,py=y*TILE;
 color(c,px+7,py-12,19,48,'#352a3e');
 color(c,px+9,py-8,15,38,p.carpet);
 color(c,px+15,py,3,19,p.gold);
 color(c,px+11,py+8,11,3,p.gold);
 color(c,px+9,py+31,5,8,p.carpet);
 color(c,px+20,py+31,4,8,p.carpet);
 color(c,px+6,py-13,23,4,p.gold);
}
function flame(c,x,y,p,now){
 const px=x*TILE,py=y*TILE,j=Math.round(Math.sin(now/95+x*5)*2);
 color(c,px-11,py-10,23,17,'#000d1980');
 color(c,px-7,py-7,15,18,'#57443b');
 color(c,px-9,py+5,19,5,p.gold);
 color(c,px-4,py-17+j,9,18,p.fire);
 color(c,px-2,py-13+j,5,12,'#fff2bb');
 color(c,px+6,py+10,4,8,'#2d333c');
}
const DOORS={up:[12,1],right:[23,9],down:[12,17],left:[1,9]};
function door(c,d,open,p,now){
 const x=d[0]*TILE,y=d[1]*TILE;
 color(c,x-6,y-10,45,51,'#192435');
 color(c,x-2,y-8,37,47,p.hi);
 color(c,x+2,y-2,29,40,p.deep);
 color(c,x+6,y+2,21,34,open?'#244f61':'#483445');
 color(c,x+10,y+4,5,25,open?'#63c5be':'#ab776d');
 if(open)color(c,x+16,y+12+Math.round(Math.sin(now/200)*2),4,10,'#d5fae3');
 else{
  color(c,x+5,y+9,25,4,'#b98370');
  color(c,x+5,y+20,25,4,'#b98370');
 }
}
function bossMark(c,p,cleared){
 const cx=12*TILE+16,cy=9*TILE+16;
 color(c,cx-52,cy-44,104,88,p.deep);
 for(let i=0;i<3;i++){
  c.strokeStyle=i===1?p.gold:p.hi;c.lineWidth=3;
  c.strokeRect(cx-44+i*8,cy-36+i*7,88-i*16,72-i*14);
 }
 color(c,cx-12,cy-9,25,18,cleared?'#5baaab':'#8f4f7a');
 color(c,cx-5,cy-4,10,8,p.gold);
}
// Art-directed SNES chamber, with broad masonry courses rather than a
// checkerboard of identical outlines. All decor uses local fictional geometry.
const styles={
 cellar:{stone:'#7a6c5d',mid:'#514a48',dark:'#2a303d',rim:'#d0a16d',rug:'#7e4348',accent:'#e1bd7b'},
 flooded:{stone:'#717b79',mid:'#445e67',dark:'#1b3544',rim:'#a6c5b6',rug:'#486f78',accent:'#8bd5d7'},
 fracture:{stone:'#73709a',mid:'#4d456f',dark:'#262641',rim:'#ceb7f2',rug:'#574882',accent:'#ae9ff5'},
 crypt:{stone:'#787583',mid:'#514d60',dark:'#2f293b',rim:'#c0ac91',rug:'#5a3f57',accent:'#d4c38d'},
 ruins:{stone:'#8a7e72',mid:'#575b53',dark:'#2b3640',rim:'#b2b88e',rug:'#656b55',accent:'#d4be85'}
};
function palette(s){
 const p=THEMES[s.kind]||THEMES.rupture,theme=styles[s.current.template];
 return theme?{...p,...theme}: {...p,stone:p.base,mid:p.joint,dark:p.deep,
  rim:p.gold,rug:p.carpet,accent:p.fire};
}
function pixelLine(c,x,y,dx,dy,stroke,width=2){
 c.save();c.strokeStyle=stroke;c.lineWidth=width;c.lineCap='square';
 c.beginPath();c.moveTo(Math.round(x),Math.round(y));
 c.lineTo(Math.round(x+dx),Math.round(y+dy));c.stroke();c.restore();
}
function isSafeFloor(s,x,y){
 return x>=2&&x<=22&&y>=2&&y<=16&&!s.walls.has(x+','+y)&&
  !(x>=9&&x<=15&&y>=6&&y<=12)&&
  !s.partySpawnSlots.some(a=>Math.abs(a.x-x)<=1&&Math.abs(a.y-y)<=1);
}
function drawMasonry(c,s,p){
 const id=s.current.id,template=s.current.template;
 color(c,0,0,W,H,'#0d1522');
 // Three courses of uneven large flagstones, with running (offset) bonds.
 // Individual stones have multiple shades, chips and local imperfections.
 for(let gy=0;gy<H;gy+=48){
  const row=gy/48,shift=(row%2)*35;
  for(let gx=-70+shift;gx<W+70;gx+=70){
   const v=HASH(id*877+row*991+gx*11),
    x=Math.round(gx),y=gy;
   const upper=v>.64?p.stone:v>.28?p.mid:p.base;
   color(c,x,y,69,47,p.dark);
   color(c,x+3,y+3,64,40,upper);
   color(c,x+4,y+3,59,3,'#e1cba039');
   color(c,x+4,y+39,63,3,'#101b2c77');
   color(c,x+63,y+6,3,35,'#1a243c66');
   if(v>.21){
    const x1=x+13+Math.round(HASH(gx+id)*25),y1=y+11+Math.round(v*11);
    pixelLine(c,x1,y1,10,1,'#111f30ad',2);
    pixelLine(c,x1+8,y1+1,5,9,p.dark,2);
    color(c,x+34,y+6,3,2,p.rim);
   }
   if(v>.72){
    color(c,x+20,y+33,15,4,p.moss);
    color(c,x+27,y+30,3,9,'#789978');
   }
  }
 }
 // Subtle damp floor patches, following broad contours, not tile cells.
 for(let j=0;j<13;j++){
  const rand=HASH(id*59+j*111),x=72+HASH(id*17+j*557)*650,
   y=97+HASH(j*103+id*31)*425;
  if(x>295&&x<505&&y>205&&y<420)continue;
  c.fillStyle=template==='flooded'?'#4a8c9d80':'#1e304042';
  c.beginPath();c.ellipse(x,y,18+rand*34,5+rand*13,0,0,TAU);c.fill();
 }
 // Raised rear masonry wall, niche shadows, column capitals and battlements.
 color(c,0,0,W,73,'#131d2d');
 color(c,30,13,W-60,62,p.mid);
 color(c,32,14,W-64,6,p.rim);
 color(c,32,24,W-64,42,p.dark);
 for(let x=42;x<W-36;x+=83){
  color(c,x,18,73,11,p.stone);
  color(c,x+3,21,66,4,'#dbc6a250');
  color(c,x+7,38,60,23,'#182238');
  color(c,x+12,41,51,17,p.mid);
  color(c,x+25,44,24,11,p.dark);
 }
 color(c,0,67,W,7,'#1a2233');
 color(c,2,71,W-4,5,p.rim);
 // Thick side-wall silhouette with projecting buttresses.
 for(const right of [false,true]){
  const x=right?744:0;
  color(c,x,40,56,H-74,p.dark);
  color(c,x+(right?0:45),42,11,H-83,p.stone);
  color(c,x+(right?0:50),40,5,H-88,p.rim);
  for(let y=90;y<H-34;y+=96){
   const px=right?744:18;
   color(c,px,y,39,16,p.stone);
   color(c,px+4,y+2,30,5,p.rim);
   color(c,px+9,y+16,23,49,p.mid);
   color(c,px+13,y+19,7,39,'#bea58a62');
  }
 }
 // South parapet; open-center movement is never occluded by collision art.
 color(c,0,H-31,W,31,p.deep);
 color(c,0,H-34,W,7,p.stone);
 color(c,0,H-36,W,4,p.rim);
 for(let x=44;x<W-36;x+=67){
  color(c,x,H-24,58,5,p.mid);
  color(c,x+3,H-20,53,8,p.stone);
 }
}
function drawRug(c,s,p){
 const type=s.current.template;
 if(!['cellar','crypt','gallery','sanctum','vault'].includes(type))return;
 // Worn ceremonial carpet is one uninterrupted area with fringe and trim.
 color(c,314,121,172,365,'#1a25347d');
 color(c,318,119,164,363,p.rug);
 color(c,322,124,156,354,'#674453');
 for(const x of [322,329,470,477]){
  color(c,x,131,3,335,p.rim);
 }
 for(let y=142;y<463;y+=39){
  color(c,340,y,121,2,'#cfa47766');
  for(const x of [340,456]){
   color(c,x,y-6,14,5,p.rim);
   color(c,x+5,y-11,4,17,p.mid);
  }
 }
 for(const x of [328,351,374,397,420,443,466]){
  color(c,x,477,3,10,p.rim);
 }
}
function drawRoomThemes(c,s,p,now){
 const type=s.current.template,id=s.current.id;
 if(type==='cellar'){
  // Copper pipes, stacked casks, wall racks and suspended chain.
  for(const x of [80,690]){
   for(let y=122;y<466;y+=114){
    color(c,x-20,y-10,72,64,'#1c2432a5');
    barrel(c,x,y,p);
    barrel(c,x+28,y-1,p);
    color(c,x-26,y+39,92,9,'#493b36');
    color(c,x-24,y+40,88,3,p.rim);
   }
  }
  for(let x=123;x<660;x+=132){
   color(c,x,74,5,80,'#735e50');
   color(c,x-6,147,17,9,p.rim);
   color(c,x+10,80,4,61,'#c6a778');
   for(let y=92;y<138;y+=15)color(c,x+4,y,9,3,'#dfa969');
  }
 }else if(type==='flooded'){
  // Jagged canal edges and animated reflection strips.
  for(const side of [0,1]){
   const x=side?623:104;
   for(let y=112;y<520;y+=80){
    color(c,x-11,y-8,95,57,p.dark);
    color(c,x-6,y-5,86,49,p.water);
    color(c,x-5,y-5,82,4,'#b2dee5');
    const ripple=(Math.floor(now/160)+y)%19;
    color(c,x+15+ripple,y+14,24,2,'#dbf6f3');
    color(c,x+9,y+29,40,2,'#7baec2');
   }
  }
  for(const pos of [[133,130],[641,457],[166,450]]){
   color(c,pos[0],pos[1],24,12,'#58785b');
   color(c,pos[0]+7,pos[1]-8,5,22,'#90b08b');
  }
 }else if(type==='fracture'){
  // Multi-faceted crystals and rift lines with colored illumination.
  for(const [x,y] of [[144,137],[664,135],[155,463],[645,446]]){
   const q=Math.sin(now/480+x)*4;
   c.fillStyle='#745db0';c.beginPath();
   c.moveTo(x-27,y+22);c.lineTo(x-16,y-24+q);c.lineTo(x+6,y-52+q);
   c.lineTo(x+27,y-16);c.lineTo(x+22,y+24);c.closePath();c.fill();
   pixelLine(c,x-15,y+5,20,-36,'#c5b8f2',4);
   pixelLine(c,x+8,y-32,7,44,'#8bd8e5',3);
   color(c,x-29,y+22,57,8,p.rim);
  }
  for(let j=0;j<15;j++){
   const x=105+HASH(j+id*21)*580,y=98+HASH(j*35+id)*410;
   pixelLine(c,x,y,14,-20,'#a48def',3);
   pixelLine(c,x+14,y-20,8,13,'#7fd0da',3);
  }
 }else{
  // Distinct crypt statues, ruined masonry and arches at room perimeter.
  for(const x of [112,653]){
   for(const y of [152,419]){
    color(c,x-19,y+25,69,16,'#131d2ba1');
    color(c,x-10,y-41,48,77,p.mid);
    color(c,x-5,y-42,40,11,p.rim);
    color(c,x+2,y-30,25,38,p.stone);
    color(c,x+8,y-23,11,14,p.deep);
    color(c,x-11,y+26,52,8,p.rim);
   }
  }
 }
}
function drawStructure(c,s,p){
 // Collision columns are taller than floor markers; fronts overlap floor edge.
 for(const pos of s.walls){
  const [x,y]=pos.split(',').map(Number);
  if(x<2||y<2||x>22||y>16)continue;
  column(c,x,y,p);
 }
 for(const prop of s.props)if(prop.kind==='coffin'){
  const x=prop.x*TILE,y=prop.y*TILE;
  color(c,x-6,y+20,72,15,'#101829af');
  color(c,x-10,y-8,75,35,p.mid);
  color(c,x-5,y-12,68,8,p.rim);
  color(c,x+2,y-4,57,18,p.dark);
  color(c,x+26,y+2,4,17,p.rim);
 }
}
function edgeDecor(c,s,p,now){
 const id=s.current.id,type=s.current.template;
 // Fixed architectural accents selected by theme and room ID, never obstacles.
 for(let j=0;j<12;j++){
  const x=j%2?3:21,y=3+Math.floor(j/2)*2;
  if(!isSafeFloor(s,x,y))continue;
  const seed=HASH(id*739+j*59);
  if(type==='cellar'){
   if(seed>.28)barrel(c,x,y,p);
  }else if(type==='fracture'){
   if(seed>.37){
    color(c,x*TILE+6,y*TILE-16,18,51,p.rim);
    color(c,x*TILE+12,y*TILE-33,7,48,'#918ad1');
    color(c,x*TILE+15,y*TILE-25,3,31,'#e4d5ff');
   }
  }else if(seed>.58){
   rubble(c,x,y,p,j+id);
  }else if(seed>.31){
   color(c,x*TILE+8,y*TILE+20,14,6,p.moss);
   color(c,x*TILE+10,y*TILE+15,4,9,'#98b67b');
  }
 }
 for(const x of [4,20])banner(c,x,1,p);
 for(const x of [2,22])for(const y of [3,15])flame(c,x,y,p,now);
}
function centralFocus(c,s,p,now){
 const n=s.current;
 if(n.type==='boss'){
  const x=400,y=305;
  c.strokeStyle=p.rim;c.lineWidth=5;
  c.beginPath();c.ellipse(x,y,95,72,0,0,TAU);c.stroke();
  for(let i=0;i<8;i++){
   const theta=i*Math.PI/4,x1=x+Math.cos(theta)*83,y1=y+Math.sin(theta)*62;
   color(c,x1-6,y1-4,12,8,p.rim);
  }
  color(c,x-24,y-19,47,39,n.cleared?'#65aea7':'#593e66');
  color(c,x-4,y-12,9,29,p.accent);
  color(c,x-14,y-3,29,9,p.accent);
 }else if(n.type==='treasure'){
  const x=386,y=284;
  color(c,x-20,y+37,94,13,'#1a2233b2');
  color(c,x-17,y-1,73,46,'#52372f');
  color(c,x-13,y-13,66,28,'#bb8756');
  color(c,x-7,y-12,53,5,p.rim);
  color(c,x+13,y+8,17,17,'#eac17b');
 }else if(n.type==='shrine'){
  const x=398,y=294;
  color(c,x-46,y+24,92,19,p.dark);
  color(c,x-29,y+18,59,11,p.rim);
  c.fillStyle='#7dd5cb';c.beginPath();
  c.moveTo(x,y-47);c.lineTo(x+19,y-12);
  c.lineTo(x,y+13);c.lineTo(x-18,y-12);c.closePath();c.fill();
  pixelLine(c,x-1,y-38,6,34,'#e0fff0',4);
 }
}
let tileCache=null,tileKey='',tileLast=0;
function drawRoom(c,s,now){
 const node=s.current,p=palette(s);
 const key=s.plan.seed+':'+s.nodeIndex+':'+node.template+':'+s.roomClear;
 if(tileCache&&tileKey===key&&now-tileLast<105){
  c.drawImage(tileCache,0,0);return;
 }
 c.save();c.imageSmoothingEnabled=false;
 drawMasonry(c,s,p);
 drawRug(c,s,p);
 drawRoomThemes(c,s,p,now);
 drawStructure(c,s,p);
 edgeDecor(c,s,p,now);
 centralFocus(c,s,p,now);
 for(const side of ['up','down','left','right'])if(node.edges[side]!==undefined)
  door(c,DOORS[side],s.roomClear,p,now);
 // Architectural shadows pull attention to the four-player combat space.
 const shadow=c.createRadialGradient(400,285,96,400,285,470);
 shadow.addColorStop(0,'#00000000');shadow.addColorStop(1,'#080e206d');
 c.fillStyle=shadow;c.fillRect(0,0,W,H);
 c.restore();
 if(!tileCache){tileCache=document.createElement('canvas');tileCache.width=W;tileCache.height=H}
 const cache=tileCache.getContext('2d');cache.clearRect(0,0,W,H);
 cache.drawImage(c.canvas,0,0);tileKey=key;tileLast=now;
}
function drawSprite(c,s,kind,now,player=false){
 const art=window.LibationDungeonArt;
 if(!art)return;
 // Source artists' multi-layer original character designs are sampled onto
 // 16-bit pixel-grid sprites; nearest neighbor upscale preserves sprite pixels.
 const frame=player?
  s.animation==='walk'?s.walkFrame%4:
  s.animation==='attack'?Math.max(0,Math.min(3,Math.floor((205-(s.attackUntil-now))/55))):
  s.animation==='hurt'?Math.floor(now/90)%4:
  s.animation==='defeat'?3:Math.floor(now/550)%2:
  Math.floor(now/170)%4;
 const key=player?
  ['hero',s.warrior?.id,s.warrior?.gender,s.face,s.animation,frame].join(':'):
  [kind,s.theme,s.variant??0,frame].join(':');
 let atlas=dynSprites.get(key);
 if(!atlas){
  const buffer=document.createElement('canvas');
  buffer.width=128;buffer.height=160;const q=buffer.getContext('2d');
  q.imageSmoothingEnabled=true;
  if(player){
   q.translate(64,126);
   q.scale(1.45,1.45);
   // Draw at the same position in its own source sprite frame.
   art.drawHero(q,s.warrior,s.face,s.animation,frame,0,0);
  }else{
   const scale=s.boss?1.17:1.34;
   q.translate(64-16*scale,110-16*scale);
   q.scale(scale,scale);
   // Enemies are located in arbitrary rooms; normalize world space to 0,0.
   art.drawEnemy(q,{...s,kind,x:0,y:0},now,s.theme);
  }
  const low=document.createElement('canvas');low.width=64;low.height=80;
  const lowc=low.getContext('2d');lowc.imageSmoothingEnabled=true;
  lowc.drawImage(buffer,0,0,128,160,0,0,64,80);
  dynSprites.set(key,low);
  if(dynSprites.size>180)dynSprites.delete(dynSprites.keys().next().value);
  atlas=low;
 }
 c.save();c.imageSmoothingEnabled=false;
 const x=(player?s.player.x:s.x)*TILE+16,y=(player?s.player.y:s.y)*TILE+16;
 // Feet anchored at tile center; character upper body projects into tile above.
 c.drawImage(atlas,Math.round(x-40),Math.round(y-77),80,100);
 c.restore();
}
const dynSprites=new Map();
function drawEnemy(c,e,now,theme){
 drawSprite(c,{...e,theme},e.kind,now,false);
}
function drawHero(c,s,now){
 drawSprite(c,{...s,animation:s.animation,walkFrame:s.walkFrame},'hero',now,true);
}
function drawEffects(c,s,now){
 const art=window.LibationDungeonArt;
 if(!art)return;
 c.save();c.imageSmoothingEnabled=false;
 art.drawEffects(c,s,now);c.restore();
}
window.LibationDungeonSNES=Object.freeze({
 width:GRID_W,height:GRID_H,tile:TILE,canvasWidth:W,canvasHeight:H,
 partyCapacity:4,drawRoom,drawEnemy,drawHero,drawEffects
});
})();