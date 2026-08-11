import mongoose from 'mongoose';
import { readFileSync } from 'fs';

const env = readFileSync('.env.local', 'utf8');
const MONGODB_URI = env.match(/MONGODB_URI=(.+)/)?.[1]?.trim();
if (!MONGODB_URI) { console.error('No MONGODB_URI'); process.exit(1); }

const ProductSchema = new mongoose.Schema({
  code:String, name:String, packSize:String, purchaseRate:{type:Number,default:0},
  sellingPrice:{type:Number,default:0}, stock:{type:Number,default:0},
  stockCumilla:{type:Number,default:0}, stockMymensingh:{type:Number,default:0},
  stockBogra:{type:Number,default:0}, stockJessore:{type:Number,default:0}, stockFeni:{type:Number,default:0},
  unit:String, status:{type:String,default:'a'},
},{timestamps:true});
const Product = mongoose.model('Product', ProductSchema);

const prods = [
  {name:"Aqua Amla",size:"100gm",c:293,m:699,b:143,j:0,f:0,t:1135},
  {name:"Aqua Amla",size:"500gm",c:409,m:116,b:37,j:70,f:120,t:752},
  {name:"Aqua Milk Premium",size:"500gm",c:6942,m:454,b:402,j:104,f:80,t:7982},
  {name:"Aqua Safe Plus",size:"5kg",c:64,m:303,b:23,j:23,f:40,t:453},
  {name:"Bencidal Plus",size:"100ml",c:2236,m:761,b:81,j:14,f:110,t:3202},
  {name:"Bencidal Plus",size:"500ml",c:106,m:205,b:24,j:189,f:123,t:647},
  {name:"Bottom Light",size:"100gm",c:1097,m:305,b:16,j:64,f:70,t:1552},
  {name:"Bottom Light",size:"500gm",c:485,m:132,b:26,j:42,f:134,t:819},
  {name:"Brood Plus",size:"500gm",c:114,m:325,b:34,j:28,f:48,t:549},
  {name:"Eco Fresh",size:"1kg",c:106,m:140,b:73,j:19,f:35,t:373},
  {name:"Eco Fresh Plus",size:"1kg",c:1193,m:687,b:148,j:168,f:195,t:2391},
  {name:"Energy Flow",size:"500gm",c:145,m:215,b:48,j:214,f:96,t:718},
  {name:"Enrosef",size:"100ml",c:0,m:0,b:0,j:0,f:0,t:0},
  {name:"Enrosef",size:"500ml",c:17,m:0,b:0,j:0,f:0,t:17},
  {name:"Erostep",size:"100gm",c:9,m:0,b:0,j:39,f:0,t:48},
  {name:"Green Vita",size:"500gm",c:111,m:289,b:34,j:40,f:40,t:312},
  {name:"Liver Win",size:"500ml",c:1246,m:337,b:70,j:86,f:68,t:1737},
  {name:"Oxy-win (Granular)",size:"1kg",c:152,m:26.5,b:13,j:8,f:80,t:142.5},
  {name:"Oxy-win (Tablet)",size:"1kg",c:2750,m:373,b:14,j:32.5,f:100,t:3269.5},
  {name:"Pro Yucca for Fish",size:"100ml",c:1298,m:421,b:82,j:134,f:80,t:2015},
  {name:"Pro Yucca for Fish",size:"500ml",c:1688,m:293,b:37,j:144,f:89,t:2251},
  {name:"Vitafort Aqua",size:"500gm",c:157,m:227,b:60,j:13,f:50,t:507},
  {name:"Vitazyme Aqua",size:"500gm",c:2140,m:595,b:65,j:47,f:80,t:2927},
  {name:"Win C",size:"100gm",c:441,m:0,b:0,j:0,f:0,t:441},
  {name:"Win C",size:"500gm",c:0,m:0,b:0,j:0,f:0,t:0},
  {name:"Win Health",size:"500ml",c:331,m:214,b:45,j:15,f:23,t:628},
  {name:"Win Max Plus",size:"50ml",c:337,m:1304,b:203,j:91,f:28,t:1963},
  {name:"Win Max Plus",size:"200ml",c:364,m:516,b:55,j:252,f:56,t:1243},
  {name:"Win Pro Aqua",size:"100gm",c:370,m:545,b:80,j:144,f:199,t:1338},
  {name:"Win Pro Aqua",size:"200gm",c:1797,m:575,b:35,j:112,f:68,t:2587},
  {name:"Winxide Aqua",size:"100ml",c:162,m:408,b:69,j:0,f:34,t:673},
  {name:"Winxide Aqua",size:"500ml",c:106,m:212,b:0,j:119,f:115,t:552},
  {name:"Vita Fort Aqua",size:"500g",c:0,m:0,b:6,j:0,f:0,t:6},
];

function mkCode(n,s){return n.replace(/[^a-zA-Z0-9]/g,'').toUpperCase().slice(0,6)+'-'+s.replace(/[^a-zA-Z0-9]/g,'').toUpperCase();}
function mkUnit(s){return s.includes('ml')||s.includes('ML')?'ML':s.includes('kg')||s.includes('KG')?'KG':'GM';}

await mongoose.connect(MONGODB_URI);
let added=0,updated=0;
for(const p of prods){
  const code=mkCode(p.name,p.size);
  const ex=await Product.findOne({name:p.name,packSize:p.size});
  if(ex){
    await Product.updateOne({_id:ex._id},{stockCumilla:p.c,stockMymensingh:p.m,stockBogra:p.b,stockJessore:p.j,stockFeni:p.f,stock:p.t});
    console.log('Updated:',p.name,p.size);updated++;
  } else {
    await Product.create({code,name:p.name,packSize:p.size,purchaseRate:0,sellingPrice:0,stock:p.t,stockCumilla:p.c,stockMymensingh:p.m,stockBogra:p.b,stockJessore:p.j,stockFeni:p.f,unit:mkUnit(p.size),status:'a'});
    console.log('Added:',p.name,p.size);added++;
  }
}
console.log(`Done — added:${added} updated:${updated}`);
await mongoose.disconnect();
