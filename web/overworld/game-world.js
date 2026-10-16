/* Libation Warriors — geographic RPG canvas renderer, v13.
 * OpenStreetMap vector features remain the exclusive source of real terrain,
 * roads, shoreline and building geometry. This canvas is only their art layer.
 * No user GPS readings, accounts or venue positions are stored.
 */
(() => {
  'use strict';
  const $ = (s) => document.querySelector(s);
  const state = {map:null,canvas:null,ctx:null,features:[],decor:[],attached:false,
    dirty:false,lastDraw:0,lastCollect:0,pending:0,waiting:0,ratio:1,ready:false,
    lastGeoKey:'',stats:{polygons:0,lines:0,buildings:0}};
  const colors = {
    ground:'#94c989',groundAlt:'#a4d39a',earth:'#b5caa0',
    park:'#69b87b',parkLight:'#8ed694',forest:'#418b66',
    sand:'#eddaa2',town:'#b4d1ab',water:'#4bafd0',
    waterDark:'#268db4',waterLight:'#8cdaed',
    path:'#e8cb89',pathLight:'#f4e5ba',pathEdge:'#ad9564',
    major:'#ead4a3',stone:'#b5af92',building:'#cbb989',
    roof:'#aa785b',roofLight:'#d9a77c',roofDark:'#755848'
  };
  let textures={};
  function rand(n){n=(n|0)+0x6d2b79f5;n=Math.imul(n^(n>>>15),1|n);
    n^=n+Math.imul(n^(n>>>7),61|n);return ((n^(n>>>14))>>>0)/4294967295;}
  function makeTile(kind){
    const c=document.createElement('canvas');c.width=48;c.height=48;
    const g=c.getContext('2d');g.imageSmoothingEnabled=false;
    g.fillStyle=kind==='water'?colors.water:kind==='park'?colors.park:colors.ground;
    g.fillRect(0,0,48,48);
    for(let i=0;i<36;i++){
      const h=rand(i*733+(kind==='water'?127:kind==='park'?791:447));
      const x=Math.floor(rand(i*419+71)*48),y=Math.floor(rand(i*31+191)*48);
      if(kind==='water'){
        if(h>.42){
          g.fillStyle=h>.77?'#ace5e7':'#72cadd';
          g.fillRect(x,y,5+Math.floor(h*8),1);
        }
      }else{
        g.fillStyle=h>.79?'#c8e8a1':h>.38?'#5d9c6c':'#7cb77c';
        g.fillRect(x,y,1+Math.floor(h*2),2);
        if(h>.85){g.fillStyle='#e7e3ad';g.fillRect(x+1,y-1,2,1)}
      }
    }
    return c;
  }
  function ensure(){
    if(!state.map||state.canvas?.isConnected)return;
    const host=state.map.getCanvasContainer();
    if(!host)return;
    const c=document.createElement('canvas');c.id='gameOverworldArt';
    c.setAttribute('aria-hidden','true');
    c.style.cssText='position:absolute;inset:0;width:100%;height:100%;z-index:2;pointer-events:none;image-rendering:pixelated;display:none';
    host.appendChild(c);state.canvas=c;state.ctx=c.getContext('2d',{alpha:false});
    textures.ground=makeTile('ground');textures.park=makeTile('park');textures.water=makeTile('water');
    resize();
  }
  function resize(){
    if(!state.map||!state.canvas)return;
    const el=state.map.getCanvas();const w=el.clientWidth,h=el.clientHeight;
    if(!w||!h)return;
    // 1x rendering keeps clean 16-bit pixels without huge mobile WebGL costs.
    state.canvas.width=Math.round(w);state.canvas.height=Math.round(h);
    state.ratio=1;
    state.ctx.imageSmoothingEnabled=false;
    schedule();
  }
  function walkGeo(geometry,callback){
    if(!geometry||!Array.isArray(geometry.coordinates))return;
    const type=geometry.type,c=geometry.coordinates;
    if(type==='Polygon')for(const ring of c)callback(ring,false);
    if(type==='MultiPolygon')for(const poly of c)for(const ring of poly)callback(ring,false);
    if(type==='LineString')callback(c,true);
    if(type==='MultiLineString')for(const line of c)callback(line,true);
  }
  function geoKey(f){
    const p=f.properties||{},l=f.layer||{};
    const coords=f.geometry?.coordinates;
    const first=Array.isArray(coords)?JSON.stringify(coords).slice(0,92):'';
    return [l.id,f.id||p.osm_id||p.id||'',first].join(':');
  }
  function classify(f){
    const layer=f.layer||{}, id=String(layer.id||'').toLowerCase();
    if(id.startsWith('lw-'))return '';
    const p=f.properties||{};
    const cls=String(p.class||'').toLowerCase();
    const category=(id+' '+cls+' '+String(p.subclass||'')).toLowerCase();
    const geom=f.geometry?.type||'';
    const polygon=geom==='Polygon'||geom==='MultiPolygon';
    const line=geom==='LineString'||geom==='MultiLineString';
    if(polygon){
      if(/water|sea|ocean|lake|river|bay|reservoir/.test(category))return 'water';
      if(/forest|wood|tree/.test(category))return 'forest';
      if(/park|nature|garden|recreation|pitch|meadow|grass/.test(category))return 'park';
      if(/beach|sand|dune/.test(category))return 'sand';
      if(/build|house|structure/.test(category))return 'building';
      if(/residential|commercial|industrial|landuse|urban/.test(category))return 'town';
      return '';
    }
    if(line){
      if(/stream|river|canal|waterway/.test(category))return 'stream';
      if(/motorway|trunk|primary|secondary|tertiary|street|road|highway|residential|service|path|track|footway|pedestrian|cycle|living/.test(category)){
        return /path|track|footway|pedestrian|cycle/.test(category)?'trail':
          /motorway|trunk|primary/.test(category)?'major':'road';
      }
    }
    return '';
  }
  function snapshot(){
    if(!state.map||!state.map.isStyleLoaded())return;
    const w=state.canvas?.width||0,h=state.canvas?.height||0;
    if(w<5||h<5)return;
    let raw=[];
    try{raw=state.map.queryRenderedFeatures([[0,0],[w,h]])||[]}
    catch(e){console.warn('[Libation RPG] vector query failed',e);return}
    const found=[],seen=new Set();
    for(const feature of raw){
      const type=classify(feature);
      if(!type)continue;
      const id=geoKey(feature);
      if(seen.has(id))continue;seen.add(id);
      found.push({type,geometry:feature.geometry,seed:Math.floor(rand(feature.id||found.length)*100000)});
      if(found.length>=1050)break;
    }
    // Avoid temporarily blanking the canvas when tiles are still loading.
    if(found.length>0){
      const firstReady=!state.ready;
      state.features=found;state.ready=true;
      if(state.canvas)state.canvas.style.display='block';
      if(firstReady)window.dispatchEvent(new CustomEvent('libation-world-ready',
        {detail:{geographicFeatures:found.length}}));
    }else if(!state.ready&&state.canvas)state.canvas.style.display='none';
    makeDecoration();
    schedule();
  }
  function polygonPath(ctx,geo){
    ctx.beginPath();let count=0;
    walkGeo(geo,(points)=>{
      let first=true;
      for(const v of points){
        if(!Array.isArray(v)||v.length<2)continue;
        const pt=state.map.project(v);
        if(!Number.isFinite(pt.x)||!Number.isFinite(pt.y))continue;
        if(first){ctx.moveTo(pt.x,pt.y);first=false}else ctx.lineTo(pt.x,pt.y);
        count++;
      }
      if(!first)ctx.closePath();
    });
    return count>2;
  }
  function linePath(ctx,geo){
    ctx.beginPath();let count=0;
    walkGeo(geo,(points)=>{
      let first=true;
      for(const v of points){
        if(!Array.isArray(v)||v.length<2)continue;
        const pt=state.map.project(v);
        if(!Number.isFinite(pt.x)||!Number.isFinite(pt.y))continue;
        if(first){ctx.moveTo(pt.x,pt.y);first=false}else ctx.lineTo(pt.x,pt.y);
        count++;
      }
    });
    return count>1;
  }
  function pattern(ctx,key){
    if(!textures[key])return colors.ground;
    return ctx.createPattern(textures[key],'repeat');
  }
  function drawPolygon(ctx,item){
    if(!polygonPath(ctx,item.geometry))return;
    const t=item.type;
    if(t==='water'){
      ctx.fillStyle=pattern(ctx,'water');ctx.fill('evenodd');
      ctx.lineWidth=5;ctx.strokeStyle=colors.waterLight;ctx.stroke();
      ctx.lineWidth=2;ctx.strokeStyle=colors.waterDark;ctx.stroke();
    }else if(t==='forest'||t==='park'){
      ctx.fillStyle=pattern(ctx,'park');ctx.fill('evenodd');
      ctx.lineWidth=3;ctx.strokeStyle=t==='forest'?'#3d8a61':'#7faf83';ctx.stroke();
    }else if(t==='town'){
      ctx.fillStyle='#b5d3ac';ctx.fill('evenodd');
    }else if(t==='sand'){
      ctx.fillStyle=colors.sand;ctx.fill('evenodd');
      ctx.lineWidth=3;ctx.strokeStyle='#d1b87f';ctx.stroke();
    }else if(t==='building'){
      // Light is from upper-left; short sidewalls produce original RPG roof art.
      ctx.fillStyle='#7b8978';ctx.fill('evenodd');
      ctx.save();ctx.translate(-3,-8);
      if(polygonPath(ctx,item.geometry)){
        ctx.fillStyle=colors.roof;ctx.fill('evenodd');
        ctx.lineWidth=2.5;ctx.strokeStyle=colors.roofDark;ctx.stroke();
        ctx.lineWidth=1;ctx.strokeStyle=colors.roofLight;ctx.stroke();
      }
      ctx.restore();
    }
  }
  function drawLine(ctx,item){
    if(!linePath(ctx,item.geometry))return;
    const t=item.type;
    const major=t==='major',trail=t==='trail',stream=t==='stream';
    const thick=stream?9:major?14:trail?8:11;
    ctx.lineCap='round';ctx.lineJoin='round';
    ctx.strokeStyle=stream?'#368dac':colors.pathEdge;
    ctx.lineWidth=thick+5;ctx.stroke();
    ctx.strokeStyle=stream?colors.water:colors.path;
    ctx.lineWidth=thick;ctx.stroke();
    if(!stream){
      ctx.strokeStyle=trail?'#e8d9a6':colors.pathLight;
      ctx.lineWidth=trail?2:major?4:3;
      ctx.stroke();
    }
  }
  function makeDecoration(){
    if(!state.map)return;
    // Reproducible decoration grid in GPS degrees: clusters do not jump around
    // when camera moves. The map is still authoritative for paths and water.
    const b=state.map.getBounds(),sw=b.getSouthWest(),ne=b.getNorthEast();
    const mid=(sw.lat+ne.lat)/2;
    const stepLat=.00019,stepLon=stepLat/Math.max(.4,Math.cos(mid*Math.PI/180));
    const out=[];
    const y0=Math.floor(sw.lat/stepLat)-1,y1=Math.ceil(ne.lat/stepLat)+1;
    const x0=Math.floor(sw.lng/stepLon)-1,x1=Math.ceil(ne.lng/stepLon)+1;
    for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
      const r=rand(x*179+y*491);
      if(r<.47)continue;
      const lat=(y+.18+rand(x+y*9)*.64)*stepLat;
      const lon=(x+.18+rand(y+x*7)*.64)*stepLon;
      out.push({lon,lat,tree:r>.93,seed:x*19+y*177});
      if(out.length>=170)break;
    }
    state.decor=out;
  }
  function grass(ctx,x,y,seed){
    const r=rand(seed);ctx.fillStyle=r>.7?'#e6eeb9':'#62986f';
    ctx.fillRect(x,y,2,4);ctx.fillRect(x-3,y+2,2,2);
    ctx.fillStyle='#b9dba0';ctx.fillRect(x+2,y,2,2);
    if(r>.91){ctx.fillStyle='#f6d5b8';ctx.fillRect(x-2,y-2,3,3)}
  }
  function tree(ctx,x,y,seed){
    const r=rand(seed);
    const dark=r>.45?'#27644b':'#386f4d';
    const bright=r>.45?'#55a86b':'#61b679';
    // SNES-era layered tree canopy, trunk and grounding shadow.
    ctx.fillStyle='#36785b55';ctx.fillRect(x-14,y-5,29,6);
    ctx.fillStyle='#755f49';ctx.fillRect(x-3,y-13,6,15);
    ctx.fillStyle='#3d483c';ctx.fillRect(x-4,y-3,8,3);
    ctx.fillStyle=dark;
    ctx.fillRect(x-15,y-25,30,15);
    ctx.fillRect(x-11,y-31,23,15);
    ctx.fillStyle=bright;ctx.fillRect(x-12,y-29,24,13);
    ctx.fillRect(x-9,y-35,18,10);
    ctx.fillStyle='#7acc82';ctx.fillRect(x-6,y-34,9,5);
    ctx.fillStyle='#9ddd96';ctx.fillRect(x-4,y-32,4,3);
    ctx.fillStyle='#326e4d';ctx.fillRect(x+5,y-22,9,7);
    ctx.fillStyle='#428854';ctx.fillRect(x-13,y-17,6,6);
  }
  function drawDecoration(ctx){
    const w=state.canvas.width,h=state.canvas.height;
    // Pixel flora first on local lawn, not as floating screen stickers.
    for(const d of state.decor){
      const p=state.map.project([d.lon,d.lat]);
      if(p.x<0||p.y<0||p.x>w||p.y>h)continue;
      const xx=Math.round(p.x),yy=Math.round(p.y);
      // Querying source geometry at decoration points would be expensive at 60fps;
      // skip crowded areas with cached painted paths below via this buffer.
      if(d.tree)tree(ctx,xx,yy,d.seed);
      else grass(ctx,xx,yy,d.seed);
    }
  }
  function paint(now){
    state.dirty=false;
    if(!state.ready||!state.map||!state.canvas||!state.ctx)return;
    if(now-state.lastDraw<25){setTimeout(schedule,30);return}
    state.lastDraw=now;
    const ctx=state.ctx,w=state.canvas.width,h=state.canvas.height;
    if(!w||!h)return;
    ctx.imageSmoothingEnabled=false;
    ctx.fillStyle=pattern(ctx,'ground');ctx.fillRect(0,0,w,h);
    const groups={town:[],park:[],forest:[],sand:[],water:[],building:[],
      major:[],road:[],trail:[],stream:[]};
    for(const item of state.features)if(groups[item.type])groups[item.type].push(item);
    for(const kind of ['town','park','forest','sand','water']){
      for(const item of groups[kind])drawPolygon(ctx,item);
    }
    // Roads sit above water only when mapped bridges are present in actual data.
    // No fake roads or portals are generated by this graphic renderer.
    for(const kind of ['major','road','trail','stream']){
      for(const item of groups[kind])drawLine(ctx,item);
    }
    for(const item of groups.building)drawPolygon(ctx,item);
    // Decorations are deliberately sparse: preserves sight lines to real streets
    // and avoids the old full-screen animated clutter.
    // Keep vegetation sparse and behind actual water; not yet painted here.
    // drawDecoration(ctx) is reserved for geography-validated clusters.
  }
  function schedule(){
    if(state.dirty)return;
    state.dirty=true;requestAnimationFrame(paint);
  }
  function scheduleSnapshot(){
    if(state.pending)clearTimeout(state.pending);
    state.pending=setTimeout(()=>{state.pending=0;snapshot()},350);
  }
  const api={
    attach(map){
      if(!map||state.map===map&&state.attached)return;
      state.map=map;state.attached=true;ensure();
      map.on('move',schedule);
      map.on('idle',scheduleSnapshot);
      map.on('sourcedata',()=>{
        if(!state.ready) scheduleSnapshot();
      });
      map.on('resize',()=>{resize();scheduleSnapshot()});
      scheduleSnapshot();
    },
    refresh(){scheduleSnapshot()},
    destroy(){
      if(state.pending)clearTimeout(state.pending);
      if(state.canvas)state.canvas.remove();
      state.map=null;state.canvas=null;state.ctx=null;
      state.features=[];state.decor=[];state.ready=false;state.attached=false;
      state.dirty=false;state.lastDraw=0;
    },
    diagnostics(){return {features:state.features.length,ready:state.ready}}
  };
  window.LibationGameWorld=api;
})();
