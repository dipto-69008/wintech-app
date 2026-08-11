import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Target from '@/models/Target';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const branchId = searchParams.get('branchId');
    const query: Record<string, unknown> = {};
    if (branchId) query.branchId = parseInt(branchId);
    const data = await Target.find(query).sort({ createdAt: -1 }).lean();
    return NextResponse.json({ data, total: data.length });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const doc = await Target.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
