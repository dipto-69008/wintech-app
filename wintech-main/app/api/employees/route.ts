import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Employee from '@/models/Employee';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const status = searchParams.get('status') || '';
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '50');

    const branchId = searchParams.get('branchId');
    const query: Record<string, unknown> = {};
    if (search) query.$or = [
      { name: { $regex: search, $options: 'i' } },
      { employeeCode: { $regex: search, $options: 'i' } },
      { contactNo: { $regex: search, $options: 'i' } },
    ];
    if (status) query.status = status;
    if (branchId) query.branchId = parseInt(branchId);

    const [data, total] = await Promise.all([
      Employee.find(query).sort({ name: 1 }).skip((page - 1) * limit).limit(limit).lean(),
      Employee.countDocuments(query),
    ]);

    return NextResponse.json({ data, total, page, limit });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const doc = await Employee.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
