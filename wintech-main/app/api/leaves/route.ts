import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Leave from '@/models/Leave';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const status = searchParams.get('status') || '';
    const query: Record<string, unknown> = {};
    if (status) query.status = status;
    const data = await Leave.find(query).sort({ createdAt: -1 }).lean();
    return NextResponse.json({ data });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    if (!body.appliedOn) body.appliedOn = new Date().toISOString().split('T')[0];
    const doc = await Leave.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
