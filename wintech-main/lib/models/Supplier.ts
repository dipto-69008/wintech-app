import mongoose, { Schema, Document } from 'mongoose';

export interface ISupplier extends Document {
  legacyId?: number;
  code: string;
  name: string;
  type?: string;
  phone?: string;
  mobile?: string;
  email?: string;
  officePhone?: string;
  address?: string;
  contactPerson?: string;
  district?: string;
  country?: string;
  web?: string;
  previousDue?: number;
  status: string;
  branchId?: number;
  addBy?: string;
  addTime?: Date;
}

const SupplierSchema = new Schema<ISupplier>({
  legacyId: { type: Number, index: true },
  code: { type: String, required: true, trim: true },
  name: { type: String, required: true, trim: true },
  type: String,
  phone: String,
  mobile: String,
  email: String,
  officePhone: String,
  address: String,
  contactPerson: String,
  district: String,
  country: String,
  web: String,
  previousDue: { type: Number, default: 0 },
  status: { type: String, default: 'a' },
  branchId: Number,
  addBy: String,
  addTime: Date,
}, { timestamps: true });

SupplierSchema.index({ code: 1 });
SupplierSchema.index({ name: 'text' });

export default mongoose.models.Supplier || mongoose.model<ISupplier>('Supplier', SupplierSchema);
