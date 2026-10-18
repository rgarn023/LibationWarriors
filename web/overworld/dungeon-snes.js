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
let tileCache=null,tileKey='',tileLast=0;
function drawRoom(c,s,now){
 const node=s.current,p=THEMES[s.kind]||THEMES.rupture;
 const key=s.plan.seed+':'+s.nodeIndex+':'+node.template+':'+s.roomClear;
 if(tileCache&&tileKey===key&&now-tileLast<150){
  c.drawImage(tileCache,0,0);return;
 }
 c.save();c.imageSmoothingEnabled=false;
 color(c,0,0,W,H,'#080f1c');
 for(let y=0;y<GRID_H;y++)for(let x=0;x<GRID_W;x++){
  const sx=x*TILE,sy=y*TILE;
  if(x===0||y===0||x===GRID_W-1||y===GRID_H-1){
   color(c,sx,sy,32,32,'#10182a');color(c,sx+2,sy+3,28,15,p.deep);
   color(c,sx+3,sy+3,27,3,p.hi);
   color(c,sx+1,sy+20,30,9,'#0d1424');continue;
  }
  tile(c,x,y,x*37+y*173+node.id*987,p,node.template);
 }
 // Additional relief on upper/lower walls, with stone arches and banners.
 for(let x=2;x<GRID_W-2;x+=3){
  const px=x*TILE;
  color(c,px,30,8,45,p.deep);
  color(c,px+2,33,5,34,p.hi);
  color(c,px-5,54,44,5,p.gold);
  color(c,px+10,H-41,31,5,p.deep);
 }
 // Distinct themed floor features, kept on nonblocking cells.
 const r=n=>HASH(n*97+node.id*199);
 if(['gallery','crypt','cellar'].includes(node.template)){
  for(let y=3;y<16;y++){
   for(let x=10;x<=14;x++){
    const xx=x*TILE,yy=y*TILE;
    color(c,xx+2,yy+2,29,28,(x+y)%2?'#654759':'#76505b');
    color(c,xx+4,yy+3,25,3,'#ab7d72');
   }
  }
 }else if(['flooded','ruins'].includes(node.template)){
  for(let i=0;i<24;i++){
   const x=2+Math.floor(r(i+19)*21),y=2+Math.floor(r(i+67)*15);
   if(s.walls.has(x+','+y))continue;
   color(c,x*TILE+3,y*TILE+15,25,12,p.water);
   color(c,x*TILE+6,y*TILE+17,15,2,'#a3c2cd');
  }
 }else if(['fracture','sanctum','vault'].includes(node.template)){
  bossMark(c,p,false);
  for(let j=0;j<20;j++){
   const x=70+r(j+50)*(W-140),y=72+r(j+155)*(H-140);
   color(c,x,y,3,19,j%2?'#aa90e4':'#7abdc4');
   color(c,x+4,y+13,3,5,'#f2e7ff');
  }
 }
 if(node.template==='cellar'){
  for(const x of [3,5,19,21])for(const y of [3,7,12,15])barrel(c,x,y,p);
 }
 for(const yy of [3,7,13,16])for(const xx of [3,21]){
  const q=r(xx+yy*25);
  if(node.template!=='cellar'&&q>.4)rubble(c,xx,yy,p,xx+yy);
 }
 // Props inherit the gameplay collision set.
 for(const pos of s.walls){
  const [x,y]=pos.split(',').map(Number);
  if(x<2||y<2||x>22||y>16)continue;
  column(c,x,y,p);
 }
 for(const prop of s.props){
  if(prop.kind==='pillar')column(c,prop.x,prop.y,p);
  if(prop.kind==='coffin'){
   const x=prop.x*TILE,y=prop.y*TILE;
   color(c,x-6,y-3,70,34,'#1b2432');
   color(c,x-3,y-10,66,32,p.hi);
   color(c,x+3,y-5,55,22,p.deep);
   color(c,x+29,y,4,14,p.gold);
  }
 }
 for(const xx of [4,20])banner(c,xx,1,p);
 for(const x of [2,22])for(const y of [3,15])flame(c,x,y,p,now);
 for(const side of ['up','down','left','right'])if(node.edges[side]!==undefined)
  door(c,DOORS[side],s.roomClear,p,now);
 if(node.type==='boss')bossMark(c,p,s.roomClear);
 if(node.type==='treasure'){
  const x=12*TILE,y=9*TILE;
  color(c,x-14,y-7,58,38,'#3c2834');color(c,x-9,y-12,48,31,'#a27543');
  color(c,x-6,y-12,42,5,'#e3b16b');color(c,x+13,y,8,12,p.gold);
 }else if(node.type==='shrine'){
  const x=12*TILE,y=9*TILE;
  color(c,x-18,y+5,67,28,p.deep);
  color(c,x-4,y-24,39,44,'#69b1bc');
  color(c,x+8,y-21,8,32,'#dbfaed');
 }
 // Sprites at entrances represent available *space*, not connected players.
 // No fake connected avatars or implied multiplayer session.
 c.restore();
 if(!tileCache){tileCache=document.createElement('canvas');tileCache.width=W;tileCache.height=H}
 const cache=tileCache.getContext('2d');
 cache.clearRect(0,0,W,H);cache.drawImage(c.canvas,0,0);
 tileKey=key;tileLast=now;
}
function drawSprite(c,s,kind,now,player=false){
 const art=window.LibationDungeonArt;
 if(!art)return;
 // Source artists' multi-layer original character designs are sampled onto
 // 16-bit pixel-grid sprites; nearest neighbor upscale preserves sprite pixels.
 const key=player?
  ['hero',s.warrior?.gender,s.face,s.animation,s.walkFrame].join(':'):
  [kind,s.kind,s.variant??0,Math.floor(now/180)%4].join(':');
 let atlas=dynSprites.get(key);
 if(!atlas){
  const buffer=document.createElement('canvas');
  buffer.width=112;buffer.height=118;const q=buffer.getContext('2d');
  q.imageSmoothingEnabled=true;
  if(player){
   q.translate(57,98);
   q.scale(1.0,1.0);
   // Draw at the same position in its own source sprite frame.
   art.drawHero(q,s.warrior,s.face,s.animation,s.walkFrame,0,0);
  }else{
   q.translate(49,65);
   // Enemies are located in arbitrary rooms; normalize world space to 0,0.
   art.drawEnemy(q,{...s,x:0,y:0},now,s.kind);
  }
  const low=document.createElement('canvas');low.width=56;low.height=59;
  const lowc=low.getContext('2d');lowc.imageSmoothingEnabled=true;
  lowc.drawImage(buffer,0,0,112,118,0,0,56,59);
  dynSprites.set(key,low);
  if(dynSprites.size>180)dynSprites.delete(dynSprites.keys().next().value);
  atlas=low;
 }
 c.save();c.imageSmoothingEnabled=false;
 const x=(player?s.player.x:s.x)*TILE+16,y=(player?s.player.y:s.y)*TILE+16;
 // Feet anchored at tile center; character upper body projects into tile above.
 c.drawImage(atlas,Math.round(x-28),Math.round(y-42),56,59);
 c.restore();
}
const dynSprites=new Map();
function drawEnemy(c,e,now,theme){
 drawSprite(c,{...e,kind:theme},e.kind,now,false);
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