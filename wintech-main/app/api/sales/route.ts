import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import SaleMaster from '@/models/SaleMaster';
import SaleDetail from '@/models/SaleDetail';
import Product from '@/models/Product';
import Party from '@/models/Party';
import Branch from '@/models/Branch';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '50');
    const from = searchParams.get('from');
    const to = searchParams.get('to');
    const statusParam = searchParams.get('status');
    const branchId = searchParams.get('branchId');

    const query: Record<string, unknown> = {};

    if (statusParam) {
      query.status = statusParam;
    } else {
      query.status = 'a';
    }
    if (branchId) query.branchId = parseInt(branchId);

    if (search) query.$or = [
      { invoiceNo: { $regex: search, $options: 'i' } },
      { partyName: { $regex: search, $options: 'i' } },
    ];
    if (from || to) {
      query.saleDate = {};
      if (from) (query.saleDate as Record<string, unknown>).$gte = new Date(from);
      if (to) (query.saleDate as Record<string, unknown>).$lte = new Date(to + 'T23:59:59');
    }

    const [data, total] = await Promise.all([
      SaleMaster.find(query).sort({ saleDate: -1 }).skip((page - 1) * limit).limit(limit).lean(),
      SaleMaster.countDocuments(query),
    ]);

    const branchIds = [...new Set(data.map((sale) => sale.branchId).filter((id): id is number => typeof id === 'number'))];
    const branches = branchIds.length
      ? await Branch.find({ legacyId: { $in: branchIds } }).select('legacyId name').lean()
      : [];
    const branchNames = new Map(branches.map((branch) => [branch.legacyId, branch.name]));
    const withBranchName = data.map((sale) => ({
      ...sale,
      branchName: typeof sale.branchId === 'number' ? branchNames.get(sale.branchId) || '' : '',
    }));

    return NextResponse.json({ data: withBranchName, total, page, limit });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const { details, ...masterData } = body;

    // ── Server-side credit limit block ──
    if (masterData.partyId) {
      const party = await Party.findById(masterData.partyId).lean() as { _id: unknown; name?: string; creditLimit?: number } | null;
      if (party && (party.creditLimit || 0) > 0) {
        const agg = await SaleMaster.aggregate([
          { $match: { partyId: party._id, dueAmount: { $gt: 0 }, status: { $nin: ['cancelled', 'returned'] } } },
          { $group: { _id: null, total: { $sum: '$dueAmount' } } },
        ]);
        const currentDue: number = agg[0]?.total || 0;
        const usagePct = (currentDue / party.creditLimit!) * 100;
        if (usagePct >= 100) {
          return NextResponse.json(
            { error: `Credit limit full for ${party.name}. Outstanding due ৳${currentDue.toLocaleString()} has reached the limit of ৳${party.creditLimit!.toLocaleString()}. Clear dues before creating a new invoice.` },
            { status: 422 }
          );
        }
      }
    }

    const master = await SaleMaster.create(masterData);

    if (details && Array.isArray(details) && details.length > 0) {
      const detailDocs = details.map((d: Record<string, unknown>) => ({
        ...d,
        saleMasterId: master._id,
      }));
      await SaleDetail.insertMany(detailDocs);

      // Deduct stock for bonus items
      const bonusItems = details.filter((d: Record<string, unknown>) => d.isBonus && d.productId);
      for (const bd of bonusItems) {
        await Product.findByIdAndUpdate(bd.productId, {
          $inc: { stock: -(bd.quantity as number) },
        });
      }
    }

    return NextResponse.json(master, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
