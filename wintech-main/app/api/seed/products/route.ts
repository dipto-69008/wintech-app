import { NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Product from '@/models/Product';

// Branch columns: Cumilla, Mymensingh, Bogra, Jessore, Feni
const PRODUCTS = [
  { name: 'Aqua Amla',          packSize: '100gm', stockCumilla: 293,  stockMymensingh: 699,  stockBogra: 143, stockJessore: 0,    stockFeni: 0   },
  { name: 'Aqua Amla',          packSize: '500gm', stockCumilla: 409,  stockMymensingh: 116,  stockBogra: 37,  stockJessore: 70,   stockFeni: 120 },
  { name: 'Aqua Milk Premium',  packSize: '500gm', stockCumilla: 6942, stockMymensingh: 454,  stockBogra: 402, stockJessore: 104,  stockFeni: 80  },
  { name: 'Aqua Safe Plus',     packSize: '5kg',   stockCumilla: 64,   stockMymensingh: 303,  stockBogra: 23,  stockJessore: 23,   stockFeni: 40  },
  { name: 'Bencidal Plus',      packSize: '100ml', stockCumilla: 2236, stockMymensingh: 761,  stockBogra: 81,  stockJessore: 124,  stockFeni: 0   },
  { name: 'Bencidal Plus',      packSize: '500ml', stockCumilla: 106,  stockMymensingh: 205,  stockBogra: 24,  stockJessore: 189,  stockFeni: 123 },
  { name: 'Bottom Light',       packSize: '100gm', stockCumilla: 1097, stockMymensingh: 305,  stockBogra: 16,  stockJessore: 64,   stockFeni: 70  },
  { name: 'Bottom Light',       packSize: '500gm', stockCumilla: 485,  stockMymensingh: 132,  stockBogra: 26,  stockJessore: 42,   stockFeni: 134 },
  { name: 'Brood Plus',         packSize: '500gm', stockCumilla: 114,  stockMymensingh: 325,  stockBogra: 34,  stockJessore: 28,   stockFeni: 48  },
  { name: 'Eco Fresh',          packSize: '1kg',   stockCumilla: 106,  stockMymensingh: 140,  stockBogra: 73,  stockJessore: 19,   stockFeni: 35  },
  { name: 'Eco Fresh Plus',     packSize: '1kg',   stockCumilla: 1193, stockMymensingh: 687,  stockBogra: 148, stockJessore: 168,  stockFeni: 195 },
  { name: 'Energy Flow',        packSize: '500gm', stockCumilla: 145,  stockMymensingh: 215,  stockBogra: 48,  stockJessore: 214,  stockFeni: 96  },
  { name: 'Enrosef',            packSize: '100ml', stockCumilla: 0,    stockMymensingh: 0,    stockBogra: 0,   stockJessore: 0,    stockFeni: 0   },
  { name: 'Enrosef',            packSize: '500ml', stockCumilla: 17,   stockMymensingh: 0,    stockBogra: 0,   stockJessore: 0,    stockFeni: 0   },
  { name: 'Erostep',            packSize: '100gm', stockCumilla: 9,    stockMymensingh: 0,    stockBogra: 0,   stockJessore: 39,   stockFeni: 0   },
  { name: 'Green Vita',         packSize: '500gm', stockCumilla: 111,  stockMymensingh: 28,   stockBogra: 93,  stockJessore: 40,   stockFeni: 40  },
  { name: 'Liver Win',          packSize: '500ml', stockCumilla: 1246, stockMymensingh: 337,  stockBogra: 0,   stockJessore: 86,   stockFeni: 68  },
  { name: 'Oxy-win (Granular)', packSize: '1kg',   stockCumilla: 15,   stockMymensingh: 26.5, stockBogra: 13,  stockJessore: 88,   stockFeni: 0   },
  { name: 'Oxy-win (Tablet)',   packSize: '1kg',   stockCumilla: 2750, stockMymensingh: 373,  stockBogra: 14,  stockJessore: 32.5, stockFeni: 100 },
  { name: 'Pro Yucca for Fish', packSize: '100ml', stockCumilla: 1298, stockMymensingh: 421,  stockBogra: 82,  stockJessore: 134,  stockFeni: 80  },
  { name: 'Pro Yucca for Fish', packSize: '500ml', stockCumilla: 1688, stockMymensingh: 293,  stockBogra: 37,  stockJessore: 144,  stockFeni: 89  },
  { name: 'Vitafort Aqua',      packSize: '500gm', stockCumilla: 157,  stockMymensingh: 227,  stockBogra: 60,  stockJessore: 13,   stockFeni: 50  },
  { name: 'Vitazyme Aqua',      packSize: '500gm', stockCumilla: 2140, stockMymensingh: 595,  stockBogra: 65,  stockJessore: 47,   stockFeni: 80  },
  { name: 'Win C',              packSize: '100gm', stockCumilla: 441,  stockMymensingh: 0,    stockBogra: 0,   stockJessore: 0,    stockFeni: 0   },
  { name: 'Win C',              packSize: '500gm', stockCumilla: 0,    stockMymensingh: 0,    stockBogra: 0,   stockJessore: 0,    stockFeni: 0   },
  { name: 'Win Health',         packSize: '500ml', stockCumilla: 331,  stockMymensingh: 214,  stockBogra: 45,  stockJessore: 15,   stockFeni: 23  },
  { name: 'Win Max Plus',       packSize: '50ml',  stockCumilla: 337,  stockMymensingh: 1304, stockBogra: 203, stockJessore: 91,   stockFeni: 28  },
  { name: 'Win Max Plus',       packSize: '200ml', stockCumilla: 364,  stockMymensingh: 516,  stockBogra: 55,  stockJessore: 252,  stockFeni: 56  },
  { name: 'Win Pro Aqua',       packSize: '100gm', stockCumilla: 370,  stockMymensingh: 545,  stockBogra: 80,  stockJessore: 144,  stockFeni: 199 },
  { name: 'Win Pro Aqua',       packSize: '200gm', stockCumilla: 1797, stockMymensingh: 575,  stockBogra: 35,  stockJessore: 112,  stockFeni: 68  },
  { name: 'Winxide Aqua',       packSize: '100ml', stockCumilla: 162,  stockMymensingh: 408,  stockBogra: 69,  stockJessore: 0,    stockFeni: 34  },
  { name: 'Winxide Aqua',       packSize: '500ml', stockCumilla: 106,  stockMymensingh: 212,  stockBogra: 0,   stockJessore: 119,  stockFeni: 115 },
  { name: 'Vita Fort Aqua',     packSize: '500gm', stockCumilla: 0,    stockMymensingh: 0,    stockBogra: 0,   stockJessore: 60,   stockFeni: 0   },
];

function makeCode(name: string, packSize: string, idx: number): string {
  const n = name.replace(/[^a-zA-Z0-9]/g, '').toUpperCase().slice(0, 5);
  const p = packSize.replace(/[^a-zA-Z0-9]/g, '').toUpperCase().slice(0, 4);
  return n + '-' + p + '-' + String(idx + 1).padStart(2, '0');
}

export async function POST() {
  try {
    await connectDB();
    let inserted = 0;
    let skipped = 0;
    for (let idx = 0; idx < PRODUCTS.length; idx++) {
      const p = PRODUCTS[idx];
      const exists = await Product.findOne({
        $expr: { $eq: [{ $toLower: '$name' }, p.name.trim().toLowerCase()] },
        packSize: p.packSize,
      });
      if (exists) { skipped++; continue; }
      const totalStock = p.stockCumilla + p.stockMymensingh + p.stockBogra + p.stockJessore + p.stockFeni;
      await Product.create({
        code: makeCode(p.name, p.packSize, idx),
        name: p.name.trim(),
        packSize: p.packSize,
        purchaseRate: 0,
        sellingPrice: 0,
        stock: totalStock,
        stockCumilla: p.stockCumilla,
        stockMymensingh: p.stockMymensingh,
        stockBogra: p.stockBogra,
        stockJessore: p.stockJessore,
        stockFeni: p.stockFeni,
        categoryName: 'Aqua',
        unit: p.packSize,
        status: 'a',
        addTime: new Date(),
      });
      inserted++;
    }
    return NextResponse.json({ message: 'Done. Inserted: ' + inserted + ', Skipped: ' + skipped });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
