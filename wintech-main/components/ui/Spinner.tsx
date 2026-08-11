export function Spinner({ size = 24 }: { size?: number }) {
  return (
    <span
      className="inline-block border-[3px] border-blue-600 border-t-transparent rounded-full animate-spin"
      style={{ width: size, height: size }}
    />
  );
}

export function PageLoader() {
  return (
    <div className="min-h-[60vh] flex items-center justify-center">
      <Spinner size={36} />
    </div>
  );
}
