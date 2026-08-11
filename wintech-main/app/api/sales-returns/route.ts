import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import SalesReturn from '@/models/SalesReturn';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const status = searchParams.get('status') || '';

    const query: Record<string, unknown> = {};
    if (search) query.$or = [
      { returnNo: { $regex: search, $options: 'i' } },
      { partyName: { $regex: search, $options: 'i' } },
    ];
    if (status) query.status = status;

    const data = await SalesReturn.find(query).sort({ createdAt: -1 }).lean();
    return NextResponse.json({ data, total: data.length });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    if (!body.returnNo) {
      const count = await SalesReturn.countDocuments();
      body.returnNo = `RET-${String(count + 1).padStart(4, '0')}`;
    }
    const doc = await SalesReturn.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
