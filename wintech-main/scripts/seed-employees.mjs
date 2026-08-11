import mongoose from 'mongoose';
import { readFileSync } from 'fs';

const env = readFileSync('.env.local', 'utf8');
const MONGODB_URI = env.match(/MONGODB_URI=(.+)/)?.[1]?.trim();
if (!MONGODB_URI) { console.error('No MONGODB_URI'); process.exit(1); }

const EmployeeSchema = new mongoose.Schema({
  employeeCode: String, name: String, designation: String,
  department: String, presentAddress: String, contactNo: String, status: { type: String, default: 'a' }
}, { timestamps: true });
const Employee = mongoose.model('Employee', EmployeeSchema);

const employees = [
  { sl:1, name:"Sonjoy Ghosh", designation:"Deputy Manager", area:"Head Office, Dhaka", phone:"01332812203" },
  { sl:2, name:"Md Sanaullah", designation:"A/c & office Asso.", area:"Head Office, Dhaka", phone:"01939916408" },
  { sl:3, name:"Md Asraful Islam", designation:"Sr. Officer", area:"Cumilla 01", phone:"01332812209" },
  { sl:4, name:"Showkat Suboj", designation:"Mr. Asso.", area:"Laxsham, Cumilla 02", phone:"01332812206" },
  { sl:5, name:"Pobitrow Kumar Mondal", designation:"Officer", area:"Cumilla 03", phone:"01332812207" },
  { sl:6, name:"Md Hijbul Bahar", designation:"Executive", area:"Cumilla 04", phone:"01332812208" },
  { sl:7, name:"Joyanta Das", designation:"Officer", area:"Feni", phone:"01332812211" },
  { sl:8, name:"Shankor Kumar Das", designation:"Sr. Officer", area:"Bakra, Jessore", phone:"01332812216" },
  { sl:9, name:"Md Abu Syed", designation:"Executive", area:"Gouripur, Mymensingh", phone:"01332812212" },
  { sl:10, name:"Md Shaiem Akand", designation:"Officer", area:"Fulbaria", phone:"01939916413" },
  { sl:11, name:"Md Shepon", designation:"Jr. Officer", area:"Muktagasa", phone:"01332812213" },
  { sl:12, name:"Md Abu Hanif", designation:"Officer", area:"Tarakanda", phone:"01332812214" },
  { sl:13, name:"Abdus Selim", designation:"Officer", area:"Phulpur", phone:"01332812215" },
  { sl:14, name:"Md Sorowar Hossain", designation:"Mr. Asso.", area:"Bogura 01", phone:"01332812218" },
  { sl:15, name:"Md Yousuf Shamim", designation:"Officer", area:"Bogura 02", phone:"01332812217" },
];

function getDept(d) {
  if (d.toLowerCase().includes('a/c') || d.toLowerCase().includes('account')) return 'Accounts';
  if (d.toLowerCase().includes('manager')) return 'Management';
  return 'Sales';
}

await mongoose.connect(MONGODB_URI);
let added=0, skipped=0;
for (const e of employees) {
  const exists = await Employee.findOne({ name: e.name });
  if (exists) { console.log('Skip:', e.name); skipped++; continue; }
  await Employee.create({ employeeCode:'EMP-'+String(e.sl).padStart(3,'0'), name:e.name, designation:e.designation, department:getDept(e.designation), presentAddress:e.area, contactNo:e.phone, status:'a' });
  console.log('Added:', e.name);
  added++;
}
console.log(`Done — added:${added} skipped:${skipped}`);
await mongoose.disconnect();
