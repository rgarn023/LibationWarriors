// Libation Warriors - authenticated, fail-closed verified acquisition service.
// Requires custom location, nonbusiness site, product and image anti-fraud providers.
// This is a backend integration foundation, NOT a guarantee of photo genuineness.
// No configured provider => no successful verification or warrior minting.
import { createClient } from "npm:@supabase/supabase-js@2.95.0";

const URL = Deno.env.get("SUPABASE_URL") ?? "";
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const deviceURL = Deno.env.get("DEVICE_LOCATION_VERIFY_URL") ?? "";
const siteURL = Deno.env.get("NONCOMMERCIAL_SITE_VERIFY_URL") ?? "";
const photoURL = Deno.env.get("BOTTLE_PROOF_VERIFY_URL") ?? "";
const verifierKey = Deno.env.get("LW_VERIFIER_API_KEY") ?? "";
const staff = createClient(URL, KEY, {auth: {autoRefreshToken:false,persistSession:false}});
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status, headers: {"content-type":"application/json","cache-control":"no-store"}
});
const fail = (message:string,status=400) => json({ok:false,message},status);
const safeBarcode = (raw:unknown) => {
  let c=String(raw??"").replace(/[ .-]/g,"");
  if(!/^\d{8}$|^\d{12}$|^\d{13}$/.test(c))return "";
  if(c.length===13&&c[0]==="0")c=c.slice(1);
  return c;
};
const sha = async (s:string) => {
  const digest=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));
  return [...new Uint8Array(digest)].map(x=>x.toString(16).padStart(2,"0")).join("");
};
const rnd = (n:number) => {
  const b=new Uint8Array(n);crypto.getRandomValues(b);
  return [...b].map(x=>x.toString(16).padStart(2,"0").toUpperCase()).join("");
};
const distance = (a:number,b:number,c:number,d:number) => {
  const rad=Math.PI/180;
  const x=(c-a)*rad, y=(d-b)*rad;
  const z=Math.sin(x/2)**2+Math.cos(a*rad)*Math.cos(c*rad)*Math.sin(y/2)**2;
  return 6371000*2*Math.atan2(Math.sqrt(z),Math.sqrt(1-z));
};
async function provider(url:string, payload:unknown) {
  if(!url||!verifierKey)throw Error("Required independent verifier is not configured");
  const controller = new AbortController();
  const timeout = setTimeout(()=>controller.abort(),10000);
  try {
    const res=await fetch(url,{method:"POST",headers:{"content-type":"application/json","authorization":"Bearer "+verifierKey},body:JSON.stringify(payload),signal:controller.signal});
    if(!res.ok)throw Error("Independent verifier failed");
    return await res.json();
  } finally {clearTimeout(timeout);}
}
async function verifyDevice(userId:string,lat:number,lon:number,token:unknown) {
  const result=await provider(deviceURL,{user_id:userId,latitude:lat,longitude:lon,integrity_token:token});
  if(result?.decision!=="approved"||result?.fresh!==true)throw Error("Location/device verification failed");
}
const CATEGORIES:[number,string,string[]][]=[
 [0,"pirate",["rum"]],[1,"militiaman",["bourbon"]],[2,"bandit",["tequila","mezcal"]],
 [3,"druid",["scotch"]],[4,"barbarian",["vodka"]],[5,"paladin",["brandy","cognac"]],
 [6,"alchemist",["gin"]],[7,"bard",["liqueur","cocktail"]],
 [8,"red_mage",["red wine"]],[9,"white_mage",["white wine"]],
 [10,"black_mage",["wine","champagne","prosecco"]],[11,"brawler",["beer","ale","lager","cider"]],
 [12,"samurai",["sake"]],[13,"viking",["mead"]],
 [14,"rogue",["whiskey","whisky","spirits"]]
];
async function classifyProduct(code:string) {
  const res=await fetch("https://world.openfoodfacts.org/api/v2/product/"+encodeURIComponent(code)+".json",{
    headers:{"user-agent":"LibationWarriors/0.2 (game product metadata verification)"}
  });
  if(!res.ok)throw Error("Unable to verify product from independent catalog");
  const data=await res.json();
  if(data?.status!==1||!data?.product)throw Error("Unknown product UPC");
  const p=data.product;
  const txt=[p.categories,p.generic_name,p.product_name,...(p.categories_tags??[])].join(" ").toLowerCase();
  if(/non[- ]?alcoholic|alcohol[- ]?free|soft[- ]?drink|soda|juice|water|coffee|tea/.test(txt)
    && !/alcoholic[- ]beverages|cocktail|gin and tonic/.test(txt))return {category:15,faction:"nimrod"};
  for(const [category,faction,words] of CATEGORIES){
    if(words.some(w=>new RegExp("(^|[^a-z])"+w+"([^a-z]|$)").test(txt)))return {category,faction};
  }
  throw Error("Product category cannot be verified");
}
function buildBase(code:string,hash:string,category:number,faction:string) {
  const seed=BigInt("0x"+hash.slice(0,15));
  const id=(offset:number,length:number)=>parseInt(hash.slice(offset,offset+length),16);
  const gender=(seed&1n)===1n?"female":"male";
  const archetypes:Record<string,string>={
    pirate:"Sea Corsair",militiaman:"Frontier Sentinel",bandit:"Sunset Outlaw",druid:"Highland Mystic",
    barbarian:"Frost Reaver",paladin:"Gilded Warden",alchemist:"Botanical Artificer",
    bard:"Velvet Virtuoso",red_mage:"Crimson Arcanist",white_mage:"Ivory Oracle",
    black_mage:"Void Hexer",brawler:"Iron Bruiser",samurai:"Blossom Ronin",
    viking:"Runestone Raider",rogue:"Midnight Stalker",nimrod:"Fizz Fool"
  };
  const palette=[
    [[.72,.42,.12,1],[.35,.18,.05,1]],
    [[.12,.42,.28,1],[.05,.2,.12,1]],
    [[.15,.28,.65,1],[.08,.12,.35,1]],
    [[.75,.82,.9,1],[.45,.5,.58,1]]
  ][id(19,2)%4];
  const components:Record<string,string>={
    gender,archetype:archetypes[faction],
    silhouette:["athletic","lean","stocky","regal"][id(21,2)%4],
    face:"face_0"+(1+id(23,2)%4),
    skin:"skin_0"+(1+id(25,2)%5),
    hair:"hair_0"+(1+id(27,2)%6),
    outfit:"outfit_0"+(1+id(29,2)%4),
    weapon:"weapon_0"+(1+id(31,2)%3),
    headwear:["hood","circlet","none","helm"][id(33,2)%4]
  };
  const signature=Object.keys(components).sort().map(k=>k+"="+components[k]).join("|");
  const baseAtk=12+id(35,2)%28, baseDef=12+id(37,2)%28, hp=80+id(39,2)%60;
  const ep=42+id(41,2)%18, reg=10+id(43,2)%14, special=18+id(45,2)%22;
  const prefix=faction[0].toUpperCase()+faction.slice(1).replaceAll("_"," ");
  const name=prefix+" "+hash.slice(4,10).toUpperCase();
  return {
    name,faction,category,gender,base_archetype:archetypes[faction],design_version:2,
    seed_value:Number(seed),level:1,xp:0,appearance_components:components,appearance_signature:signature,
    bottle_palette_name:"UPC Palette",tint_primary:palette[0],tint_secondary:palette[1],
    tint_accent:[.86,.66,.24,1],
    variant_pattern:id(47,2)%6,variant_crest:id(49,2)%5,
    variant_weapon_style:id(51,2)%4,variant_hue_shift:0,
    base_attack:baseAtk,base_defense:baseDef,base_max_hp:hp,base_max_energy:ep,
    base_regular_power:reg,base_special_power:special,
    attack:baseAtk,defense:baseDef,max_hp:hp,max_energy:ep,
    regular_move:"Strike",special_move:"Special",regular_power:reg,special_power:special
  };
}
Deno.serve(async(req)=>{
  if(req.method!=="POST")return fail("POST required",405);
  if(!KEY||!URL)return fail("Backend is not configured",503);
  const authorization=req.headers.get("authorization")??"";
  const token=authorization.startsWith("Bearer ")?authorization.slice(7):"";
  if(!token)return fail("Sign in required",401);
  const {data:{user},error}=await staff.auth.getUser(token);
  if(error||!user)return fail("Invalid session",401);
  let body:Record<string,unknown>={};
  try {
    if(Number(req.headers.get("content-length")||0)>8_000_000)return fail("Request too large",413);
    body=await req.json();
    const operation=String(body.operation??"");
    const lat=Number(body.latitude), lon=Number(body.longitude),accuracy=Number(body.accuracy_m);
    if(!Number.isFinite(lat)||!Number.isFinite(lon)||Math.abs(lat)>90||Math.abs(lon)>180||
      !Number.isFinite(accuracy)||accuracy<0||accuracy>75) return fail("Accurate location required");
    await verifyDevice(user.id,lat,lon,body.location_integrity_token);
    if(operation==="register_location"){
      const site=await provider(siteURL,{latitude:lat,longitude:lon});
      if(site?.noncommercial!==true||site?.business===true||!site?.reference)
        return fail("Only verified private/non-business scanning locations allowed");
      const record={user_id:user.id,latitude:lat,longitude:lon,
        site_kind:"private_noncommercial",business_check_reference:String(site.reference)};
      const {error:e}=await staff.from("scan_locations_private").upsert(record,{onConflict:"user_id"});
      if(e)return fail(e.message,e.code==="P0001"?429:400);
      return json({ok:true,message:"Private scanning location registered. Changes locked for 30 days."});
    }
    const {data:loc,error:locErr}=await staff.from("scan_locations_private")
      .select("latitude,longitude,last_changed_at").eq("user_id",user.id).maybeSingle();
    if(locErr||!loc)return fail("Register your fixed private scanning location first",403);
    if(distance(lat,lon,loc.latitude,loc.longitude)>Math.max(75,accuracy*2))
      return fail("You must scan at your registered location",403);
    if(operation==="begin_scan"){
      const barcode=safeBarcode(body.barcode);
      if(!barcode)return fail("Unsupported retail barcode");
      const hash=await sha(barcode);
      const {data:owned}=await staff.from("user_warriors")
        .select("blueprint_id,warrior_blueprints!inner(barcode_hash)")
        .eq("user_id",user.id).eq("warrior_blueprints.barcode_hash",hash).limit(1);
      if(owned?.length)return fail("Warrior Already Discovered",409);
      await classifyProduct(barcode);
      const code=rnd(4);
      const challenge={user_id:user.id,normalized_barcode:barcode,barcode_hash:hash,
        code_hash:await sha(code),location_changed_at:loc.last_changed_at};
      const {data:c,error:ce}=await staff.from("scan_challenges_private")
        .insert(challenge).select("id,expires_at").single();
      if(ce||!c)return fail("Could not issue verification challenge",500);
      return json({ok:true,challenge_id:c.id,handwritten_code:code,expires_at:c.expires_at,
        instructions:"Handwrite the code. Capture the physical bottle and handwritten paper together in the live camera challenge."});
    }
    if(operation==="submit_proof"){
      if(!photoURL)return fail("Trusted photo proof verification is not configured",503);
      const challengeId=String(body.challenge_id??"");
      if(!/^[0-9a-f-]{36}$/i.test(challengeId))return fail("Invalid challenge ID");
      const {data:c}=await staff.from("scan_challenges_private").select("*")
        .eq("id",challengeId).eq("user_id",user.id).maybeSingle();
      if(!c||c.consumed_at||Date.parse(c.expires_at)<Date.now())return fail("Expired or used challenge",409);
      if(c.location_changed_at!==loc.last_changed_at)return fail("Scanning location has changed",409);
      const bytes=String(body.photo_base64??"");
      if(bytes.length<1000||bytes.length>7_500_000)return fail("Invalid proof image");
      const proof=await provider(photoURL,{photo_base64:bytes,challenge_id:challengeId,
        expected_barcode:c.normalized_barcode});
      if(proof?.decision!=="approved"||proof?.real_bottle!==true||
        proof?.physical_handwritten_code!==true||proof?.liveness_pass!==true||
        proof?.rephotographed!==false||proof?.manipulated!==false||
        safeBarcode(proof?.recognized_barcode)!==c.normalized_barcode||
        await sha(String(proof?.recognized_code??"").trim().toUpperCase())!==c.code_hash)
        return fail("Photo could not be authenticated. Try again or request review.",403);
      const cls=await classifyProduct(c.normalized_barcode);
      const blueprint=buildBase(c.normalized_barcode,c.barcode_hash,cls.category,cls.faction);
      const digest=await sha(bytes);
      const {data:blueprintId,error:mintError}=await staff.rpc("finalize_verified_warrior_scan",{
        p_user_id:user.id,p_challenge_id:c.id,p_code_hash:c.code_hash,
        p_photo_digest:digest,p_faction:cls.faction,p_category:cls.category,
        p_seed:blueprint.seed_value,p_blueprint:blueprint,
        p_verdict:{provider:"configured_bottle_proof",decision:"approved"}
      });
      if(mintError)return fail(mintError.message,409);
      const {data:canonical}=await staff.from("warrior_blueprints")
        .select("base_data,barcode_hash").eq("id",blueprintId).single();
      return json({ok:true,warrior:canonical?.base_data,barcode:c.normalized_barcode});
    }
    return fail("Unknown operation",400);
  } catch(e) {
    // Never leak attestation tokens, photo contents, secrets or exact address.
    return fail(e instanceof Error?e.message:"Verification unavailable",503);
  }
});
