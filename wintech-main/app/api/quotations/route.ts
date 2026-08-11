import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Quotation from '@/models/Quotation';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const query = search
      ? { $or: [{ partyName: { $regex: search, $options: 'i' } }, { quotationNo: { $regex: search, $options: 'i' } }] }
      : {};
    const data = await Quotation.find(query).sort({ createdAt: -1 }).limit(200).lean();
    return NextResponse.json({ data, total: data.length });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const count = await Quotation.countDocuments();
    const quotationNo = `QT-${String(count + 1).padStart(4, '0')}`;
    const doc = await Quotation.create({ ...body, quotationNo });
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
