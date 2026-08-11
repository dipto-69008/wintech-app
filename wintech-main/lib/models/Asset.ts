import mongoose, { Schema, Document } from 'mongoose';

export interface IAsset extends Document {
  name: string;
  category: string;
  serialNumber?: string;
  purchaseDate: string;
  purchaseCost: number;
  currentValue: number;
  depreciationRate: number;
  location: string;
  assignedTo?: string;
  status: 'active' | 'disposed' | 'under-maintenance';
  branchId?: number;
}

const AssetSchema = new Schema<IAsset>({
  name: { type: String, required: true },
  category: { type: String, required: true },
  serialNumber: String,
  purchaseDate: String,
  purchaseCost: { type: Number, default: 0 },
  currentValue: { type: Number, default: 0 },
  depreciationRate: { type: Number, default: 10 },
  location: { type: String, required: true },
  assignedTo: String,
  status: { type: String, enum: ['active', 'disposed', 'under-maintenance'], default: 'active' },
  branchId: Number,
}, { timestamps: true });

export default mongoose.models.Asset || mongoose.model<IAsset>('Asset', AssetSchema);
