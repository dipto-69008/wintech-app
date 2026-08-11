import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Employee from '@/models/Employee';

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const { email, password } = await req.json();

    if (!email || !password) {
      return NextResponse.json({ error: 'Email and password required' }, { status: 400 });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const emp = await Employee.findOne({
      $expr: { $eq: [{ $toLower: '$email' }, normalizedEmail] },
      status: 'a',
    }).lean() as (Record<string, unknown> & { _id: unknown; name: string; email: string; role?: string; designation?: string; department?: string; password?: string }) | null;

    if (!emp) {
      return NextResponse.json({ error: 'Invalid email or password' }, { status: 401 });
    }

    if (!emp.password) {
      return NextResponse.json({ error: 'No password set for this account. Contact admin.' }, { status: 401 });
    }

    if (emp.password !== password) {
      return NextResponse.json({ error: 'Invalid email or password' }, { status: 401 });
    }

    return NextResponse.json({
      id: String(emp._id),
      name: emp.name,
      email: emp.email,
      role: (emp.role as string) || 'employee',
      designation: emp.designation,
      department: emp.department,
    });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
