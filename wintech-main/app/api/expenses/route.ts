import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Expense from '@/models/Expense';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const status = searchParams.get('status') || '';
    const search = searchParams.get('search') || '';
    const branchId = searchParams.get('branchId');
    const query: Record<string, unknown> = {};
    if (status && status !== 'all') query.status = status;
    if (search) query.$or = [
      { employee: { $regex: search, $options: 'i' } },
      { description: { $regex: search, $options: 'i' } },
      { category: { $regex: search, $options: 'i' } },
    ];
    if (branchId) query.branchId = parseInt(branchId);
    const data = await Expense.find(query).sort({ createdAt: -1 }).lean();
    return NextResponse.json({ data, total: data.length });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const doc = await Expense.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
