import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import PurchaseReturn from '@/models/PurchaseReturn';
import PurchaseReturnDetail from '@/models/PurchaseReturnDetail';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '50');
    const from = searchParams.get('from');
    const to = searchParams.get('to');

    const query: Record<string, unknown> = {};
    if (search) query.$or = [
      { returnNo: { $regex: search, $options: 'i' } },
      { supplierName: { $regex: search, $options: 'i' } },
    ];
    if (from || to) {
      query.returnDate = {};
      if (from) (query.returnDate as Record<string, unknown>).$gte = new Date(from);
      if (to) (query.returnDate as Record<string, unknown>).$lte = new Date(to + 'T23:59:59');
    }

    const [data, total] = await Promise.all([
      PurchaseReturn.find(query).sort({ returnDate: -1 }).skip((page - 1) * limit).limit(limit).lean(),
      PurchaseReturn.countDocuments(query),
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
    const { details, ...masterData } = body;

    const master = await PurchaseReturn.create(masterData);

    if (details && Array.isArray(details) && details.length > 0) {
      const detailDocs = details.map((d: Record<string, unknown>) => ({
        ...d,
        purchaseReturnId: master._id,
      }));
      await PurchaseReturnDetail.insertMany(detailDocs);
    }

    return NextResponse.json(master, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
