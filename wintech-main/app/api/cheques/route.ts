import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Cheque from '@/models/Cheque';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const status = searchParams.get('status') || '';
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '100');
    const from = searchParams.get('from');
    const to = searchParams.get('to');

    const query: Record<string, unknown> = {};
    if (search) query.$or = [
      { chequeNo: { $regex: search, $options: 'i' } },
      { partyName: { $regex: search, $options: 'i' } },
      { bankName: { $regex: search, $options: 'i' } },
    ];
    if (status) query.status = status;
    if (from || to) {
      query.chequeDate = {};
      if (from) (query.chequeDate as Record<string, unknown>).$gte = new Date(from);
      if (to) (query.chequeDate as Record<string, unknown>).$lte = new Date(to + 'T23:59:59');
    }

    const [data, total] = await Promise.all([
      Cheque.find(query).sort({ chequeDate: -1 }).skip((page - 1) * limit).limit(limit).lean(),
      Cheque.countDocuments(query),
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
    const cheque = await Cheque.create(body);
    return NextResponse.json(cheque, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
