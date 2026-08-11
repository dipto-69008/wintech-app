import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Survey from '@/models/Survey';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const type    = searchParams.get('type') || '';
    const search  = searchParams.get('search') || '';
    const from    = searchParams.get('from') || '';
    const to      = searchParams.get('to') || '';
    const limit   = Math.min(parseInt(searchParams.get('limit') || '100'), 500);

    const q: Record<string, unknown> = {};
    if (type)   q.type = type;
    if (search) q.$or = [
      { workerName: { $regex: search, $options: 'i' } },
      { farmName:   { $regex: search, $options: 'i' } },
      { shopName:   { $regex: search, $options: 'i' } },
      { dealerName: { $regex: search, $options: 'i' } },
    ];
    if (from || to) {
      q.visitDate = {} as Record<string, unknown>;
      if (from) (q.visitDate as Record<string, unknown>)['$gte'] = new Date(from);
      if (to)   (q.visitDate as Record<string, unknown>)['$lte'] = new Date(to + 'T23:59:59');
    }

    const [data, total] = await Promise.all([
      Survey.find(q).sort({ visitDate: -1, createdAt: -1 }).limit(limit).lean(),
      Survey.countDocuments(q),
    ]);
    return NextResponse.json({ data, total });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const doc = await Survey.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
