/* Libation Warriors: original hand-drawn 2.5D fantasy dungeon.
   Fictional spaces only: this artwork never represents a mapped venue interior.
   Canvas gradients, shapes, lighting and ambient effects; no external image deps. */
(()=>{
'use strict';
const W=544,H=416,S=32,TAU=Math.PI*2;
const palettes={
 rupture:{base:'#403e39',stone:'#807a65',light:'#ebcb92',dark:'#19272f',
  grout:'#42483e',moss:'#62795a',glow:'#ffb86b',accent:'#74b3a3',trim:'#ae885a'},
 challenge:{base:'#292d40',stone:'#65617b',light:'#c7bde0',dark:'#111827',
  grout:'#302d47',moss:'#594e83',glow:'#a894ff',accent:'#86dcdd',trim:'#9986bb'}
};
function rand(n){n=Math.imul((n>>>0)^0x9e3779b9,1597334677);return ((n^(n>>>12))>>>0)/4294967296}
function grad(c,x,y,w,h,a,b){const q=c.createLinearGradient(x,y,x+w*.12,y+h);q.addColorStop(0,a);q.addColorStop(1,b);return q}
function poly(c,points,fill,stroke='#00000000',line=1){
 c.beginPath();points.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.closePath();
 c.fillStyle=fill;c.fill();if(stroke!=='#00000000'){c.lineWidth=line;c.strokeStyle=stroke;c.stroke()}
}
function ellipse(c,x,y,rx,ry,color){c.fillStyle=color;c.beginPath();c.ellipse(x,y,rx,ry,0,0,TAU);c.fill()}
function rounded(c,x,y,w,h,r,fill,outline){
 c.beginPath();c.roundRect(x,y,w,h,r);c.fillStyle=fill;c.fill();
 if(outline){c.lineWidth=2;c.strokeStyle=outline;c.stroke()}
}
function halo(c,x,y,r,color,opacity=.33){
 const g=c.createRadialGradient(x,y,1,x,y,r);
 g.addColorStop(0,color);g.addColorStop(1,'transparent');
 c.save();c.globalAlpha=opacity;c.fillStyle=g;c.fillRect(x-r,y-r,2*r,2*r);c.restore();
}
function torch(c,x,y,time,p,isChallenge){
 const flick=Math.sin(time/177+x*.5)*3;
 c.save();
 halo(c,x,y,49,isChallenge?'#a78eff':'#ffb86b',.24);
 rounded(c,x-7,y+2,14,14,2,'#253341','#a6a99f');
 poly(c,[[x-6,y+5],[x-4,y-3],[x+1,y-13-flick],[x+3,y-6],[x+9,y+4]],
  isChallenge?'#9a72e7':'#e58039');
 ellipse(c,x,y-1,4,10,isChallenge?'#d0c6ff':'#ffe5a1');
 ellipse(c,x,y+4,3,5,'#fff4d2');
 c.restore();
}
function stone(c,x,y,kind,salt,p){
 const flag=rand(salt);
 const a=flag>.55?p.stone:p.base;
 rounded(c,x+1,y+1,30,30,3,grad(c,x,y,30,30,a,p.dark),p.grout);
 c.globalAlpha=.13;
 c.strokeStyle=p.light;c.lineWidth=1.2;
 if(flag>.42){
  c.beginPath();c.moveTo(x+3,y+5);c.lineTo(x+17,y+6);
  c.moveTo(x+8,y+28);c.lineTo(x+28,y+27);c.stroke();
 }
 if(flag>.80){poly(c,[[x+7,y+14],[x+15,y+10],[x+19,y+17],[x+24,y+18]],'#00000000',p.light,1)}
 c.globalAlpha=1;
}
function pillar(c,x,y,p){
 ellipse(c,x+16,y+32,25,9,'#080d19a0');
 rounded(c,x+1,y+2,30,33,4,grad(c,x,y,30,30,p.stone,p.dark),'#151f2d');
 rounded(c,x+5,y-15,22,32,5,grad(c,x-2,y-17,30,35,p.light,p.base),p.trim);
 rounded(c,x-2,y-17,36,10,2,grad(c,x,y-17,36,10,p.light,p.stone),p.dark);
 c.strokeStyle=p.light;c.lineWidth=1.5;c.strokeRect(x+9,y-5,13,19);
}
function door(c,d,open,time,p){
 const x=d.x*S,y=d.y*S;
 ellipse(c,x+16,y+31,21,9,'#0b132acc');
 const portal=grad(c,x,y,32,35,p.stone,p.dark);
 rounded(c,x-5,y-8,42,49,8,portal,'#142432');
 rounded(c,x-1,y-4,34,43,7,p.dark,p.trim);
 rounded(c,x+5,y+2,22,35,4,open?'#356c68':'#3e364b');
 if(open){
  halo(c,x+16,y+17,34,p.accent,.22);
  rounded(c,x+12,y+3,9,25,5,p.accent);
  ellipse(c,x+17,y+6+Math.sin(time/260)*3,4,5,p.light);
 }else{
  c.strokeStyle='#d89a79';c.lineWidth=4;
  c.beginPath();c.moveTo(x+7,y+13);c.lineTo(x+26,y+26);c.moveTo(x+26,y+13);c.lineTo(x+7,y+26);c.stroke();
 }
}
function decor(c,kind,x,y,time,p){
 if(kind==='coffin'){
  ellipse(c,x+28,y+26,39,14,'#101725aa');
  rounded(c,x-6,y-3,71,28,8,grad(c,x,y,65,28,p.stone,p.dark),p.trim);
  rounded(c,x+4,y,50,18,3,p.base,p.light);
  c.strokeStyle=p.trim;c.lineWidth=3;c.beginPath();c.moveTo(x+24,y+7);c.lineTo(x+36,y+7);
  c.moveTo(x+30,y+2);c.lineTo(x+30,y+15);c.stroke();
 }else if(kind==='pillar')pillar(c,x,y,p);
}
function bossSeal(c,theme,time,cleared,p){
 const x=272,y=208;halo(c,x,y,103,theme==='challenge'?'#a47afa':'#f5af70',.23);
 ellipse(c,x,y+9,75,45,'#15182788');
 ellipse(c,x,y,63,39,grad(c,x-50,y-20,100,40,p.stone,p.dark));
 c.strokeStyle=p.trim;c.lineWidth=5;c.beginPath();c.ellipse(x,y,58,32,0,0,TAU);c.stroke();
 c.strokeStyle=p.light;c.lineWidth=3;
 for(let a=0;a<8;a++){
  const q=a*TAU/8+time/11000;
  c.beginPath();c.moveTo(x+Math.cos(q)*38,y+Math.sin(q)*20);
  c.lineTo(x+Math.cos(q+.29)*48,y+Math.sin(q+.29)*26);c.stroke();
 }
 ellipse(c,x,y,15,10,cleared?p.accent:'#a34e73');
 ellipse(c,x,y,8,5,p.light);
}
function drawRoom(c,s,time){
 const theme=s.kind, p=palettes[theme]||palettes.rupture,n=s.current;
 c.save();c.clearRect(0,0,W,H);c.fillStyle=p.dark;c.fillRect(0,0,W,H);
 // Raised masonry rims, accurate perspective-ish depth and soft center lighting.
 c.fillStyle=grad(c,0,0,W,H,p.base,p.dark);c.fillRect(24,19,W-48,H-45);
 rounded(c,12,8,W-24,H-16,17,p.dark,p.trim);
 rounded(c,25,20,W-50,H-44,12,grad(c,28,25,W-50,H-44,p.base,p.dark),p.stone);
 // The wide beveled northern masonry wall gives each room height rather than
 // a flat top-down row. Door tiles remain unobstructed below the facade.
 rounded(c,23,9,W-46,58,8,grad(c,23,9,W-46,58,p.stone,p.dark),p.trim);
 for(let y=1;y<H-1;y++)for(let x=1;x<16;x++){
  if(x===16||y===12)continue;
  const xx=x*S,yy=y*S,cell=x*91+y*53+n.id*239;
  if(y===1||y===11||x===1||x===15){
   if(rand(cell)>.55){
    c.strokeStyle=p.light;c.globalAlpha=.15;c.lineWidth=2;
    c.strokeRect(xx+2,yy+3,28,21);c.globalAlpha=1;
   }
   continue;
  }
  stone(c,xx,yy,n.template,cell,p);
 }
 // Lichen, damp staining, engraved slate and distinct surface materials.
 for(let a=0;a<42;a++){
  const salt=n.id*109+a*733,q=rand(salt);
  const x=57+rand(salt+3)*430,y=76+rand(salt+8)*272;
  if(q>.57){ellipse(c,x,y,5+q*13,1.7,p.moss);ellipse(c,x+4,y-2,2,1,p.light)}
 }
 if(n.template==='gallery'||n.template==='crypt'){
  const carpet=n.template==='crypt'?'#4c5268':'#685268';
  const runner=grad(c,190,72,160,290,carpet,p.dark);
  rounded(c,190,70,164,287,9,runner,p.trim);
  rounded(c,201,82,142,266,6,grad(c,201,82,142,266,carpet,p.base),p.light);
  for(let y=94;y<343;y+=24){
   c.strokeStyle=p.trim;c.globalAlpha=.32;c.lineWidth=2;
   c.beginPath();c.moveTo(216,y);c.lineTo(272,y+9);c.lineTo(328,y);c.stroke();
  }c.globalAlpha=1;
 }else if(n.template==='vault'||n.template==='sanctum'){
  rounded(c,160,111,223,218,16,grad(c,160,111,223,218,p.dark,p.stone),p.trim);
  for(let j=0;j<3;j++){
   c.strokeStyle=j===1?p.accent:p.trim;c.lineWidth=j===1?3:2;
   c.strokeRect(173+j*12,122+j*13,197-j*24,195-j*26);
  }
 }else if(n.template==='ruins'||n.template==='pillars'){
  for(let a=0;a<11;a++){
   const q=n.id*71+a*61;
   const x=75+rand(q)*385,y=94+rand(q+3)*215;
   if(rand(q+8)>.65){ellipse(c,x,y,20,8,'#111b2780');rounded(c,x-10,y-8,20,13,3,p.stone,p.trim)}
  }
 }else if(n.template==='arcade'){
  for(const y of [106,306])for(let x=107;x<478;x+=64){
   c.strokeStyle=p.trim;c.lineWidth=3;c.beginPath();c.arc(x,y,22,Math.PI,TAU);
   c.stroke();ellipse(c,x,y,4,4,p.light);
  }
 }
 // Wall occluders and columns are painted above the floor for raised depth.
 for(const pos of s.walls){
  const [gx,gy]=pos.split(',').map(Number),xx=gx*S,yy=gy*S;
  ellipse(c,xx+17,yy+27,21,9,'#101726a0');
  rounded(c,xx+2,yy-11,28,44,6,grad(c,xx,yy-11,28,44,p.light,p.dark),p.trim);
  rounded(c,xx+5,yy-13,22,11,3,p.light,p.stone);
 }
 for(const prop of s.props)decor(c,prop.kind,prop.x*S,prop.y*S,time,p);
 // Animated braziers and magical fixtures.
 for(const x of [87,455])torch(c,x,55,time,p,theme==='challenge');
 for(const dir of ['up','right','down','left']){
  if(n.edges[dir]!==undefined)door(c,({up:{x:8,y:1},right:{x:15,y:6},
   down:{x:8,y:11},left:{x:1,y:6}})[dir],s.roomClear,time,p);
 }
 if(n.type==='boss')bossSeal(c,theme,time,s.roomClear,p);
 if(n.type==='treasure'){
  halo(c,272,212,78,p.glow,.16);ellipse(c,277,235,32,9,'#1d2535b0');
  rounded(c,248,194,49,36,8,grad(c,248,194,49,36,p.trim,'#4c302a'),p.light);
  rounded(c,253,183,39,22,8,grad(c,253,183,39,22,'#e3b875','#63412f'),p.trim);
  rounded(c,267,207,13,11,2,p.light,p.trim);
 }else if(n.type==='shrine'){
  halo(c,272,209,83,p.accent,.20);
  rounded(c,243,208,58,24,7,grad(c,243,208,58,24,p.light,p.dark),p.trim);
  poly(c,[[273,166],[291,197],[273,218],[255,197]],grad(c,260,172,20,38,p.accent,p.light),p.light,2);
 }
 // Vignette is transparent around action and strengthens room depth.
 const edge=c.createRadialGradient(W/2,H/2,108,W/2,H/2,335);
 edge.addColorStop(0,'#00000000');edge.addColorStop(1,'#06101cc0');
 c.fillStyle=edge;c.fillRect(0,0,W,H);
 // Atmospheric dust motes move slowly enough to keep action legible.
 for(let i=0;i<18;i++){
  const q=n.id*613+i*109,x=36+rand(q)*470,y=58+((rand(q+7)*320+time*.008*(i%3+1))%325);
  ellipse(c,x,y,rand(q+8)*1.9+.3,rand(q+9)*1.4+.3,p.light);
 }
 c.restore();
}
function line(c,x1,y1,x2,y2,width,col){
 c.strokeStyle=col;c.lineWidth=width;c.lineCap='round';c.beginPath();c.moveTo(x1,y1);c.lineTo(x2,y2);c.stroke();
}
function drawEnemy(c,e,time,theme){
 const p=palettes[theme]||palettes.rupture,kind=e.kind;
 const cx=e.x*S+16,cy=e.y*S+16;
 const phase=Math.sin(time/230+e.x*3),hop=Math.abs(Math.sin(time/255+e.x))*3;
 const hurt=time<e.hitUntil,boss=!!e.boss;
 const glow=theme==='challenge'?'#bea0ff':'#fdc48c';
 c.save();
 ellipse(c,cx,cy+14,boss?27:17,boss?10:6,'#07121d9e');
 c.translate(cx,cy-(kind==='bat'||kind==='specter'?hop+6:hop));
 if(boss){
  const a=e.hp/e.maxHP,phase2=a<=.52,blue=theme==='challenge';
  halo(c,0,2,45,blue?'#9873e2':'#e9a85e',.30);
  poly(c,[[-23,-22],[-9,-31],[11,-31],[27,-21],[24,17],[-21,17]],
   grad(c,-18,-24,40,56,phase2?'#955178':blue?'#5a4f87':'#766353','#243046'),glow,2);
  rounded(c,-13,-20,27,21,8,grad(c,-14,-20,25,24,p.light,p.dark),p.trim);
  ellipse(c,-6,-10,3,3,'#fa926e');ellipse(c,6,-10,3,3,'#fa926e');
  poly(c,[[-21,-16],[-28,-28],[-15,-24]],p.trim,p.light,1);
  poly(c,[[21,-16],[28,-28],[15,-24]],p.trim,p.light,1);
  rounded(c,-19,1,37,25,8,grad(c,-18,2,36,26,p.stone,p.dark),p.trim);
  ellipse(c,0,10,8,10,phase2?'#e96ebd':blue?'#9ce0f0':'#f3bd75');
  line(c,19,2,30,-12,7,p.trim);ellipse(c,30,-13,6,6,p.accent);
  line(c,-11,21,-15,28,9,p.dark);line(c,11,21,15,28,9,p.dark);
  if(phase2)halo(c,0,10,23,'#f26cbd',.48);
 }else if(kind==='slime'){
  halo(c,0,5,27,'#81e6be',.16);
  const g=c.createRadialGradient(-5,-7,2,0,8,27);
  g.addColorStop(0,'#d5fff0');g.addColorStop(.5,'#6fc9a1');g.addColorStop(1,'#236a72');
  ellipse(c,0,4,17+phase,15-phase,g);
  ellipse(c,-6,0,4,3,'#efffff');ellipse(c,8,1,3,3,'#f0ffff');
  ellipse(c,-6,0,2,2,'#253a44');ellipse(c,8,1,2,2,'#253a44');
  ellipse(c,3,8,5,2,'#315d5d');
 }else if(kind==='skeleton'){
  poly(c,[[-12,-2],[0,-14],[15,-2],[12,21],[-12,21]],'#5e536a',p.trim,1.6);
  ellipse(c,0,-13,11,13,'#ded7bc');rounded(c,-10,-16,20,13,5,'#eee0c1');
  ellipse(c,-5,-12,3,4,'#734953');ellipse(c,5,-12,3,4,'#734953');
  line(c,-11,4,11,4,3,'#d9cba6');
  line(c,-8,11,8,11,2,'#d9cba6');
  line(c,17,-9,20,20,3,'#d0e0e5');line(c,14,10,25,10,3,p.trim);
  line(c,-7,20,-9,26,5,'#d4c9b0');line(c,8,20,11,26,5,'#d4c9b0');
 }else if(kind==='bat'){
  const wing=Math.sin(time/118+e.x)*10;
  poly(c,[[-5,-3],[-12,-17-wing],[-30,-9-wing],[-24,8],[-8,5]],'#7467a6',p.light,1.3);
  poly(c,[[5,-3],[12,-17-wing],[30,-9-wing],[24,8],[8,5]],'#7467a6',p.light,1.3);
  ellipse(c,0,1,11,14,'#3a355b');
  ellipse(c,-4,-3,2.5,3,'#ffceae');ellipse(c,4,-3,2.5,3,'#ffceae');
  poly(c,[[-6,-11],[-9,-20],[-2,-13]],'#3a355b');
  poly(c,[[6,-11],[9,-20],[2,-13]],'#3a355b');
 }else if(kind==='sentinel'){
  poly(c,[[-15,-18],[-3,-28],[16,-18],[19,17],[-16,17]],
   grad(c,-15,-21,32,41,'#b1b9b6','#476274'),p.trim,1.5);
  rounded(c,-11,-15,24,17,4,p.dark,'#a0b3bc');
  ellipse(c,-5,-8,3,3,'#a5f5eb');ellipse(c,7,-8,3,3,'#a5f5eb');
  rounded(c,-14,2,27,17,6,'#627888',p.trim);
  ellipse(c,0,9,6,8,'#68c9bc');halo(c,0,8,18,'#7eeaca',.3);
  line(c,-10,19,-10,28,8,'#3a465a');line(c,10,19,10,28,8,'#3a465a');
 }else if(kind==='specter'){
  halo(c,0,-1,30,'#a990ef',.39);
  poly(c,[[-12,-10],[-5,-24],[8,-24],[17,-8],[15,14],[4,7],[-3,21],[-14,12]],
   grad(c,-10,-22,18,43,'#d2baff','#65518d'),'#bfb3e1',1.5);
  ellipse(c,-5,-9,3,4,'#fff1bf');ellipse(c,6,-9,3,4,'#fff1bf');
  ellipse(c,0,2,8,4,'#453e75');
 }else if(kind==='thornbound'){
  poly(c,[[-16,20],[-13,-9],[-5,-20],[12,-18],[19,7],[11,20]],'#4d6744','#9fc08b',2);
  ellipse(c,-2,-8,14,13,'#66875a');
  poly(c,[[-6,-16],[-18,-25],[-10,-7]],'#87aa67');
  poly(c,[[6,-16],[19,-25],[10,-7]],'#87aa67');
  ellipse(c,-5,-8,3,3,'#f4d98d');ellipse(c,6,-8,3,3,'#f4d98d');
  line(c,-13,14,-21,25,6,'#654c38');line(c,11,12,21,25,5,'#654c38');
 }else if(kind==='mimic'){
  rounded(c,-19,-1,38,25,6,grad(c,-18,-1,36,26,'#b78b51','#543b32'),p.trim);
  rounded(c,-20,-16,40,18,6,'#744957','#d5ac70');
  if(e.awake){
   for(let j=-14;j<17;j+=7)poly(c,[[j,3],[j+4,12],[j+7,3]],'#f2e4ba');
   ellipse(c,-9,-10,4,4,'#ffd5a4');ellipse(c,10,-10,4,4,'#ffd5a4');
  }else rounded(c,-4,-10,8,16,3,'#f2d185');
 }else{
  ellipse(c,0,3,15,12,'#5cb4a2');ellipse(c,-6,-2,3,3,'white');ellipse(c,6,-2,3,3,'white');
 }
 if(hurt){c.globalAlpha=.53;ellipse(c,0,-1,boss?23:17,boss?28:19,'#fff9d8');c.globalAlpha=1}
 if(e.windup){
  c.strokeStyle=e.boss?'#ff7fb9':'#ffdca5';c.lineWidth=2.4;
  c.beginPath();c.arc(0,-1,boss?37:24,-Math.PI*.65,Math.PI*.65+time*.0007);c.stroke();
  ellipse(c,0,-32,3.5,3.5,'#fff3d0');
 }
 c.restore();
 // Grounded health bar, readable on dark and warm dungeons.
 rounded(c,cx-(boss?25:15),cy-(boss?42:31),boss?50:30,5,3,'#18242c');
 rounded(c,cx-(boss?23:13),cy-(boss?41:30),(boss?46:26)*Math.max(0,e.hp/e.maxHP),3,2,
  e.boss?'#ec8fb1':'#a7d6a2');
}
function drawEffects(c,s,time){
 c.save();
 for(const shot of s.projectiles||[]){
  const x=shot.x*S+16,y=shot.y*S+16;
  halo(c,x,y,24,shot.kind==='root'?'#83ba85':'#ab86eb',.24);
  ellipse(c,x,y,8,8,shot.kind==='root'?'#67b879':'#ae8bea');
  ellipse(c,x-3,y-3,3,3,'#fff4de');
 }
 for(const wave of s.warnings||[]){
  const x=wave.x*S+16,y=wave.y*S+16,progress=Math.min(1,(time-wave.started)/(wave.until-wave.started));
  c.strokeStyle=wave.kind==='root'?'#8ac985':'#ee9dbc';c.lineWidth=4;
  c.beginPath();c.ellipse(x,y,wave.radius*S,wave.radius*S*.55,0,0,TAU);c.stroke();
  halo(c,x,y,(wave.radius+.5)*S,wave.kind==='root'?'#9ecf8c':'#fd8cbb',.09+progress*.16);
 }
 c.restore();
}

// A unified illustrated hero: the staging preview and active player use the
// identical vector animation source. Faction and gender influence appearance,
// but never mutate the normalized UPC blueprint or a user's collection.
function hero(c,value,dir,action,frame,x,y){
 const who=value&&typeof value==='object'?value:{gender:'male',faction:'Pirate',name:'Warrior'};
 const woman=who.gender==='female',back=dir==='up',side=dir==='left'||dir==='right';
 const stride=action==='walk'?Math.sin(frame*Math.PI*.5)*5:0;
 const bounce=action==='walk'?Math.abs(Math.sin(frame*Math.PI*.5))*2:
  action==='idle'?frame%2:0;
 const attack=action==='attack',hurt=action==='hurt',defeat=action==='defeat';
 const primary=woman?'#376ca2':'#853e4b',secondary=woman?'#609ac2':'#b75e4f';
 const shirt=woman?'#c9d8c9':'#f0d7ad',skin=woman?'#e6ab83':'#d49c7a';
 const hair=woman?'#ddb66a':'#6a3a32',gold='#e2b579';
 c.save();c.translate(x,y);
 if(dir==='left'){c.scale(-1,1)}
 if(defeat){c.translate(-16,14);c.rotate(-1.13);c.translate(16,-14)}
 ellipse(c,0,21,19,5,'#13212b8f');
 c.translate(0,-bounce);
 // Boots articulate independently; upper body remains balanced over the feet.
 const boots=[[-10,-stride*.52],[9,stride*.52]];
 for(const [bx,delta] of boots){
  poly(c,[[bx-6,1+delta],[bx+5,1+delta],[bx+6,20+delta],
   [bx+10,23+delta],[bx-9,23+delta],[bx-9,19+delta]],
   grad(c,bx-6,0,11,24,'#b58b5d','#342d35'),'#352f35',1.8);
  line(c,bx-3,14+delta,bx+3,14+delta,2,gold);
 }
 // Animated fabric cape hangs behind the armor and sways while walking.
 const flow=action==='walk'?stride*.7:Math.sin(frame*.8)*1.2;
 poly(c,[[-17,-37],[12,-37],[19,-16],[23+flow,11],
  [5+flow,14],[-11+flow,9],[-20,-12]],
  grad(c,-17,-36,34,51,woman?'#1d416e':'#663342',woman?'#5174a3':'#be6a63'),
  '#222b3c',1.5);
 poly(c,[[7,-27],[19,-19],[23+flow,8],[9+flow,10]],
  '#e9d5af','#c8a87b',1.2);
 line(c,14,-17,19+flow,5,1.5,'#fff1cb');
 // Torso, sleeves and gloves.
 poly(c,[[-15,-35],[11,-36],[19,-26],[14,-1],[-13,0],[-18,-24]],
  grad(c,-15,-35,34,35,secondary,primary),'#333344',2);
 poly(c,[[-9,-34],[4,-36],[13,-17],[5,-6],[-8,-9]],
  grad(c,-9,-33,20,30,shirt,primary),gold,1);
 rounded(c,-12,-5,26,8,3,'#66433b',gold);
 rounded(c,-4,-6,10,10,3,gold,'#765334');
 ellipse(c,1,0,2,2,'#fff3cf');
 const armLift=attack?[0,11,23,8][frame]:0;
 poly(c,[[-17,-31],[-9,-26],[-15,-11],[-21,-11],[-23,-20]],
  secondary,'#343849',1.5);
 ellipse(c,-17,-11,5,6,skin);
 poly(c,[[12,-31],[20,-28],[24,-17-armLift],
  [18,-11-armLift],[10,-18]],primary,gold,1.3);
 ellipse(c,20,-12-armLift,5,6,skin);
 rounded(c,-19,-11,8,7,2,'#765340');
 rounded(c,17,-12-armLift,9,7,2,'#765340');
 // Neck, hair layers and face separated from shoulder silhouette.
 rounded(c,-5,-40,12,11,4,skin,'#855747');
 ellipse(c,0,-49,16,18,skin);
 if(back){
  ellipse(c,0,-55,17,17,grad(c,-18,-65,30,29,hair,'#392d36'));
  poly(c,[[-17,-57],[-16,-68],[-6,-65],[-1,-73],[7,-64],
   [15,-67],[19,-52],[11,-39],[-8,-39]],hair,'#442f32',1.5);
  poly(c,[[-10,-64],[-7,-71],[-2,-63],[5,-71],[8,-58]],
   woman?'#f1d48c':'#b2794f');
 }else{
  ellipse(c,-2,-57,18,16,grad(c,-12,-69,24,26,hair,'#46313a'));
  poly(c,[[-20,-60],[-17,-70],[-8,-67],[-3,-77],[5,-70],[13,-72],
   [17,-64],[16,-54],[-11,-49]],hair,'#51323a',1.4);
  if(side){
   ellipse(c,10,-49,2.3,3,'#263342');
   line(c,14,-45,17,-44,1.6,'#8f534a');
  }else{
   ellipse(c,-6,-49,2.2,3,'#28333c');
   ellipse(c,7,-49,2.2,3,'#28333c');
   line(c,-2,-41,4,-41,1.6,'#955c53');
  }
 }
 // Distinguishing faction accessories and readable weapon movement.
 if(woman){
  poly(c,[[-20,-65],[-14,-73],[7,-75],[19,-63],[18,-55],[-19,-55]],
   grad(c,-20,-74,36,20,'#3176aa','#18395e'),gold,1.8);
  ellipse(c,1,-65,4,5,'#c6eaff');
 }else{
  poly(c,[[-21,-67],[-13,-74],[17,-73],[24,-64],[10,-60],[-14,-61]],
   grad(c,-15,-76,34,18,'#414151','#1b2735'),gold,1.6);
  line(c,-13,-63,18,-63,2,gold);
 }
 if(attack){
  c.save();c.translate(22,-15-armLift);
  c.rotate([-.4,-1.35,-2.45,-.7][frame]);
  rounded(c,-2,-33,7,40,3,grad(c,-3,-32,8,40,'#fcffff','#7ba4bc'),'#d6ebf1');
  rounded(c,-9,6,22,5,2,gold);
  c.restore();
  if(frame===2){
   c.strokeStyle='#b7f3f6c0';c.lineWidth=4;c.beginPath();
   c.arc(0,-19,39,-2.1,.4);c.stroke();
  }
 }else if(woman){
  line(c,21,-13,24,-53,4,'#795237');
  ellipse(c,24,-54,7,7,grad(c,21,-59,8,14,'#f5fcff','#6cb7dc'));
 }else{
  line(c,22,-10,27,-37,3,'#d2e5e7');line(c,18,-14,28,-14,3,gold);
 }
 if(hurt){
  c.globalAlpha=.25;ellipse(c,0,-34,24,43,'#fff6db');c.globalAlpha=1;
 }
 c.restore();
}
function previewHero(value,dir='down',action='idle',frame=0){
 const el=document.createElement('canvas');el.width=96;el.height=112;
 const c=el.getContext('2d');c.imageSmoothingEnabled=true;
 c.save();c.translate(48,79);c.scale(1.03,1.03);
 hero(c,value,dir,action,frame,0,0);c.restore();
 return el.toDataURL('image/png');
}
function drawHero(c,value,dir,action,frame,x,y){
 c.save();c.translate(x,y);
 c.scale(.83,.83);hero(c,value,dir,action,frame,0,0);c.restore();
}
window.LibationDungeonArt=Object.freeze({drawRoom,drawEnemy,drawEffects,drawHero,previewHero,
 enemyTypes:['slime','skeleton','bat','sentinel','specter','thornbound','mimic'],
 palettes});
})();
