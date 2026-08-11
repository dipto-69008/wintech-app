import mongoose, { Schema, Document } from 'mongoose';

export interface IPayroll extends Document {
  employeeId?: mongoose.Types.ObjectId;
  employeeLegacyId?: number;
  employeeName: string;
  designation?: string;
  department?: string;
  month: number;
  year: number;
  basicSalary: number;
  houseRent: number;
  medicalAllowance: number;
  transportAllowance: number;
  otherAllowance: number;
  grossSalary: number;
  providentFund: number;
  tax: number;
  otherDeductions: number;
  totalDeductions: number;
  netSalary: number;
  paidAmount: number;
  dueAmount: number;
  paymentDate?: Date;
  paymentMethod: string;
  status: 'pending' | 'paid' | 'partial';
  note?: string;
  addBy?: string;
}

const PayrollSchema = new Schema<IPayroll>({
  employeeId: { type: Schema.Types.ObjectId, ref: 'Employee' },
  employeeLegacyId: Number,
  employeeName: { type: String, required: true },
  designation: String,
  department: String,
  month: { type: Number, required: true },
  year: { type: Number, required: true },
  basicSalary: { type: Number, default: 0 },
  houseRent: { type: Number, default: 0 },
  medicalAllowance: { type: Number, default: 0 },
  transportAllowance: { type: Number, default: 0 },
  otherAllowance: { type: Number, default: 0 },
  grossSalary: { type: Number, default: 0 },
  providentFund: { type: Number, default: 0 },
  tax: { type: Number, default: 0 },
  otherDeductions: { type: Number, default: 0 },
  totalDeductions: { type: Number, default: 0 },
  netSalary: { type: Number, default: 0 },
  paidAmount: { type: Number, default: 0 },
  dueAmount: { type: Number, default: 0 },
  paymentDate: Date,
  paymentMethod: { type: String, default: 'Bank Transfer' },
  status: { type: String, enum: ['pending', 'paid', 'partial'], default: 'pending' },
  note: String,
  addBy: String,
}, { timestamps: true });

PayrollSchema.index({ year: -1, month: -1 });
PayrollSchema.index({ employeeId: 1 });

export default mongoose.models.Payroll || mongoose.model<IPayroll>('Payroll', PayrollSchema);
