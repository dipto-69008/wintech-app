import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Payroll from '@/models/Payroll';
import Employee from '@/models/Employee';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const month = searchParams.get('month');
    const year = searchParams.get('year');
    const status = searchParams.get('status') || '';
    const search = searchParams.get('search') || '';

    const query: Record<string, unknown> = {};
    if (month) query.month = parseInt(month);
    if (year) query.year = parseInt(year);
    if (status) query.status = status;
    if (search) query.employeeName = { $regex: search, $options: 'i' };

    const data = await Payroll.find(query).sort({ year: -1, month: -1, employeeName: 1 }).lean();
    const total = await Payroll.countDocuments(query);
    return NextResponse.json({ data, total });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();

    if (body.generateForMonth) {
      const { month, year } = body;
      const employees = await Employee.find({ status: 'a' }).lean();
      const existing = await Payroll.find({ month, year }).lean();
      const existingIds = new Set(existing.map((p: Record<string, unknown>) => String(p.employeeId || p.employeeLegacyId)));

      const newPayrolls = employees
        .filter((e: Record<string, unknown>) => !existingIds.has(String(e._id)))
        .map((e: Record<string, unknown>) => {
          const basic = Number(e.salary) || 0;
          const houseRent = Math.round(basic * 0.4);
          const medical = Math.round(basic * 0.1);
          const transport = Math.round(basic * 0.05);
          const gross = basic + houseRent + medical + transport;
          const pf = Math.round(gross * 0.05);
          const netSalary = gross - pf;
          return {
            employeeId: e._id,
            employeeName: String(e.name || ''),
            designation: String(e.designation || ''),
            department: String(e.department || ''),
            month,
            year,
            basicSalary: basic,
            houseRent,
            medicalAllowance: medical,
            transportAllowance: transport,
            otherAllowance: 0,
            grossSalary: gross,
            providentFund: pf,
            tax: 0,
            otherDeductions: 0,
            totalDeductions: pf,
            netSalary,
            paidAmount: 0,
            dueAmount: netSalary,
            paymentMethod: 'Bank Transfer',
            status: 'pending',
          };
        });

      if (newPayrolls.length > 0) {
        await Payroll.insertMany(newPayrolls);
      }
      return NextResponse.json({ generated: newPayrolls.length, existing: existing.length });
    }

    const payroll = await Payroll.create(body);
    return NextResponse.json(payroll, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
