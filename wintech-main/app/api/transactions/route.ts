import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Transaction from '@/models/Transaction';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const type = searchParams.get('type') || '';
    const search = searchParams.get('search') || '';
    const branchId = searchParams.get('branchId');
    const query: Record<string, unknown> = {};
    if (type && type !== 'all') query.type = type;
    if (search) query.$or = [
      { description: { $regex: search, $options: 'i' } },
      { category: { $regex: search, $options: 'i' } },
    ];
    if (branchId) query.branchId = parseInt(branchId);
    const branchMatch = branchId ? { branchId: parseInt(branchId) } : {};
    const data = await Transaction.find(query).sort({ createdAt: -1 }).limit(500).lean();
    const totalIncome = await Transaction.aggregate([{ $match: { ...branchMatch, type: 'income' } }, { $group: { _id: null, total: { $sum: '$amount' } } }]);
    const totalExpense = await Transaction.aggregate([{ $match: { ...branchMatch, type: 'expense' } }, { $group: { _id: null, total: { $sum: '$amount' } } }]);
    return NextResponse.json({
      data, total: data.length,
      totalIncome: totalIncome[0]?.total || 0,
      totalExpense: totalExpense[0]?.total || 0,
    });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const doc = await Transaction.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
