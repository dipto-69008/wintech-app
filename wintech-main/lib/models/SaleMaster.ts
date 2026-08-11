import mongoose, { Schema, Document } from 'mongoose';

export interface ISaleMaster extends Document {
  legacyId?: number;
  invoiceNo: string;
  partyId?: mongoose.Types.ObjectId;
  partyLegacyId?: number;
  partyName?: string;
  employeeId?: number;
  saleDate: Date;
  description?: string;
  saleType?: string;
  paymentType?: string;
  totalAmount: number;
  discountAmount: number;
  taxAmount: number;
  freight?: number;
  subTotal: number;
  paidAmount: number;
  dueAmount: number;
  previousDue?: number;
  status: string;
  isService?: boolean;
  isOrder?: string;
  branchId?: number;
  addBy?: string;
  addTime?: Date;
  probablePaymentDate?: Date;
  paymentReminderSent?: string[];
}

const SaleMasterSchema = new Schema<ISaleMaster>({
  legacyId: { type: Number, index: true },
  invoiceNo: { type: String, required: true, trim: true },
  partyId: { type: Schema.Types.ObjectId, ref: 'Party' },
  partyLegacyId: Number,
  partyName: String,
  employeeId: Number,
  saleDate: { type: Date, required: true },
  description: String,
  saleType: String,
  paymentType: { type: String, default: 'Cash' },
  totalAmount: { type: Number, required: true, default: 0 },
  discountAmount: { type: Number, default: 0 },
  taxAmount: { type: Number, default: 0 },
  freight: { type: Number, default: 0 },
  subTotal: { type: Number, required: true, default: 0 },
  paidAmount: { type: Number, default: 0 },
  dueAmount: { type: Number, default: 0 },
  previousDue: { type: Number, default: 0 },
  status: { type: String, default: 'a' },
  isService: { type: Boolean, default: false },
  isOrder: String,
  branchId: Number,
  addBy: String,
  addTime: Date,
  probablePaymentDate: { type: Date },
  paymentReminderSent: { type: [String], default: [] },
}, { timestamps: true });

SaleMasterSchema.index({ invoiceNo: 1 });
SaleMasterSchema.index({ saleDate: -1 });
SaleMasterSchema.index({ partyLegacyId: 1 });

export default mongoose.models.SaleMaster || mongoose.model<ISaleMaster>('SaleMaster', SaleMasterSchema);
