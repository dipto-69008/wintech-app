import { NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Employee from '@/models/Employee';

const EMPLOYEES = [
  { sl: 1,  name: 'Sonjoy Ghosh',         designation: 'Deputy Manager',         areaName: 'Head Office, Dhaka',   contactNo: '01332812203' },
  { sl: 2,  name: 'Md Sanaullah',          designation: 'A/c & Office Associate', areaName: 'Head Office, Dhaka',   contactNo: '01939916408' },
  { sl: 3,  name: 'Md Asraful Islam',      designation: 'Sr. Officer',            areaName: 'Cumilla 01',           contactNo: '01332812209' },
  { sl: 4,  name: 'Showkat Suboj',         designation: 'Mr. Associate',          areaName: 'Laxsham, Cumilla 02', contactNo: '01332812206' },
  { sl: 5,  name: 'Pobitrow Kumar Mondal', designation: 'Officer',                areaName: 'Cumilla 03',           contactNo: '01332812207' },
  { sl: 6,  name: 'Md Hijbul Bahar',       designation: 'Executive',              areaName: 'Cumilla 04',           contactNo: '01332812208' },
  { sl: 7,  name: 'Joyanta Das',           designation: 'Officer',                areaName: 'Feni',                 contactNo: '01332812211' },
  { sl: 8,  name: 'Shankor Kumar Das',     designation: 'Sr. Officer',            areaName: 'Bakra, Jessore',       contactNo: '01332812216' },
  { sl: 9,  name: 'Md Abu Syed',           designation: 'Executive',              areaName: 'Gouripur, Mymensingh', contactNo: '01332812212' },
  { sl: 10, name: 'Md Shaiem Akand',       designation: 'Officer',                areaName: 'Fulbaria',             contactNo: '01939916413' },
  { sl: 11, name: 'Md Shepon',             designation: 'Jr. Officer',            areaName: 'Muktagasa',            contactNo: '01332812213' },
  { sl: 12, name: 'Md Abu Hanif',          designation: 'Officer',                areaName: 'Tarakanda',            contactNo: '01332812214' },
  { sl: 13, name: 'Abdus Selim',           designation: 'Officer',                areaName: 'Phulpur',              contactNo: '01332812215' },
  { sl: 14, name: 'Md Sorowar Hossain',    designation: 'Mr. Associate',          areaName: 'Bogura 01',            contactNo: '01332812218' },
  { sl: 15, name: 'Md Yousuf Shamim',      designation: 'Officer',                areaName: 'Bogura 02',            contactNo: '01332812217' },
];

export async function POST() {
  try {
    await connectDB();
    let inserted = 0;
    let skipped = 0;
    for (const emp of EMPLOYEES) {
      const normalised = emp.name.trim().toLowerCase();
      const exists = await Employee.findOne({
        $expr: { $eq: [{ $toLower: '$name' }, normalised] },
      });
      if (exists) { skipped++; continue; }
      await Employee.create({
        employeeCode: 'EMP' + String(emp.sl).padStart(3, '0'),
        name: emp.name.trim(),
        designation: emp.designation,
        department: 'Sales & Marketing',
        areaName: emp.areaName,
        contactNo: emp.contactNo,
        status: 'a',
        addTime: new Date(),
      });
      inserted++;
    }
    return NextResponse.json({ message: 'Done. Inserted: ' + inserted + ', Skipped: ' + skipped });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
